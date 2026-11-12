// Nukad Kart API — Cloudflare Worker + D1.
// Endpoints (all JSON):
//   GET  /health
//   POST /v1/auth/google        { idToken }                  -> { token, user, profileComplete }
//   GET  /v1/me                                               (auth)
//   POST /v1/me/phone           { accessToken, phone }       (auth) phone verified by MSG91
//   PUT  /v1/me                 { name, address? }           (auth)
//   POST /v1/me/delete          { reason, feedback }         (auth) removes profile; next Google login starts fresh
//   POST /v1/me/push-token     { token }                    (auth) this phone's Firebase token
//   POST /v1/me/logout                                        (auth) log out this phone
//   GET  /v1/me/sessions                                      (auth) phones where this account is logged in
//   POST /v1/me/sessions/logout { id }                       (auth) log out one phone
//   POST /v1/me/sessions/logout-others                        (auth) log out every other phone
//   GET  /v1/stores/nearby?lat=&lng=&radius=                  stores within radius (max 500 m); thelas by live location
//   GET  /v1/stores/:id/products                              what a store / thela sells now

import { isAdmin, partnerRoute, offlineReason, staleThelas } from './partner.js';
import { productOut } from './products.js';

export const RADIUS_MAX_M = 500;
const SESSION_DAYS = 30;
const GOOGLE_ISSUERS = ['accounts.google.com', 'https://accounts.google.com'];
const GOOGLE_CERTS = 'https://www.googleapis.com/oauth2/v3/certs';
const MSG91_VERIFY = 'https://control.msg91.com/api/v5/widget/verifyAccessToken';

// ---------- helpers ----------
const enc = new TextEncoder();

export function b64url(bytes) {
  let s = '';
  for (const b of new Uint8Array(bytes)) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
export function b64urlDecode(str) {
  const s = str.replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(s + '='.repeat((4 - (s.length % 4)) % 4));
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}

export class HttpError extends Error {
  constructor(status, code, message) { super(message || code); this.status = status; this.code = code; }
}

export function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });
}

export async function body(req) {
  try { return await req.json(); } catch { throw new HttpError(400, 'bad_json'); }
}

export const now = () => Math.floor(Date.now() / 1000);

// ---------- distance ----------
export function haversineM(lat1, lng1, lat2, lng2) {
  const R = 6371000, rad = Math.PI / 180;
  const dLat = (lat2 - lat1) * rad, dLng = (lng2 - lng1) * rad;
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

export function boundingBox(lat, lng, radiusM) {
  const dLat = radiusM / 111320;
  const dLng = radiusM / (111320 * Math.max(Math.cos(lat * Math.PI / 180), 0.01));
  return { minLat: lat - dLat, maxLat: lat + dLat, minLng: lng - dLng, maxLng: lng + dLng };
}

// ---------- our session token (HMAC-SHA256) ----------
async function hmacKey(secret) {
  return crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);
}

export async function signSession(uid, secret, days = SESSION_DAYS, sid = undefined) {
  const payload = b64url(enc.encode(JSON.stringify({ uid, sid, exp: now() + days * 86400 })));
  const sig = await crypto.subtle.sign('HMAC', await hmacKey(secret), enc.encode(payload));
  return `${payload}.${b64url(sig)}`;
}

export async function verifySession(token, secret) {
  const [payload, sig] = String(token || '').split('.');
  if (!payload || !sig) return null;
  const ok = await crypto.subtle.verify('HMAC', await hmacKey(secret), b64urlDecode(sig), enc.encode(payload));
  if (!ok) return null;
  const data = JSON.parse(new TextDecoder().decode(b64urlDecode(payload)));
  return data.exp > now() ? data : null;
}

// ---------- Google ID token ----------
let certCache = { keys: null, until: 0 };

async function googleKeys(fetchImpl = fetch) {
  if (certCache.keys && certCache.until > Date.now()) return certCache.keys;
  const res = await fetchImpl(GOOGLE_CERTS);
  if (!res.ok) throw new HttpError(502, 'google_certs_unavailable');
  const { keys } = await res.json();
  const maxAge = Number((res.headers.get('cache-control') || '').match(/max-age=(\d+)/)?.[1] || 3600);
  certCache = { keys, until: Date.now() + maxAge * 1000 };
  return keys;
}

