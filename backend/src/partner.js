// Partner (shop / thela owner) and admin routes.
//   GET  /v1/partner/plans                                    pass plans + where to pay
//   GET  /v1/partner/me                          (auth)       my shop, pass, live state, payments
//   POST /v1/partner/register                    (auth)       shop details + camera photo
//   POST /v1/partner/payments    { plan, key }   (auth)       start a pass payment (same key = same payment)
//   POST /v1/partner/payments/:key/done { upiStatus, upiRef, app }   back from the UPI app
//   POST /v1/partner/live        { on }          (auth)       go live / offline
//   GET  /v1/stores/:id/photo                                 shop photo (JPEG)
//   GET/PUT /v1/admin/settings { upiId, upiName } (admin)     where partners pay
//   GET  /v1/admin/payments?status=CHECKING|ALL  (admin)
//   POST /v1/admin/payments/:id/confirm          (admin)      money is in: pass starts
//   POST /v1/admin/payments/:id/cancel { reason } (admin)     money never came: pass undone
import { HttpError, json, body, now, verifySession, verifyMsg91 } from './index.js';

export const PLANS = {
  daily: { name: 'Daily', price: 99, days: 1 },
  weekly: { name: 'Weekly', price: 199, days: 7 },
  monthly: { name: 'Monthly', price: 499, days: 30 },
  yearly: { name: 'Yearly', price: 5999, days: 365 },
};
export const MISSED_LIMIT = 5; // missed orders in a day before the shop goes offline for the day
const IST = 5.5 * 3600;
export const TRIAL_DAYS = 7;
export const AGREEMENT_VERSION = '1.0';
export const DOC_TYPES = ['pan', 'aadhaar', 'gst', 'fssai'];
export const MAX_DOC_BYTES = 2 * 1024 * 1024;
export const MAX_PHOTO_DISTANCE_M = 50; // shop pin must be within this of where the shop photo was taken

/** Metres between two points. */
export function distanceM(lat1, lng1, lat2, lng2) {
  const r = 6371000, rad = Math.PI / 180;
  const a = Math.sin(((lat2 - lat1) * rad) / 2) ** 2 +
    Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(((lng2 - lng1) * rad) / 2) ** 2;
  return 2 * r * Math.asin(Math.sqrt(a));
}

