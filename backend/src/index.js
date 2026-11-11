// Nukad Kart API — Cloudflare Worker + D1.
// Endpoints (all JSON):
//   GET  /health
//   POST /v1/auth/google        { idToken }                  -> { token, user, profileComplete }
//   GET  /v1/me                                               (auth)
//   POST /v1/me/phone           { accessToken, phone }       (auth) phone verified by MSG91
//   PUT  /v1/me                 { name, address? }           (auth)
//   POST /v1/me/delete          { reason, feedback }         (auth) removes profile; next Google login starts fresh
//   GET  /v1/stores/nearby?lat=&lng=&radius=                  stores within radius (max 500 m)

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

class HttpError extends Error {
  constructor(status, code, message) { super(message || code); this.status = status; this.code = code; }
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });
}

async function body(req) {
  try { return await req.json(); } catch { throw new HttpError(400, 'bad_json'); }
}

const now = () => Math.floor(Date.now() / 1000);

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

export async function signSession(uid, secret, days = SESSION_DAYS) {
  const payload = b64url(enc.encode(JSON.stringify({ uid, exp: now() + days * 86400 })));
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

async function auth(req, env) {
  const token = (req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
  const s = await verifySession(token, env.SESSION_SECRET);
  if (!s) throw new HttpError(401, 'not_signed_in');
  const live = await env.DB.prepare('SELECT id FROM users WHERE id = ? AND deleted_at IS NULL').bind(s.uid).first();
  if (!live) throw new HttpError(401, 'not_signed_in');
  return s.uid;
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

// ---------- routes ----------
async function route(req, env) {
  const url = new URL(req.url);
  const path = url.pathname.replace(/\/+$/, '') || '/';
  const m = req.method;

  if (m === 'GET' && (path === '/' || path === '/health')) {
    const row = await env.DB.prepare('SELECT COUNT(*) AS n FROM stores WHERE active = 1').first();
    return json({ ok: true, service: 'nukad-kart-api', stores: row.n, time: new Date().toISOString() });
  }

  if (m === 'POST' && path === '/v1/auth/google') {
    const audiences = String(env.GOOGLE_CLIENT_IDS || '').split(',').map((s) => s.trim()).filter(Boolean);
    if (!audiences.length) throw new HttpError(503, 'google_not_configured');
    const { idToken } = await body(req);
    const c = await verifyGoogleIdToken(idToken, audiences);
    const t = now();
    let user = await env.DB.prepare('SELECT * FROM users WHERE google_sub = ?').bind(c.sub).first();
    if (!user) {
      const id = crypto.randomUUID();
      await env.DB.prepare('INSERT INTO users (id, google_sub, email, name, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)')
        .bind(id, c.sub, c.email, c.name || null, t, t).run();
      user = { id };
    } else if (user.email !== c.email) {
      await env.DB.prepare('UPDATE users SET email = ?, updated_at = ? WHERE id = ?').bind(c.email, t, user.id).run();
    }
    const token = await signSession(user.id, env.SESSION_SECRET);
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
      // Keep only the row id (orders and complaints will point to it); personal details are wiped.
      env.DB.prepare(
        "UPDATE users SET google_sub = 'deleted:' || id, email = '', name = NULL, phone = NULL, phone_verified = 0, deleted_at = ?, updated_at = ? WHERE id = ?",
      ).bind(t, t, uid),
    ]);
    return json({ ok: true });
  }

  if (path === '/v1/stores/nearby' && m === 'GET') {
    const lat = Number(url.searchParams.get('lat')), lng = Number(url.searchParams.get('lng'));
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) throw new HttpError(400, 'bad_location');
    const radius = Math.min(Number(url.searchParams.get('radius')) || RADIUS_MAX_M, RADIUS_MAX_M);
    const bb = boundingBox(lat, lng, radius);
    const { results } = await env.DB.prepare(
      `SELECT id, name, kind, lat, lng, address, phone, photo_key, opens_at, closes_at, door_delivery
       FROM stores WHERE active = 1 AND lat BETWEEN ? AND ? AND lng BETWEEN ? AND ?`,
    ).bind(bb.minLat, bb.maxLat, bb.minLng, bb.maxLng).all();
    const stores = results
      .map((s) => ({ ...s, distanceM: Math.round(haversineM(lat, lng, s.lat, s.lng)) }))
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
};