export async function verifyGoogleIdToken(idToken, audiences, { keys, at = now() } = {}) {
  const parts = String(idToken || '').split('.');
  if (parts.length !== 3) throw new HttpError(401, 'bad_google_token');
  const [h, p, s] = parts;
  const header = JSON.parse(new TextDecoder().decode(b64urlDecode(h)));
  const claims = JSON.parse(new TextDecoder().decode(b64urlDecode(p)));
  if (header.alg !== 'RS256') throw new HttpError(401, 'bad_google_token');
  const jwk = (keys || (await googleKeys())).find((k) => k.kid === header.kid);
  if (!jwk) throw new HttpError(401, 'bad_google_token', 'unknown key');
  const key = await crypto.subtle.importKey('jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
  const ok = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, b64urlDecode(s), enc.encode(`${h}.${p}`));
  if (!ok) throw new HttpError(401, 'bad_google_token', 'signature');
  if (!GOOGLE_ISSUERS.includes(claims.iss)) throw new HttpError(401, 'bad_google_token', 'issuer');
  if (!audiences.includes(claims.aud)) throw new HttpError(401, 'bad_google_token', 'audience');
  if (!(claims.exp > at - 60)) throw new HttpError(401, 'google_token_expired');
  if (claims.email_verified !== true && claims.email_verified !== 'true') throw new HttpError(401, 'email_not_verified');
  return claims;
}