// ---------- time (shops keep Indian time) ----------
/** "8 am", "9:30 pm", "21:30" → minutes after midnight, or null. */
export function parseTime(s) {
  const m = String(s || '').trim().toLowerCase().match(/^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$/);
  if (!m) return null;
  let h = Number(m[1]);
  const min = Number(m[2] || 0);
  if (m[3] === 'pm' && h < 12) h += 12;
  if (m[3] === 'am' && h === 12) h = 0;
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

export function istMinutes(t = now()) {
  const d = new Date((t + IST) * 1000);
  return d.getUTCHours() * 60 + d.getUTCMinutes();
}
export function istDate(t = now()) {
  return new Date((t + IST) * 1000).toISOString().slice(0, 10);
}

/** Open right now by its timings? Closing after midnight (e.g. 8 am – 1 am) is handled. */
export function openAt(opensAt, closesAt, t = now()) {
  const o = parseTime(opensAt), c = parseTime(closesAt);
  if (o == null || c == null) return true;
  const m = istMinutes(t);
  return o <= c ? m >= o && m < c : m >= o || m < c;
}

/** New pass end: a new pass starts when the current one ends (or now, if none). */
export function extendPass(passUntil, days, t = now()) {
  return Math.max(passUntil || 0, t) + days * 86400;
}

/** Why a shop is not visible to customers right now, or null when it is. */
export function offlineReason(s, t = now()) {
  if (s.status === 'blocked') return 'blocked';
  if (s.status === 'deleted') return 'deleted';
  if (!s.agreement_version) return 'no_agreement';
  if (s.status === 'rejected') return 'rejected';
  if (s.status === 'pending' || s.status === 'review') return 'not_verified';
  if (!(s.pass_until > t)) return 'no_pass';
  if (!s.live) return 'switched_off';
  if (s.missed_date === istDate(t) && s.missed_count >= MISSED_LIMIT) return 'missed_orders';
  if (!openAt(s.opens_at, s.closes_at, t)) return 'closed_now';
  return null;
}

// ---------- helpers ----------
const STORE_Q = 'SELECT * FROM stores WHERE owner_id = ? ORDER BY created_at DESC LIMIT 1';
const DOCS_Q = `SELECT id, type, mime, name, size, created_at FROM partner_docs WHERE done = 1 AND store_id =
  (SELECT id FROM stores WHERE owner_id = ? ORDER BY created_at DESC LIMIT 1) ORDER BY created_at`;
const docOut = (d) => ({ id: d.id, type: d.type, mime: d.mime, name: d.name, size: d.size, uploadedAt: d.created_at });

/**
 * Who is calling + their shop + its documents, in ONE database round trip
 * (the database is far from India, so every extra trip costs ~0.1–0.3 s).
 */
async function ctx(req, env) {
  const token = (req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
  const sess = await verifySession(token, env.SESSION_SECRET);
  if (!sess || !sess.sid) throw new HttpError(401, 'not_signed_in');
  const t = now();
  const [ur, sr, dr] = await env.DB.batch([
    env.DB.prepare(`SELECT u.* FROM sessions s JOIN users u ON u.id = s.user_id
      WHERE s.id = ? AND s.user_id = ? AND s.revoked_at IS NULL AND u.deleted_at IS NULL`).bind(sess.sid, sess.uid),
    env.DB.prepare(STORE_Q).bind(sess.uid),
    env.DB.prepare(DOCS_Q).bind(sess.uid),
    // "last seen" for Logged-in devices, at most every 10 minutes
    env.DB.prepare('UPDATE sessions SET last_seen = ? WHERE id = ? AND last_seen < ?').bind(t, sess.sid, t - 600),
  ]);
  const u = ur.results[0];
  if (!u) throw new HttpError(401, 'not_signed_in');
  return { u, s: sr.results[0] || null, docs: dr.results.map(docOut) };
}

async function me(req, env) {
  return (await ctx(req, env)).u;
}

/** Run writes and read the shop back in the same round trip. */
async function writeAndRead(env, uid, stmts = []) {
  const res = await env.DB.batch([...stmts, env.DB.prepare(STORE_Q).bind(uid), env.DB.prepare(DOCS_Q).bind(uid)]);
  const s = res[res.length - 2].results[0] || null;
  return storeOutWith(s, res[res.length - 1].results.map(docOut));
}

export async function sha256Hex(text) {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

export async function isAdmin(env, email) {
  const list = String(env.ADMIN_EMAIL_HASHES || '').toLowerCase().split(',').map((s) => s.trim()).filter(Boolean);
  if (!list.length || !email) return false;
  return list.includes(await sha256Hex(String(email).trim().toLowerCase()));
}

const PARTY_KEYS = { legalName: 'party_legal_name', address: 'party_address', city: 'party_city', pan: 'party_pan', email: 'party_email' };

const partyQuery = (env) => env.DB.prepare(`SELECT key, value FROM settings WHERE key IN (${Object.values(PARTY_KEYS).map(() => '?').join(',')})`)
  .bind(...Object.values(PARTY_KEYS));

async function partySettings(env) {
  return partyFrom((await partyQuery(env).all()).results);
}

function partyFrom(results) {
  const m = Object.fromEntries(results.map((r) => [r.key, r.value]));
  return Object.fromEntries(Object.entries(PARTY_KEYS).map(([k, key]) => [k, m[key] || '']));
}

async function upiSettings(env) {
  const { results } = await env.DB.prepare("SELECT key, value FROM settings WHERE key IN ('upi_id','upi_name','test_mode')").all();
  const m = Object.fromEntries(results.map((r) => [r.key, r.value]));
  // testMode: every partner sees "Demo pay" (for testing before launch). Set by an admin.
  return { upiId: m.upi_id || '', upiName: m.upi_name || 'Nukad Kart', testMode: m.test_mode === '1' };
}

async function admin(req, env) {
  const { u } = await ctx(req, env);
  if (!(await isAdmin(env, u.email))) throw new HttpError(403, 'not_admin');
  return u;
}

async function myStore(env, uid) {
  return env.DB.prepare('SELECT * FROM stores WHERE owner_id = ? ORDER BY created_at DESC LIMIT 1').bind(uid).first();
}

/** Documents this shop must upload: PAN and Aadhaar always; GST / FSSAI when it has them. */
export function requiredDocs(s) {
  return ['pan', 'aadhaar', ...(s.gst_type && s.gst_type !== 'none' ? ['gst'] : []), ...(s.fssai ? ['fssai'] : [])];
}

async function docList(env, s) {
  const { results } = await env.DB.prepare('SELECT id, type, mime, name, size, created_at FROM partner_docs WHERE store_id = ? AND done = 1 ORDER BY created_at').bind(s.id).all();
  return results.map(docOut);
}

async function storeOut(env, s, docs) {
  if (!s) return null;
  return storeOutWith(s, docs || (await docList(env, s)));
}

function storeOutWith(s, docs) {
  if (!s) return null;
  const have = new Set(docs.map((d) => d.type));
  const required = requiredDocs(s);
  const optional = DOC_TYPES.filter((t) => !required.includes(t) && (t !== 'gst' || (s.gst_type && s.gst_type !== 'none')));
  return { ...publicStore(s), requiredDocs: required, optionalDocs: optional, docsComplete: required.every((t) => have.has(t)) };
}

async function trialAvailable(env, phone, devHash) {
  const ph = await sha256Hex('phone:' + phone);
  const row = await env.DB.prepare('SELECT id FROM trial_claims WHERE phone_hash = ? OR (? IS NOT NULL AND device_hash = ?) LIMIT 1')
    .bind(ph, devHash, devHash).first();
  return !row;
}

async function submitForReview(env, s, docs) {
  const out = await storeOut(env, s, docs);
  if (!out.docsComplete) throw new HttpError(400, 'docs_missing');
  if (s.agreement_version !== AGREEMENT_VERSION) throw new HttpError(403, 'agreement_needed');
  if (s.status === 'pending' || s.status === 'rejected') {
    await env.DB.prepare("UPDATE stores SET status = 'review', review_note = NULL WHERE id = ?").bind(s.id).run();
  }
}

function publicStore(s, t = now()) {
  if (!s) return null;
  const reason = offlineReason(s, t);
  return {
    id: s.id, name: s.name, kind: s.kind, address: s.address, phone: s.phone, lat: s.lat, lng: s.lng,
    opensAt: s.opens_at, closesAt: s.closes_at, door: !!s.door_delivery, pickup: !!s.pickup,
    fssai: s.fssai || '', gstType: s.gst_type || 'none', gstin: s.gstin || '', status: s.status,
    live: !!s.live, visible: reason == null, offlineReason: reason,
    passUntil: s.pass_until || 0, passActive: s.pass_until > t,
    trial: !!s.trial_until && s.trial_until >= (s.pass_until || 0) && s.pass_until > t,
    agreementVersion: s.agreement_version || '', agreementSigned: s.agreement_version === AGREEMENT_VERSION,
    pan: s.pan || '', aadhaarLast4: s.aadhaar_last4 || '', reviewNote: s.review_note || '', reviewedAt: s.reviewed_at || 0,
    addr: { shop: s.addr_shop || '', landmark: s.addr_landmark || '', area: s.addr_area || '', city: s.addr_city || '', state: s.addr_state || '', pin: s.addr_pin || '' },
    missedToday: s.missed_date === istDate(t) ? s.missed_count : 0, hasPhoto: !!s.photo_at, createdAt: s.created_at,
  };
}

function vendorDetails(s, u) {
  return { storeName: s.name, kind: s.kind, address: s.address || '', phone: s.phone || '', email: u.email || '',
    gstType: s.gst_type || 'none', gstin: s.gstin || '', fssai: s.fssai || '', pan: s.pan || '', aadhaarLast4: s.aadhaar_last4 || '' };
}

function payPublic(p) {
  return { id: p.id, plan: p.plan, planName: PLANS[p.plan]?.name || p.plan, amount: p.amount, status: p.status,
    upiStatus: p.upi_status, app: p.app, createdAt: p.created_at, reason: p.reason };
}

async function activate(env, p, by) {
  const s = await env.DB.prepare('SELECT pass_until FROM stores WHERE id = ?').bind(p.store_id).first();
  const until = extendPass(s?.pass_until, PLANS[p.plan].days);
  await env.DB.batch([
    env.DB.prepare('UPDATE stores SET pass_until = ? WHERE id = ?').bind(until, p.store_id),
    env.DB.prepare('UPDATE pass_payments SET status = ?, pass_until = ?, decided_by = ?, updated_at = ? WHERE id = ?')
      .bind('PAID', until, by, now(), p.id),
  ]);
  return until;
}

const b64ToBytes = (b64) => Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
function bytesToB64(u8) {
  let out = '';
  for (let i = 0; i < u8.length; i += 0x8000) out += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000));
  return btoa(out);
}

// ---------- routes ----------
export async function partnerRoute(req, env, path, m) {
  if (path === '/v1/partner/plans' && m === 'GET') {
    return json({ plans: Object.entries(PLANS).map(([id, p]) => ({ id, ...p })), ...(await upiSettings(env)) });
  }

  const photo = path.match(/^\/v1\/stores\/([\w-]+)\/photo$/);
  if (photo && m === 'GET') {
    const row = await env.DB.prepare('SELECT photo FROM store_photos WHERE store_id = ?').bind(photo[1]).first();
    if (!row) throw new HttpError(404, 'no_photo');
    return new Response(b64ToBytes(row.photo), { headers: { 'content-type': 'image/jpeg', 'cache-control': 'public, max-age=86400' } });
  }

  if (path === '/v1/partner/me' && m === 'GET') {
    const { u, s, docs } = await ctx(req, env);
    const pays = s
      ? (await env.DB.prepare('SELECT * FROM pass_payments WHERE store_id = ? ORDER BY created_at DESC LIMIT 10').bind(s.id).all()).results
      : [];
    return json({ user: { email: u.email, name: u.name, phone: u.partner_phone || '', phoneVerified: !!u.partner_phone,
      trialAvailable: u.partner_trial_ok !== 0 }, admin: await isAdmin(env, u.email), store: storeOutWith(s, docs),
      payments: pays.map(payPublic) });
  }

  if (path === '/v1/partner/phone' && m === 'POST') {
    // Step 1: verified mobile number (MSG91 SMS code) + this phone's hardware id, for the one-trial rule.
    const { u, s } = await ctx(req, env);
    if (!env.MSG91_AUTHKEY) throw new HttpError(503, 'phone_check_not_configured');
    const b = await body(req);
    const claimed = String(b.phone || '').replace(/\D/g, '').slice(-10);
    if (!/^[6-9]\d{9}$/.test(claimed)) throw new HttpError(400, 'bad_phone');
    const verified = await verifyMsg91(b.accessToken, env.MSG91_AUTHKEY);
    if (verified && verified !== claimed) throw new HttpError(401, 'phone_mismatch');
    const other = await env.DB.prepare("SELECT id FROM users WHERE partner_phone = ? AND id != ? AND deleted_at IS NULL").bind(claimed, u.id).first();
    if (other) throw new HttpError(409, 'phone_in_use');
    const hw = String(b.deviceId || '').trim();
    const devHash = hw ? await sha256Hex('dev:' + hw) : null;
    const ok = await trialAvailable(env, claimed, devHash);
    const stmts = [env.DB.prepare('UPDATE users SET partner_phone = ?, partner_device_hash = COALESCE(?, partner_device_hash), partner_trial_ok = ?, updated_at = ? WHERE id = ?')
      .bind(claimed, devHash, ok ? 1 : 0, now(), u.id)];
    if (s) stmts.push(env.DB.prepare('UPDATE stores SET phone = ?, phone_verified = 1, device_hash = COALESCE(?, device_hash) WHERE id = ?').bind(claimed, devHash, s.id));
    await env.DB.batch(stmts);
    return json({ phone: claimed, trialAvailable: ok });
  }

  if (path === '/v1/partner/register' && m === 'POST') {
    const { u, s: existing } = await ctx(req, env);
    if (!u.partner_phone) throw new HttpError(400, 'phone_first');
    const b = await body(req);
    const str = (k, max = 120) => String(b[k] ?? '').trim().slice(0, max);
    const kind = b.kind === 'thela' ? 'thela' : 'shop';
    const name = str('name', 80);
    if (name.length < 2) throw new HttpError(400, 'name_required');
    const lat = Number(b.lat), lng = Number(b.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) throw new HttpError(400, 'location_required');
    if (kind === 'shop' && (parseTime(b.opensAt) == null || parseTime(b.closesAt) == null)) throw new HttpError(400, 'timings_required');
    if (existing && existing.status === 'active') throw new HttpError(409, 'already_approved');
    const photoB64 = String(b.photo || '');
    if (!photoB64 && !existing) throw new HttpError(400, 'photo_required');
    if (photoB64.length > 1_400_000) throw new HttpError(413, 'photo_too_big');
    if (photoB64) {
      const bytes = b64ToBytes(photoB64);
      if (!(bytes[0] === 0xff && bytes[1] === 0xd8)) throw new HttpError(400, 'photo_must_be_jpeg');
    }
    const pan = str('pan', 10).toUpperCase();
    if (!/^[A-Z]{5}[0-9]{4}[A-Z]$/.test(pan)) throw new HttpError(400, 'bad_pan');
    const aadhaar4 = str('aadhaarLast4', 4);
    if (!/^\d{4}$/.test(aadhaar4)) throw new HttpError(400, 'bad_aadhaar');
    const gstType = ['none', 'regular', 'composition'].includes(b.gstType) ? b.gstType : 'none';
    const gstin = gstType === 'none' ? '' : str('gstin', 15).toUpperCase();
    if (gstType !== 'none' && !/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/.test(gstin)) throw new HttpError(400, 'bad_gstin');
    if (gstType !== 'none' && gstin.slice(2, 12) !== pan) throw new HttpError(400, 'gstin_pan_mismatch');
    const fssai = str('fssai', 14).replace(/\D/g, '');
    if (fssai && fssai.length !== 14) throw new HttpError(400, 'bad_fssai');
    // Address: shop no. and landmark are typed; area, city, state and PIN come from the map pin.
    const a = (k, max = 120) => String((b.addr || {})[k] ?? '').trim().slice(0, max);
    const addr = { shop: a('shop', 80), landmark: a('landmark', 80), area: a('area'), city: a('city', 60), state: a('state', 60), pin: a('pin', 6) };
    if (kind === 'shop') {
      if (addr.shop.length < 1) throw new HttpError(400, 'shop_no_required');
      if (!addr.city || !/^\d{6}$/.test(addr.pin)) throw new HttpError(400, 'pin_area_missing');
    }
    const address = [addr.shop, addr.landmark, addr.area, addr.city, [addr.state, addr.pin].filter(Boolean).join(' ')].filter(Boolean).join(', ').slice(0, 300) || str('address', 200);
    let pLat = Number(b.photoLat), pLng = Number(b.photoLng);
    if (kind === 'shop') {
      if (!photoB64 && existing) { pLat = existing.photo_lat; pLng = existing.photo_lng; }
      // Shop: photo taken at the shop (GPS), and the map pin must be within 50 m of it.
      if (!Number.isFinite(pLat) || !Number.isFinite(pLng)) throw new HttpError(400, 'photo_location_required');
      if (distanceM(lat, lng, pLat, pLng) > MAX_PHOTO_DISTANCE_M) throw new HttpError(400, 'address_far');
    }
    const t = now();
    const id = existing?.id || `p_${crypto.randomUUID().slice(0, 8)}`;
    const cols = {
      name, kind, lat, lng, address, phone: u.partner_phone, phone_verified: 1, device_hash: u.partner_device_hash,
      opens_at: str('opensAt', 10), closes_at: str('closesAt', 10), door_delivery: b.door === false ? 0 : 1, pickup: b.pickup === false ? 0 : 1,
      fssai, gst_type: gstType, gstin, pan, aadhaar_last4: aadhaar4,
      addr_shop: addr.shop, addr_landmark: addr.landmark, addr_area: addr.area, addr_city: addr.city, addr_state: addr.state, addr_pin: addr.pin,
    };
    if (photoB64) Object.assign(cols, { photo_lat: kind === 'shop' ? pLat : null, photo_lng: kind === 'shop' ? pLng : null, photo_at: Number(b.photoAt) || t });
    const keys = Object.keys(cols);
    const stmts = [];
    if (existing) {
      // A rejected shop that is fixed goes back to "pending" until it is submitted again.
      stmts.push(env.DB.prepare(`UPDATE stores SET ${keys.map((k) => `${k} = ?`).join(', ')}, status = CASE WHEN status = 'rejected' THEN 'pending' ELSE status END WHERE id = ?`)
        .bind(...keys.map((k) => cols[k]), id));
    } else {
      stmts.push(env.DB.prepare(`INSERT INTO stores (${keys.join(', ')}, id, owner_id, status, live, pass_until, active, demo, created_at)
        VALUES (${keys.map(() => '?').join(', ')}, ?, ?, 'pending', 0, 0, 1, 0, ?)`).bind(...keys.map((k) => cols[k]), id, u.id, t));
    }
    if (photoB64) stmts.push(env.DB.prepare('INSERT OR REPLACE INTO store_photos (store_id, photo, updated_at) VALUES (?, ?, ?)').bind(id, photoB64, t));
    return json({ store: await writeAndRead(env, u.id, stmts) });
  }

  // ---------- documents (JPG / PDF, max 2 MB, uploaded in chunks so the app can show progress) ----------
  if (path === '/v1/partner/docs' && m === 'GET') {
    const { u, s, docs } = await ctx(req, env);
    if (!s) throw new HttpError(400, 'register_first');
    const out = storeOutWith(s, docs);
    return json({ docs, required: out.requiredDocs, optional: out.optionalDocs });
  }

  if (path === '/v1/partner/docs' && m === 'POST') {
    const { u, s, docs } = await ctx(req, env);
    if (!s) throw new HttpError(400, 'register_first');
    if (s.status === 'active' || s.status === 'review') throw new HttpError(409, 'docs_locked');
    const b = await body(req);
    const type = String(b.type || '');
    if (!DOC_TYPES.includes(type)) throw new HttpError(400, 'bad_doc_type');
    const mime = String(b.mime || '');
    if (!['image/jpeg', 'application/pdf'].includes(mime)) throw new HttpError(400, 'doc_must_be_jpg_or_pdf');
    const size = Number(b.size);
    if (!(size > 0)) throw new HttpError(400, 'doc_empty');
    if (size > MAX_DOC_BYTES) throw new HttpError(413, 'doc_too_big');
    const chunks = Number(b.chunks);
    if (!(chunks >= 1 && chunks <= 16)) throw new HttpError(400, 'bad_chunks');
    const id = `D${crypto.randomUUID().replace(/-/g, '').slice(0, 14)}`;
    await env.DB.prepare('INSERT INTO partner_docs (id, store_id, type, mime, name, size, chunks, done, created_at) VALUES (?,?,?,?,?,?,?,0,?)')
      .bind(id, s.id, type, mime, String(b.name || '').slice(0, 100), size, chunks, now()).run();
    return json({ id });
  }

  const chunk = path.match(/^\/v1\/partner\/docs\/(D\w+)\/(\d+)$/);
  if (chunk && m === 'PUT') {
    // One part of a document, sent as raw bytes (no base64 on the phone: ~25% less to upload).
    const { s } = await ctx(req, env);
    if (!s) throw new HttpError(404, 'no_doc');
    const docId = chunk[1], idx = Number(chunk[2]);
    const raw = new Uint8Array(await req.arrayBuffer());
    if (!raw.length || raw.length > 1_048_576) throw new HttpError(400, 'bad_chunk');
    // Save the part and see how many parts are in: one round trip.
    const [, info] = await env.DB.batch([
      env.DB.prepare(`INSERT OR REPLACE INTO doc_chunks (doc_id, idx, data)
        SELECT ?, ?, ? WHERE EXISTS (SELECT 1 FROM partner_docs WHERE id = ? AND store_id = ? AND chunks > ? AND done = 0)`)
        .bind(docId, idx, bytesToB64(raw), docId, s.id, idx),
      env.DB.prepare(`SELECT d.chunks, d.type, d.mime, d.done, (SELECT COUNT(*) FROM doc_chunks c WHERE c.doc_id = d.id) AS n,
        (SELECT substr(c.data, 1, 16) FROM doc_chunks c WHERE c.doc_id = d.id AND c.idx = 0) AS head
        FROM partner_docs d WHERE d.id = ? AND d.store_id = ?`).bind(docId, s.id),
    ]);
    const d = info.results[0];
    if (!d) throw new HttpError(404, 'no_doc');
    if (d.n < d.chunks) return json({ done: false, received: d.n });
    // All parts in: check it really is a JPG / PDF, keep only this one per type, and send back the list. One round trip.
    const first = d.head ? b64ToBytes(d.head) : new Uint8Array();
    const isJpg = first[0] === 0xff && first[1] === 0xd8;
    const isPdf = first[0] === 0x25 && first[1] === 0x50 && first[2] === 0x44 && first[3] === 0x46;
    if ((d.mime === 'image/jpeg' && !isJpg) || (d.mime === 'application/pdf' && !isPdf)) {
      await env.DB.batch([env.DB.prepare('DELETE FROM doc_chunks WHERE doc_id = ?').bind(docId), env.DB.prepare('DELETE FROM partner_docs WHERE id = ?').bind(docId)]);
      throw new HttpError(400, 'doc_must_be_jpg_or_pdf');
    }
    const res = await env.DB.batch([
      env.DB.prepare('UPDATE partner_docs SET done = 1 WHERE id = ?').bind(docId),
      env.DB.prepare('DELETE FROM doc_chunks WHERE doc_id IN (SELECT id FROM partner_docs WHERE store_id = ? AND type = ? AND id != ?)').bind(s.id, d.type, docId),
      env.DB.prepare('DELETE FROM partner_docs WHERE store_id = ? AND type = ? AND id != ?').bind(s.id, d.type, docId),
      env.DB.prepare('SELECT id, type, mime, name, size, created_at FROM partner_docs WHERE done = 1 AND store_id = ? ORDER BY created_at').bind(s.id),
    ]);
    return json({ done: true, docs: res[3].results.map(docOut) });
  }

  const myDoc = path.match(/^\/v1\/partner\/docs\/(D\w+)$/);
  if (myDoc && m === 'DELETE') {
    const { u, s, docs } = await ctx(req, env);
    if (!s) throw new HttpError(404, 'no_doc');
    if (s.status === 'active' || s.status === 'review') throw new HttpError(409, 'docs_locked');
    await env.DB.batch([
      env.DB.prepare('DELETE FROM doc_chunks WHERE doc_id IN (SELECT id FROM partner_docs WHERE id = ? AND store_id = ?)').bind(myDoc[1], s.id),
      env.DB.prepare('DELETE FROM partner_docs WHERE id = ? AND store_id = ?').bind(myDoc[1], s.id),
    ]);
    return json({ docs: await docList(env, s) });
  }

  if (path === '/v1/partner/submit' && m === 'POST') {
    // Send for Nukad team verification (needs all documents + the signed agreement).
    const { u, s, docs } = await ctx(req, env);
    if (!s) throw new HttpError(400, 'register_first');
    await submitForReview(env, s, docs);
    return json({ store: await writeAndRead(env, u.id) });
  }

  if (path === '/v1/partner/delete' && m === 'POST') {
    const { u, s, docs } = await ctx(req, env);
    const b = await body(req);
    const t = now();
    const stmts = [env.DB.prepare('INSERT INTO deletion_requests (id, user_id, reason, feedback, created_at) VALUES (?, ?, ?, ?, ?)')
      .bind(crypto.randomUUID(), u.id, 'partner: ' + String(b.reason || '').slice(0, 190), String(b.feedback || '').slice(0, 1000), t)];
    if (s) {
      // Shop, photo and documents go now. Signed agreement and pass payments stay (legal records); trial claims are hashes.
      stmts.push(
        env.DB.prepare('DELETE FROM doc_chunks WHERE doc_id IN (SELECT id FROM partner_docs WHERE store_id = ?)').bind(s.id),
        env.DB.prepare('DELETE FROM partner_docs WHERE store_id = ?').bind(s.id),
        env.DB.prepare('DELETE FROM store_photos WHERE store_id = ?').bind(s.id),
        env.DB.prepare(`UPDATE stores SET status = 'deleted', active = 0, live = 0, owner_id = NULL, pan = NULL, aadhaar_last4 = NULL, gstin = '',
          fssai = '', phone = NULL, addr_shop = NULL, addr_landmark = NULL, photo_lat = NULL, photo_lng = NULL WHERE id = ?`).bind(s.id),
      );
    }
    stmts.push(
      env.DB.prepare('UPDATE sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL').bind(t, u.id),
      env.DB.prepare(`UPDATE users SET google_sub = 'deleted:' || id, email = '', name = NULL, phone = NULL, phone_verified = 0,
        partner_phone = NULL, deleted_at = ?, updated_at = ? WHERE id = ?`).bind(t, t, u.id),
    );
    await env.DB.batch(stmts);
    return json({ ok: true });
  }

  if (path === '/v1/partner/payments' && m === 'POST') {
    const { u, s, docs } = await ctx(req, env);
    if (!s) throw new HttpError(400, 'register_first');
    const upi = await upiSettings(env);
    const b = await body(req);
    if (!upi.upiId && b.demo !== true) throw new HttpError(503, 'upi_not_set');
    const plan = PLANS[b.plan];
    if (!plan) throw new HttpError(400, 'bad_plan');
    const key = String(b.key || '').slice(0, 64);
    if (key.length < 16) throw new HttpError(400, 'bad_key');
    const same = await env.DB.prepare('SELECT * FROM pass_payments WHERE idem_key = ?').bind(key).first();
    if (same) return json({ payment: payPublic(same), ...upi });
    if (b.demo === true) {
      // Testing only: admins, or anyone while an admin has Test mode on. Marked DEMO everywhere.
      if (!upi.testMode && !(await isAdmin(env, u.email))) throw new HttpError(403, 'not_admin');
      const t = now();
      const id = `DEMO-${crypto.randomUUID().slice(0, 8).toUpperCase()}`;
      await env.DB.prepare(`INSERT INTO pass_payments (id, idem_key, store_id, owner_id, plan, amount, status, upi_status, app, checked_at, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, 'CREATED', 'DEMO', 'Demo', ?, ?, ?)`).bind(id, key, s.id, u.id, b.plan, plan.price, t, t, t).run();
      await activate(env, await env.DB.prepare('SELECT * FROM pass_payments WHERE id = ?').bind(id).first(), 'demo');
      const p = await env.DB.prepare('SELECT * FROM pass_payments WHERE id = ?').bind(id).first();
      return json({ payment: payPublic(p), store: await writeAndRead(env, u.id), ...upi });
    }
    // 3 failed / cancelled in 24 h: wait a day (stops abuse of "paid" claims).
    const bad = await env.DB.prepare("SELECT COUNT(*) AS n FROM pass_payments WHERE store_id = ? AND status IN ('FAILED','CANCELLED') AND created_at > ?")
      .bind(s.id, now() - 86400).first();
    if (bad.n >= 3) throw new HttpError(429, 'payments_paused');
    const seq = (await env.DB.prepare('SELECT COUNT(*) AS n FROM pass_payments').first()).n + 1;
    const id = `NK${String(s.id).replace(/\W/g, '').slice(-4).toUpperCase()}-${String(seq).padStart(4, '0')}`;
    const t = now();
    await env.DB.prepare(`INSERT INTO pass_payments (id, idem_key, store_id, owner_id, plan, amount, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, 'CREATED', ?, ?)`).bind(id, key, s.id, u.id, b.plan, plan.price, t, t).run();
    const p = await env.DB.prepare('SELECT * FROM pass_payments WHERE id = ?').bind(id).first();
    return json({ payment: payPublic(p), ...upi });
  }

  const done = path.match(/^\/v1\/partner\/payments\/([\w-]+)\/done$/);
  if (done && m === 'POST') {
    const { u } = await ctx(req, env);
    const p = await env.DB.prepare('SELECT * FROM pass_payments WHERE idem_key = ? AND owner_id = ?').bind(done[1], u.id).first();
    if (!p) throw new HttpError(404, 'no_payment');
    if (p.status !== 'CREATED') return json({ payment: payPublic(p) });
    const b = await body(req);
    const st = String(b.upiStatus || '').toUpperCase().slice(0, 20) || null;
    const ref = String(b.upiRef || '').slice(0, 60) || null;
    const app = String(b.app || '').slice(0, 40) || null;
    const t = now();
    if (st === 'FAILURE' || st === 'FAILED') {
      await env.DB.prepare("UPDATE pass_payments SET status='FAILED', upi_status=?, upi_ref=?, app=?, reason=?, updated_at=? WHERE id=?")
        .bind(st, ref, app, 'The UPI app said the payment failed', t, p.id).run();
    } else if (st === 'SUCCESS') {
      // The UPI app said SUCCESS: the pass starts now; the admin checks the bank and can cancel it.
      await env.DB.prepare('UPDATE pass_payments SET upi_status=?, upi_ref=?, app=?, updated_at=? WHERE id=?').bind(st, ref, app, t, p.id).run();
      await activate(env, p, 'upi-app');
    } else {
      await env.DB.prepare("UPDATE pass_payments SET status='CHECKING', upi_status=?, upi_ref=?, app=?, updated_at=? WHERE id=?")
        .bind(st, ref, app, t, p.id).run();
    }
    const out = await env.DB.prepare('SELECT * FROM pass_payments WHERE id = ?').bind(p.id).first();
    return json({ payment: payPublic(out), store: await writeAndRead(env, u.id) });
  }

  if (path === '/v1/partner/live' && m === 'POST') {
    const { u, s, docs } = await ctx(req, env);
    if (!s) throw new HttpError(400, 'register_first');
    const { on } = await body(req);
    if (on) {
      if (s.status === 'blocked') throw new HttpError(403, 'blocked');
      if (s.agreement_version !== AGREEMENT_VERSION) throw new HttpError(403, 'agreement_needed');
      if (s.status !== 'active') throw new HttpError(403, 'not_verified');
      if (!(s.pass_until > now())) throw new HttpError(402, 'no_pass');
    }
    // Going live again after the "5 missed orders" pause starts a fresh count for today. One round trip.
    const w = on ? env.DB.prepare('UPDATE stores SET live = 1, missed_count = 0 WHERE id = ?').bind(s.id)
      : env.DB.prepare('UPDATE stores SET live = 0 WHERE id = ?').bind(s.id);
    return json({ store: await writeAndRead(env, u.id, [w]) });
  }

  if (path === '/v1/partner/agreement' && m === 'GET') {
    const { u, s, docs } = await ctx(req, env);
    if (!s) throw new HttpError(400, 'register_first');
    const [lr, pr] = await env.DB.batch([
      env.DB.prepare('SELECT * FROM agreements WHERE store_id = ? ORDER BY accepted_at DESC LIMIT 1').bind(s.id),
      partyQuery(env),
    ]);
    const last = lr.results[0];
    return json({ version: AGREEMENT_VERSION, party: partyFrom(pr.results), vendor: vendorDetails(s, u),
      signed: last ? { version: last.version, name: last.signer_name, date: last.signed_date, acceptedAt: last.accepted_at,
        id: last.id, signature: last.signature, vendor: JSON.parse(last.snapshot).vendor } : null });
  }

  if (path === '/v1/partner/agreement' && m === 'POST') {
    const { u, s, docs } = await ctx(req, env);
    if (!s) throw new HttpError(400, 'register_first');
    const b = await body(req);
    if (b.version !== AGREEMENT_VERSION) throw new HttpError(409, 'agreement_changed');
    if (b.agree !== true || b.authorised !== true) throw new HttpError(400, 'agree_required');
    if (!storeOutWith(s, docs).docsComplete) throw new HttpError(400, 'docs_missing');
    const name = String(b.name || '').trim().slice(0, 80);
    if (name.length < 3) throw new HttpError(400, 'signer_name_required');
    const sig = String(b.signature || '');
    if (sig.length < 200 || sig.length > 400_000) throw new HttpError(400, 'signature_required');
    const png = b64ToBytes(sig);
    if (!(png[0] === 0x89 && png[1] === 0x50 && png[2] === 0x4e && png[3] === 0x47)) throw new HttpError(400, 'signature_required');
    const t = now();
    const id = `AG-${istDate(t).replace(/-/g, '')}-${crypto.randomUUID().slice(0, 6).toUpperCase()}`;
    const snapshot = JSON.stringify({ party: await partySettings(env), vendor: vendorDetails(s, u) });
    const signedDate = istDate(t).split('-').reverse().join('/');
    // Save, mark signed, send to "waiting for Nukad team", and read back: one round trip.
    const store = await writeAndRead(env, u.id, [
      env.DB.prepare(`INSERT INTO agreements (id, store_id, owner_id, version, signer_name, signature, snapshot, signed_date, accepted_at, device, ip)
        VALUES (?,?,?,?,?,?,?,?,?,?,?)`).bind(id, s.id, u.id, AGREEMENT_VERSION, name, sig, snapshot, signedDate, t,
        String(b.device || '').slice(0, 80), req.headers.get('cf-connecting-ip') || ''),
      env.DB.prepare("UPDATE stores SET agreement_version = ?, status = CASE WHEN status IN ('pending','rejected') THEN 'review' ELSE status END, review_note = NULL WHERE id = ?")
        .bind(AGREEMENT_VERSION, s.id),
    ]);
    return json({ id, store });
  }

  if (path === '/v1/admin/settings' && m === 'GET') {
    await admin(req, env);
    return json({ ...(await upiSettings(env)), party: await partySettings(env) });
  }

  if (path === '/v1/admin/settings' && m === 'PUT') {
    await admin(req, env);
    const b = await body(req);
    const stmts = [];
    const put = (key, v) => stmts.push(env.DB.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)').bind(key, v));
    if (b.upiId !== undefined) {
      const upiId = String(b.upiId || '').trim();
      if (!/^[\w.\-]{2,256}@[a-zA-Z][\w.\-]{1,64}$/.test(upiId)) throw new HttpError(400, 'bad_upi_id');
      put('upi_id', upiId);
      put('upi_name', String(b.upiName || 'Nukad Kart').trim().slice(0, 60) || 'Nukad Kart');
    }
    if (typeof b.testMode === 'boolean') put('test_mode', b.testMode ? '1' : '0');
    if (b.party && typeof b.party === 'object') {
      for (const [k, key] of Object.entries(PARTY_KEYS)) {
        if (b.party[k] !== undefined) put(key, String(b.party[k] || '').trim().slice(0, 300));
      }
    }
    if (stmts.length) await env.DB.batch(stmts);
    return json({ ...(await upiSettings(env)), party: await partySettings(env) });
  }

  if (path === '/v1/admin/partners' && m === 'GET') {
    await admin(req, env);
    const all = new URL(req.url).searchParams.get('status') === 'ALL';
    const { results } = await env.DB.prepare(
      `SELECT s.*, u.email AS owner_email FROM stores s LEFT JOIN users u ON u.id = s.owner_id
       WHERE s.owner_id IS NOT NULL AND s.demo = 0 ${all ? "AND s.status != 'deleted'" : "AND s.status = 'review'"} ORDER BY s.created_at DESC LIMIT 100`,
    ).all();
    const ids = results.map((r) => r.id);
    const all2 = ids.length
      ? (await env.DB.prepare(`SELECT id, store_id, type, mime, name, size, created_at FROM partner_docs WHERE done = 1 AND store_id IN (${ids.map(() => '?').join(',')})`)
        .bind(...ids).all()).results
      : [];
    const by = {};
    for (const d of all2) (by[d.store_id] ||= []).push(docOut(d));
    return json({ partners: results.map((r) => ({ ...storeOutWith(r, by[r.id] || []), ownerEmail: r.owner_email, docs: by[r.id] || [] })) });
  }

  const adDoc = path.match(/^\/v1\/admin\/docs\/(D\w+)$/);
  if (adDoc && m === 'GET') {
    await admin(req, env);
    const d = await env.DB.prepare('SELECT * FROM partner_docs WHERE id = ? AND done = 1').bind(adDoc[1]).first();
    if (!d) throw new HttpError(404, 'no_doc');
    const { results } = await env.DB.prepare('SELECT data FROM doc_chunks WHERE doc_id = ? ORDER BY idx').bind(d.id).all();
    const parts = results.map((r) => b64ToBytes(r.data));
    const bytes = new Uint8Array(parts.reduce((n, x) => n + x.length, 0));
    let o = 0;
    for (const x of parts) { bytes.set(x, o); o += x.length; }
    return new Response(bytes, { headers: { 'content-type': d.mime, 'cache-control': 'no-store' } });
  }

  const review = path.match(/^\/v1\/admin\/partners\/([\w-]+)\/(approve|reject)$/);
  if (review && m === 'POST') {
    const a = await admin(req, env);
    const s = await env.DB.prepare('SELECT * FROM stores WHERE id = ? AND owner_id IS NOT NULL').bind(review[1]).first();
    if (!s) throw new HttpError(404, 'no_store');
    const t = now();
    let trial = false;
    if (review[2] === 'approve') {
      const stmts = [];
      // Free trial: once per verified number and once per phone, given when the shop is approved.
      if (!s.trial_until && s.phone && (await trialAvailable(env, s.phone, s.device_hash))) {
        const until = Math.max(s.pass_until || 0, t) + TRIAL_DAYS * 86400;
        stmts.push(env.DB.prepare('UPDATE stores SET pass_until = ?, trial_until = ? WHERE id = ?').bind(until, until, s.id));
        stmts.push(env.DB.prepare('INSERT INTO trial_claims (id, phone_hash, device_hash, store_id, created_at) VALUES (?,?,?,?,?)')
          .bind(crypto.randomUUID(), await sha256Hex('phone:' + s.phone), s.device_hash, s.id, t));
        trial = true;
      }
      stmts.push(env.DB.prepare("UPDATE stores SET status = 'active', review_note = NULL, reviewed_at = ?, reviewed_by = ? WHERE id = ?").bind(t, a.email, s.id));
      await env.DB.batch(stmts);
    } else {
      const { reason } = await body(req);
      const note = String(reason || '').trim().slice(0, 300);
      if (note.length < 3) throw new HttpError(400, 'reason_required');
      await env.DB.prepare("UPDATE stores SET status = 'rejected', live = 0, review_note = ?, reviewed_at = ?, reviewed_by = ? WHERE id = ?")
        .bind(note, t, a.email, s.id).run();
    }
    return json({ trial, store: await storeOut(env, await env.DB.prepare('SELECT * FROM stores WHERE id = ?').bind(s.id).first()) });
  }

  if (path === '/v1/admin/payments' && m === 'GET') {
    await admin(req, env);
    const all = new URL(req.url).searchParams.get('status') === 'ALL';
    const { results } = await env.DB.prepare(
      `SELECT p.*, s.name AS store_name, s.kind AS store_kind FROM pass_payments p JOIN stores s ON s.id = p.store_id
       ${all ? '' : "WHERE p.status = 'CHECKING' OR (p.status = 'PAID' AND p.decided_by = 'upi-app' AND p.checked_at IS NULL)"}
       ORDER BY p.created_at DESC LIMIT 100`,
    ).all();
    return json({ payments: results.map((p) => ({ ...payPublic(p), store: p.store_name, kind: p.store_kind,
      upiRef: p.upi_ref, needsCheck: p.status === 'CHECKING' || (p.status === 'PAID' && !p.checked_at) })) });
  }

  const adm = path.match(/^\/v1\/admin\/payments\/([\w-]+)\/(confirm|cancel)$/);
  if (adm && m === 'POST') {
    const a = await admin(req, env);
    const p = await env.DB.prepare('SELECT * FROM pass_payments WHERE id = ?').bind(adm[1]).first();
    if (!p) throw new HttpError(404, 'no_payment');
    const t = now();
    if (adm[2] === 'confirm') {
      if (p.status === 'CHECKING') await activate(env, p, a.email);
      await env.DB.prepare('UPDATE pass_payments SET checked_at = ?, decided_by = COALESCE(decided_by, ?) WHERE id = ?').bind(t, a.email, p.id).run();
    } else {
      const { reason } = await body(req);
      const stmts = [env.DB.prepare("UPDATE pass_payments SET status='CANCELLED', reason=?, checked_at=?, decided_by=?, updated_at=? WHERE id=?")
        .bind(String(reason || 'Money not received').slice(0, 200), t, a.email, t, p.id)];
      // Undo the days this payment added.
      if (p.status === 'PAID') {
        stmts.push(env.DB.prepare('UPDATE stores SET pass_until = MAX(?, pass_until - ?) WHERE id = ?')
          .bind(t, PLANS[p.plan].days * 86400, p.store_id));
      }
      await env.DB.batch(stmts);
    }
    return json({ payment: payPublic(await env.DB.prepare('SELECT * FROM pass_payments WHERE id = ?').bind(p.id).first()) });
  }

  return null;
}
