// Letters of intent (nukkadkart.in/loi): founders fill one with a shop or thela in the field, the seller signs on the phone.
//   POST /v1/admin/loi            { clientId, kind, shopName, ownerName, area, years, mobile, delivers, upi, android, pass, sign, lat, lng, signedAt } (admin)
//   GET  /v1/admin/loi            list + totals, no signatures (admin)
//   GET  /v1/admin/loi/:id/sign   one signature as a PNG data URL (admin)
// Only the founders: an admin's login, or the private link (header x-loi-key, its SHA-256 in LOI_KEY_HASHES).
// The list holds sellers' names and mobile numbers, and the totals go into investor decks, so nobody else may add or read rows.
import { HttpError, json, now } from './index.js';
import { ctx, isAdmin, sha256Hex } from './partner.js';
import { cleanText, rateLimit, clientIp } from './guard.js';

const KINDS = ['kirana', 'thela', 'dairy', 'other'];
const YN = ['yes', 'no', ''];
const PASSES = ['day', 'week', 'month', 'year', ''];

/** Who may use the LOI routes: { by } for the private link, or the admin user. */
async function founder(req, env) {
  const key = req.headers.get('x-loi-key');
  if (key) {
    await rateLimit(env, `loi:${clientIp(req)}`, 120, 600);
    const list = String(env.LOI_KEY_HASHES || '').toLowerCase().split(',').map((s) => s.trim()).filter(Boolean);
    if (key.length < 16 || key.length > 100 || !list.includes(await sha256Hex(key))) throw new HttpError(403, 'bad_link');
    return { link: true };
  }
  const { u } = await ctx(req, env);
  if (!(await isAdmin(env, u.email))) throw new HttpError(403, 'not_admin');
  return { u };
}

export function checkLoi(b) {
  if (!b || typeof b !== 'object' || Array.isArray(b)) throw new HttpError(400, 'bad_request');
  const bad = (f) => { throw new HttpError(400, 'bad_field', f); };
  const one = (v, list, f) => { const s = String(v ?? '').toLowerCase(); if (!list.includes(s)) bad(f); return s; };
  const out = {
    clientId: String(b.clientId ?? ''),
    kind: one(b.kind, KINDS, 'kind'),
    shopName: cleanText(b.shopName, 80).replace(/\s+/g, ' '),
    ownerName: cleanText(b.ownerName, 80).replace(/\s+/g, ' '),
    area: cleanText(b.area, 160).replace(/\s+/g, ' '),
    years: cleanText(b.years, 20),
    mobile: String(b.mobile ?? '').replace(/\D/g, '').replace(/^(91|0)(?=[6-9]\d{9}$)/, ''),
    delivers: one(b.delivers, YN, 'delivers'),
    upi: one(b.upi, YN, 'upi'),
    android: one(b.android, YN, 'android'),
    pass: one(b.pass, PASSES, 'pass'),
    sign: String(b.sign ?? ''),
    lat: b.lat == null ? null : Number(b.lat),
    lng: b.lng == null ? null : Number(b.lng),
    signedAt: Math.floor(Number(b.signedAt) || 0),
  };
  if (!/^[\w-]{8,64}$/.test(out.clientId)) bad('clientId');
  if (out.shopName.length < 2) bad('shopName');
  if (out.ownerName.length < 2) bad('ownerName');
  if (out.area.length < 2) bad('area');
  if (out.mobile && !/^[6-9]\d{9}$/.test(out.mobile)) bad('mobile');
  if (!/^data:image\/png;base64,[A-Za-z0-9+/=]+$/.test(out.sign) || out.sign.length < 200 || out.sign.length > 120000) bad('sign');
  for (const k of ['lat', 'lng']) if (out[k] != null && !Number.isFinite(out[k])) bad(k);
  if (out.lat != null && (out.lat < 5 || out.lat > 38 || out.lng < 66 || out.lng > 99)) { out.lat = null; out.lng = null; }
  const t = now();
  if (!out.signedAt || out.signedAt > t + 300 || out.signedAt < t - 86400 * 60) out.signedAt = t;
  return out;
}

const rowOut = (r) => ({ id: r.id, kind: r.kind, shopName: r.shop_name, ownerName: r.owner_name, area: r.area, years: r.years,
  mobile: r.mobile, delivers: r.delivers, upi: r.upi, android: r.android, pass: r.pass, lat: r.lat, lng: r.lng,
  collectedBy: r.collected_by, signedAt: r.signed_at });

export async function loiRoute(req, env, path, m) {
  if (path !== '/v1/admin/loi' && !path.startsWith('/v1/admin/loi/')) return null;
  const who = await founder(req, env);
  if (m === 'POST' && path === '/v1/admin/loi') {
    let b;
    try { b = await req.json(); } catch { throw new HttpError(400, 'bad_json'); }
    const l = checkLoi(b);
    const id = 'loi_' + crypto.randomUUID().replace(/-/g, '').slice(0, 16);
    const by = who.u ? cleanText(who.u.name || String(who.u.email).split('@')[0], 60) : (cleanText(b.collector, 40) || 'Private link');
    await env.DB.prepare(
      `INSERT INTO loi (id, client_id, kind, shop_name, owner_name, area, years, mobile, delivers, upi, android, pass, sign_png, lat, lng,
        collected_by, signed_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(client_id) DO NOTHING`,
    ).bind(id, l.clientId, l.kind, l.shopName, l.ownerName, l.area, l.years, l.mobile, l.delivers, l.upi, l.android, l.pass, l.sign,
      l.lat, l.lng, by, l.signedAt, now()).run();
    return json({ ok: true });
  }
  if (m === 'GET' && path === '/v1/admin/loi') {
    const { results } = await env.DB.prepare(
      `SELECT id, kind, shop_name, owner_name, area, years, mobile, delivers, upi, android, pass, lat, lng, collected_by, signed_at
       FROM loi ORDER BY signed_at DESC LIMIT 2000`).all();
    return json({ items: results.map(rowOut) });
  }
  const sm = path.match(/^\/v1\/admin\/loi\/(loi_[a-f0-9]{16})\/sign$/);
  if (m === 'GET' && sm) {
    const r = await env.DB.prepare('SELECT sign_png FROM loi WHERE id = ?').bind(sm[1]).first();
    if (!r) throw new HttpError(404, 'not_found');
    return json({ sign: r.sign_png });
  }
  throw new HttpError(404, 'not_found');
}