// ---------- MSG91 ----------
export async function verifyMsg91(accessToken, authkey, fetchImpl = fetch) {
  const res = await fetchImpl(MSG91_VERIFY, {
    method: 'POST',
    headers: { 'content-type': 'application/json', accept: 'application/json' },
    body: JSON.stringify({ authkey, 'access-token': accessToken }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || data.type !== 'success') throw new HttpError(401, 'phone_not_verified', data.message || 'msg91');
  // MSG91 returns the verified number in `message` (e.g. "919876543210"); keep the last 10 digits.
  const digits = String(data.message || '').replace(/\D/g, '');
  return digits.length >= 10 ? digits.slice(-10) : null;
}

// ---------- data ----------
function publicUser(u) {
  return { id: u.id, email: u.email, name: u.name, phone: u.phone, phoneVerified: !!u.phone_verified };
}

async function profile(db, uid) {
  const user = await db.prepare('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL').bind(uid).first();
  if (!user) throw new HttpError(401, 'unknown_user');
  const { results } = await db.prepare('SELECT * FROM addresses WHERE user_id = ? ORDER BY is_default DESC, created_at').bind(uid).all();
  const complete = !!(user.name && user.phone && user.phone_verified && results.length);
  return { user: publicUser(user), addresses: results, profileComplete: complete };
}

const SEEN_EVERY = 600; // update last_seen at most every 10 minutes (saves database writes)

export async function session(req, env) {
  const token = (req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
  const s = await verifySession(token, env.SESSION_SECRET);
  if (!s || !s.sid) throw new HttpError(401, 'not_signed_in');
  const row = await env.DB.prepare(
    `SELECT s.id, s.last_seen FROM sessions s JOIN users u ON u.id = s.user_id
     WHERE s.id = ? AND s.user_id = ? AND s.revoked_at IS NULL AND u.deleted_at IS NULL`,
  ).bind(s.sid, s.uid).first();
  if (!row) throw new HttpError(401, 'not_signed_in');
  if (now() - row.last_seen > SEEN_EVERY) {
    await env.DB.prepare('UPDATE sessions SET last_seen = ? WHERE id = ?').bind(now(), s.sid).run();
  }
  return { uid: s.uid, sid: s.sid };
}

async function auth(req, env) {
  return (await session(req, env)).uid;
}

const ADDRESS_FIELDS = ['label', 'name', 'phone', 'flat', 'floor', 'area', 'city', 'state', 'country', 'pin'];

function cleanAddress(a) {
  if (!a || typeof a !== 'object') throw new HttpError(400, 'address_required');
  const out = {};
  for (const f of ADDRESS_FIELDS) out[f] = a[f] == null ? null : String(a[f]).trim().slice(0, 200);
  for (const f of ['flat', 'area', 'city', 'state', 'pin']) if (!out[f]) throw new HttpError(400, 'address_incomplete', f);
  if (!/^\d{6}$/.test(out.pin)) throw new HttpError(400, 'bad_pin');
  const lat = Number(a.lat), lng = Number(a.lng);
  out.lat = Number.isFinite(lat) && Math.abs(lat) <= 90 ? lat : null;
  out.lng = Number.isFinite(lng) && Math.abs(lng) <= 180 ? lng : null;
  return out;
}

// ---------- nearby shops: short cache ----------
// Customers in the same ~1 km cell see the same shops, so the database is asked once per cell every
// 30 seconds (per Cloudflare server) instead of once per customer. A shop switching LIVE shows within 30 s.
const NEAR_CELL = 0.01; // degrees (~1.1 km)
const NEAR_TTL_MS = 30_000; // shops only; thelas are read fresh every time
/** A thela that has not sent its location for this long is hidden from customers. */
export const THELA_STALE_S = 600;
/** Moved within this long = "Moving"; otherwise "Standing here". */
const THELA_MOVING_S = 120;
const nearCache = new Map();

const prodCache = new Map();

const NEAR_COLS = `id, name, kind, lat, lng, address, phone, opens_at, closes_at, door_delivery, pickup, demo, status, live,
  pass_until, missed_date, missed_count, photo_at, gst_type, fssai, agreement_version, live_lat, live_lng, live_at, moved_at, heading`;

/** Shops (cached 20 s per ~1 km cell) + thelas (always fresh: they move and go offline any moment). */
async function nearbyRows(env, lat, lng) {
  const cLat = Math.floor(lat / NEAR_CELL), cLng = Math.floor(lng / NEAR_CELL);
  const key = `${cLat}:${cLng}`;
  // The whole cell plus 500 m around it, so every customer inside the cell is covered.
  const pad = RADIUS_MAX_M / 111_000 + 0.001;
  const padLng = pad / Math.max(Math.cos((lat * Math.PI) / 180), 0.2);
  const la0 = cLat * NEAR_CELL - pad, la1 = (cLat + 1) * NEAR_CELL + pad, lo0 = cLng * NEAR_CELL - padLng, lo1 = (cLng + 1) * NEAR_CELL + padLng;
  const thelaQ = env.DB.prepare(`SELECT ${NEAR_COLS} FROM stores
    WHERE kind = 'thela' AND live = 1 AND active = 1 AND live_lat BETWEEN ? AND ? AND live_lng BETWEEN ? AND ?`).bind(la0, la1, lo0, lo1);
  const hit = nearCache.get(key);
  if (hit && hit.at > Date.now() - NEAR_TTL_MS) {
    const t = await thelaQ.all();
    return [...hit.rows, ...t.results];
  }
  const [sh, th] = await env.DB.batch([
    env.DB.prepare(`SELECT ${NEAR_COLS} FROM stores
      WHERE kind != 'thela' AND active = 1 AND lat BETWEEN ? AND ? AND lng BETWEEN ? AND ?`).bind(la0, la1, lo0, lo1),
    thelaQ,
  ]);
  if (nearCache.size > 2000) nearCache.clear();
  nearCache.set(key, { at: Date.now(), rows: sh.results });
  return [...sh.results, ...th.results];
}

// ---------- routes ----------
async function route(req, env) {
  const url = new URL(req.url);
  const path = url.pathname.replace(/\/+$/, '') || '/';
  const m = req.method;

  const partner = await partnerRoute(req, env, path, m);
  if (partner) return partner;

  if (m === 'GET' && (path === '/' || path === '/health')) {
    const t0 = Date.now();
    const r = await env.DB.prepare('SELECT COUNT(*) AS n FROM stores WHERE active = 1').all();
    return json({ ok: true, service: 'nukad-kart-api', stores: r.results[0].n, time: new Date().toISOString(),
      worker: req.cf?.colo || '', db: r.meta?.served_by_region || r.meta?.served_by || '', dbMs: Date.now() - t0 });
  }

  if (m === 'POST' && path === '/v1/auth/google') {
    const audiences = String(env.GOOGLE_CLIENT_IDS || '').split(',').map((s) => s.trim()).filter(Boolean);
    if (!audiences.length) throw new HttpError(503, 'google_not_configured');
    const { idToken, device, app: appRaw } = await body(req);
    const app = appRaw === 'partner' ? 'partner' : 'customer';
    const c = await verifyGoogleIdToken(idToken, audiences);
    const t = now();
    let user = await env.DB.prepare('SELECT * FROM users WHERE google_sub = ?').bind(c.sub).first();
    // One Google account is either a customer or a partner (admins can use both apps).
    if (user?.app && user.app !== app && !(await isAdmin(env, c.email))) {
      throw new HttpError(409, user.app === 'partner' ? 'email_used_by_partner' : 'email_used_by_customer');
    }
    if (!user) {
      const id = crypto.randomUUID();
      await env.DB.prepare('INSERT INTO users (id, google_sub, email, name, app, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
        .bind(id, c.sub, c.email, c.name || null, app, t, t).run();
      user = { id };
    } else {
      await env.DB.prepare('UPDATE users SET email = ?, app = COALESCE(app, ?), updated_at = ? WHERE id = ?').bind(c.email, app, t, user.id).run();
    }
    const sid = crypto.randomUUID();
    const d = device && typeof device === 'object' ? device : {};
    const role = (await env.DB.prepare('SELECT role FROM users WHERE id = ?').bind(user.id).first())?.role || 'customer';
    const stmts = [];
    // A thela account works on one phone at a time: logging in here logs out every other phone.
    if (role === 'thela') {
      stmts.push(env.DB.prepare('UPDATE sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL').bind(t, user.id));
    }
    const devName = String(d.name || 'Unknown phone').slice(0, 60);
    const devPlatform = String(d.platform || '').slice(0, 40);
    const devId = String(d.id || '').slice(0, 64) || null;
    if (devId) {
      // Same phone logging in again: its old session is replaced, not listed twice.
      // Older sessions made before phones sent an id are matched by model + Android version.
      stmts.push(env.DB.prepare(
        `UPDATE sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL
         AND (device_id = ? OR (device_id IS NULL AND device = ? AND platform = ?))`,
      ).bind(t, user.id, devId, devName, devPlatform));
    }
    stmts.push(env.DB.prepare(
      'INSERT INTO sessions (id, user_id, device, platform, city, created_at, last_seen, device_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    ).bind(sid, user.id, devName, devPlatform, String(req.cf?.city || '').slice(0, 60) || null, t, t, devId));
    await env.DB.batch(stmts);
    const token = await signSession(user.id, env.SESSION_SECRET, SESSION_DAYS, sid);
    return json({ token, ...(await profile(env.DB, user.id)) });
  }

  if (path === '/v1/me' && m === 'GET') {
    return json(await profile(env.DB, await auth(req, env)));
  }

  if (path === '/v1/me/phone' && m === 'POST') {
    const uid = await auth(req, env);
    if (!env.MSG91_AUTHKEY) throw new HttpError(503, 'phone_check_not_configured');
    const { accessToken, phone } = await body(req);
    const claimed = String(phone || '').replace(/\D/g, '').slice(-10);
    if (claimed.length !== 10) throw new HttpError(400, 'bad_phone');
    const verified = await verifyMsg91(accessToken, env.MSG91_AUTHKEY);
    if (verified && verified !== claimed) throw new HttpError(401, 'phone_mismatch');
    const other = await env.DB.prepare('SELECT id FROM users WHERE phone = ? AND id != ? AND deleted_at IS NULL').bind(claimed, uid).first();
    if (other) throw new HttpError(409, 'phone_in_use');
    await env.DB.prepare('UPDATE users SET phone = ?, phone_verified = 1, updated_at = ? WHERE id = ?').bind(claimed, now(), uid).run();
    return json(await profile(env.DB, uid));
  }

  if (path === '/v1/me' && m === 'PUT') {
    const uid = await auth(req, env);
    const b = await body(req);
    const name = String(b.name || '').trim().slice(0, 80);
    if (!name) throw new HttpError(400, 'name_required');
    const stmts = [env.DB.prepare('UPDATE users SET name = ?, updated_at = ? WHERE id = ?').bind(name, now(), uid)];
    if (b.address) {
      const a = cleanAddress(b.address);
      stmts.push(env.DB.prepare('UPDATE addresses SET is_default = 0 WHERE user_id = ?').bind(uid));
      stmts.push(env.DB.prepare(
        `INSERT INTO addresses (id, user_id, ${ADDRESS_FIELDS.join(', ')}, lat, lng, is_default, created_at)
         VALUES (?, ?, ${ADDRESS_FIELDS.map(() => '?').join(', ')}, ?, ?, 1, ?)`,
      ).bind(crypto.randomUUID(), uid, ...ADDRESS_FIELDS.map((f) => (f === 'country' ? a.country || 'India' : f === 'label' ? a.label || 'Home' : a[f])), a.lat, a.lng, now()));
    }
    await env.DB.batch(stmts);
    return json(await profile(env.DB, uid));
  }

  if (path === '/v1/me/delete' && m === 'POST') {
    const uid = await auth(req, env);
    const b = await body(req);
    const t = now();
    await env.DB.batch([
      env.DB.prepare('INSERT INTO deletion_requests (id, user_id, reason, feedback, created_at) VALUES (?, ?, ?, ?, ?)')
        .bind(crypto.randomUUID(), uid, String(b.reason || '').slice(0, 200), String(b.feedback || '').slice(0, 1000), t),
      env.DB.prepare('DELETE FROM addresses WHERE user_id = ?').bind(uid),
      env.DB.prepare('UPDATE sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL').bind(t, uid),
      // Keep only the row id (orders and complaints will point to it); personal details are wiped.
      env.DB.prepare(
        "UPDATE users SET google_sub = 'deleted:' || id, email = '', name = NULL, phone = NULL, phone_verified = 0, deleted_at = ?, updated_at = ? WHERE id = ?",
      ).bind(t, t, uid),
    ]);
    return json({ ok: true });
  }

  if (path === '/v1/me/push-token' && m === 'POST') {
    // Customer phone's Firebase token: for "thela is coming", order updates and chat.
    const { uid } = await session(req, env);
    const token = String((await body(req)).token || '').trim();
    if (token.length < 20 || token.length > 4096) throw new HttpError(400, 'bad_token');
    await env.DB.prepare('INSERT OR REPLACE INTO push_tokens (token, user_id, app, updated_at) VALUES (?, ?, ?, ?)')
      .bind(token, uid, 'customer', now()).run();
    return json({ ok: true });
  }

  if (path === '/v1/me/logout' && m === 'POST') {
    const { sid } = await session(req, env);
    await env.DB.prepare('UPDATE sessions SET revoked_at = ? WHERE id = ?').bind(now(), sid).run();
    return json({ ok: true });
  }

  if (path === '/v1/me/sessions' && m === 'GET') {
    const { uid, sid } = await session(req, env);
    const { results } = await env.DB.prepare(
      'SELECT id, device, platform, city, created_at, last_seen FROM sessions WHERE user_id = ? AND revoked_at IS NULL ORDER BY last_seen DESC',
    ).bind(uid).all();
    return json({ sessions: results.map((r) => ({ ...r, current: r.id === sid })) });
  }

  if (path === '/v1/me/sessions/logout' && m === 'POST') {
    const { uid } = await session(req, env);
    const { id } = await body(req);
    await env.DB.prepare('UPDATE sessions SET revoked_at = ? WHERE id = ? AND user_id = ? AND revoked_at IS NULL')
      .bind(now(), String(id || ''), uid).run();
    return json({ ok: true });
  }

  if (path === '/v1/me/sessions/logout-others' && m === 'POST') {
    const { uid, sid } = await session(req, env);
    await env.DB.prepare('UPDATE sessions SET revoked_at = ? WHERE user_id = ? AND id != ? AND revoked_at IS NULL')
      .bind(now(), uid, sid).run();
    return json({ ok: true });
  }

  // What a shop / thela is selling now (in stock only). Short cache: prices change during the day.
  const sp = path.match(/^\/v1\/stores\/([\w-]+)\/products$/);
  if (sp && m === 'GET') {
    const hit = prodCache.get(sp[1]);
    if (hit && hit.at > Date.now() - 20_000) return json(hit.body);
    const [st, pr] = await env.DB.batch([
      env.DB.prepare('SELECT * FROM stores WHERE id = ? AND active = 1').bind(sp[1]),
      // A thela sells only items from the app's photo list (aloo, pyaz…); older hand-added items stay hidden.
      env.DB.prepare(`SELECT p.* FROM products p JOIN stores s ON s.id = p.store_id WHERE p.store_id = ? AND p.in_stock = 1
        AND (s.kind != 'thela' OR p.produce_key IS NOT NULL) ORDER BY p.category, p.name LIMIT 1000`).bind(sp[1]),
    ]);
    const s = st.results[0];
    if (!s || s.demo || offlineReason(s, now()) != null) throw new HttpError(404, 'not_available');
    const out = { storeId: s.id, products: pr.results.map(productOut) };
    if (prodCache.size > 500) prodCache.clear();
    prodCache.set(sp[1], { at: Date.now(), body: out });
    return json(out);
  }

  if (path === '/v1/stores/nearby' && m === 'GET') {
    const lat = Number(url.searchParams.get('lat')), lng = Number(url.searchParams.get('lng'));
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) throw new HttpError(400, 'bad_location');
    const radius = Math.min(Number(url.searchParams.get('radius')) || RADIUS_MAX_M, RADIUS_MAX_M);
    const results = await nearbyRows(env, lat, lng);
    // Partner shops show only with an active pass, switched on, within their timings
    // (after closing time they drop off the map) and not paused for missed orders.
    const t = now();
    const stores = results
      .filter((s) => !s.demo && offlineReason(s, t) == null)
      .filter((s) => s.kind !== 'thela' || (s.live_at && t - s.live_at <= THELA_STALE_S))
      .map((s) => {
        const thela = s.kind === 'thela';
        const sLat = thela ? s.live_lat : s.lat, sLng = thela ? s.live_lng : s.lng;
        return {
          id: s.id, name: s.name, kind: s.kind, lat: sLat, lng: sLng, address: thela ? '' : s.address,
          // A thela's number is never shared; customers reach it through the app.
          phone: thela ? '' : s.phone,
          opensAt: s.opens_at, closesAt: s.closes_at, door: !!s.door_delivery, pickup: !!s.pickup,
          gstType: s.gst_type || 'none', fssai: s.fssai || '', photo: s.photo_at ? `/v1/stores/${s.id}/photo` : null,
          distanceM: Math.round(haversineM(lat, lng, sLat, sLng)),
          ...(thela ? { seenAgo: t - s.live_at, moving: !!s.moved_at && t - s.moved_at <= THELA_MOVING_S, heading: s.heading } : {}),
        };
      })
      .filter((s) => s.distanceM <= radius)
      .sort((a, b) => a.distanceM - b.distanceM);
    return json({ radius, count: stores.length, stores });
  }

  throw new HttpError(404, 'not_found');
}

export default {
  async fetch(req, env) {
    try {
      return await route(req, env);
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.code, detail: e.message !== e.code ? e.message : undefined }, e.status);
      console.error(e);
      return json({ error: 'server_error' }, 500);
    }
  },
  // Every 5 minutes: thelas whose location stopped coming are hidden; tell the seller once.
  async scheduled(_ev, env, ectx) {
    ectx.waitUntil(staleThelas(env).catch((e) => console.error(e)));
  },
};
