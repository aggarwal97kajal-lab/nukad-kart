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
import { HttpError, json, body, now, session } from './index.js';

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
  if (!s.agreement_version) return 'no_agreement';
  if (!(s.pass_until > t)) return 'no_pass';
  if (!s.live) return 'switched_off';
  if (s.missed_date === istDate(t) && s.missed_count >= MISSED_LIMIT) return 'missed_orders';
  if (!openAt(s.opens_at, s.closes_at, t)) return 'closed_now';
  return null;
}

// ---------- helpers ----------
async function me(req, env) {
  const { uid } = await session(req, env);
  const user = await env.DB.prepare('SELECT id, email, name, phone FROM users WHERE id = ?').bind(uid).first();
  return user;
}

export async function sha256Hex(text) {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function isAdmin(env, email) {
  const list = String(env.ADMIN_EMAIL_HASHES || '').toLowerCase().split(',').map((s) => s.trim()).filter(Boolean);
  if (!list.length || !email) return false;
  return list.includes(await sha256Hex(String(email).trim().toLowerCase()));
}

const PARTY_KEYS = { legalName: 'party_legal_name', address: 'party_address', city: 'party_city', pan: 'party_pan', email: 'party_email' };

async function partySettings(env) {
  const { results } = await env.DB.prepare(`SELECT key, value FROM settings WHERE key IN (${Object.values(PARTY_KEYS).map(() => '?').join(',')})`)
    .bind(...Object.values(PARTY_KEYS)).all();
  const m = Object.fromEntries(results.map((r) => [r.key, r.value]));
  return Object.fromEntries(Object.entries(PARTY_KEYS).map(([k, key]) => [k, m[key] || '']));
}

async function upiSettings(env) {
  const { results } = await env.DB.prepare("SELECT key, value FROM settings WHERE key IN ('upi_id','upi_name')").all();
  const m = Object.fromEntries(results.map((r) => [r.key, r.value]));
  return { upiId: m.upi_id || '', upiName: m.upi_name || 'Nukad Kart' };
}

async function admin(req, env) {
  const u = await me(req, env);
  if (!(await isAdmin(env, u.email))) throw new HttpError(403, 'not_admin');
  return u;
}

async function myStore(env, uid) {
  return env.DB.prepare('SELECT * FROM stores WHERE owner_id = ? ORDER BY created_at DESC LIMIT 1').bind(uid).first();
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
    missedToday: s.missed_date === istDate(t) ? s.missed_count : 0, hasPhoto: !!s.photo_at,
  };
}

function vendorDetails(s, u) {
  return { storeName: s.name, kind: s.kind, address: s.address || '', phone: s.phone || '', email: u.email || '',
    gstType: s.gst_type || 'none', gstin: s.gstin || '', fssai: s.fssai || '' };
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
    const u = await me(req, env);
    const s = await myStore(env, u.id);
    const pays = s
      ? (await env.DB.prepare('SELECT * FROM pass_payments WHERE store_id = ? ORDER BY created_at DESC LIMIT 10').bind(s.id).all()).results
      : [];
    return json({ user: { email: u.email, name: u.name }, admin: await isAdmin(env, u.email), store: publicStore(s),
      payments: pays.map(payPublic) });
  }

  if (path === '/v1/partner/register' && m === 'POST') {
    const u = await me(req, env);
    const b = await body(req);
    const str = (k, max = 120) => String(b[k] ?? '').trim().slice(0, max);
    const kind = b.kind === 'thela' ? 'thela' : 'shop';
    const name = str('name', 80);
    if (name.length < 2) throw new HttpError(400, 'name_required');
    const lat = Number(b.lat), lng = Number(b.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) throw new HttpError(400, 'location_required');
    if (kind === 'shop' && (parseTime(b.opensAt) == null || parseTime(b.closesAt) == null)) throw new HttpError(400, 'timings_required');
    const photoB64 = String(b.photo || '');
    if (!photoB64) throw new HttpError(400, 'photo_required');
    if (photoB64.length > 1_400_000) throw new HttpError(413, 'photo_too_big');
    const bytes = b64ToBytes(photoB64);
    if (!(bytes[0] === 0xff && bytes[1] === 0xd8)) throw new HttpError(400, 'photo_must_be_jpeg');
    const gstType = ['none', 'regular', 'composition'].includes(b.gstType) ? b.gstType : 'none';
    const gstin = gstType === 'none' ? '' : str('gstin', 15).toUpperCase();
    if (gstType !== 'none' && !/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/.test(gstin)) throw new HttpError(400, 'bad_gstin');
    const pLat = Number(b.photoLat), pLng = Number(b.photoLng);
    if (kind === 'shop') {
      // Shop: photo taken at the shop (GPS), and the map pin must be within 50 m of it.
      if (!Number.isFinite(pLat) || !Number.isFinite(pLng)) throw new HttpError(400, 'photo_location_required');
      if (distanceM(lat, lng, pLat, pLng) > MAX_PHOTO_DISTANCE_M) throw new HttpError(400, 'address_far');
    }
    const fssai = str('fssai', 14).replace(/\D/g, '');
    if (fssai && fssai.length !== 14) throw new HttpError(400, 'bad_fssai');
    const t = now();
    const existing = await myStore(env, u.id);
    const id = existing?.id || `p_${crypto.randomUUID().slice(0, 8)}`;
    const vals = [name, kind, lat, lng, str('address', 200), str('phone', 20), str('opensAt', 10), str('closesAt', 10),
      b.door === false ? 0 : 1, b.pickup === false ? 0 : 1, fssai, gstType, gstin,
      kind === 'shop' ? pLat : null, kind === 'shop' ? pLng : null, Number(b.photoAt) || t];
    const stmts = [];
    if (existing) {
      stmts.push(env.DB.prepare(`UPDATE stores SET name=?, kind=?, lat=?, lng=?, address=?, phone=?, opens_at=?, closes_at=?,
        door_delivery=?, pickup=?, fssai=?, gst_type=?, gstin=?, photo_lat=?, photo_lng=?, photo_at=? WHERE id=?`).bind(...vals, id));
    } else {
      stmts.push(env.DB.prepare(`INSERT INTO stores (name, kind, lat, lng, address, phone, opens_at, closes_at, door_delivery, pickup,
        fssai, gst_type, gstin, photo_lat, photo_lng, photo_at, id, owner_id, status, live, pass_until, trial_until, active, demo, created_at)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?, 'active', 0, ?, ?, 1, 0, ?)`).bind(...vals, id, u.id, t + TRIAL_DAYS * 86400, t + TRIAL_DAYS * 86400, t));
    }
    stmts.push(env.DB.prepare('INSERT OR REPLACE INTO store_photos (store_id, photo, updated_at) VALUES (?, ?, ?)').bind(id, photoB64, t));
    await env.DB.batch(stmts);
    return json({ store: publicStore(await myStore(env, u.id)) });
  }

  if (path === '/v1/partner/payments' && m === 'POST') {
    const u = await me(req, env);
    const s = await myStore(env, u.id);
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
      // Testing only: admins can start a pass without paying. Marked DEMO everywhere.
      if (!(await isAdmin(env, u.email))) throw new HttpError(403, 'not_admin');
      const t = now();
      const id = `DEMO-${crypto.randomUUID().slice(0, 8).toUpperCase()}`;
      await env.DB.prepare(`INSERT INTO pass_payments (id, idem_key, store_id, owner_id, plan, amount, status, upi_status, app, checked_at, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, 'CREATED', 'DEMO', 'Demo', ?, ?, ?)`).bind(id, key, s.id, u.id, b.plan, plan.price, t, t, t).run();
      await activate(env, await env.DB.prepare('SELECT * FROM pass_payments WHERE id = ?').bind(id).first(), 'demo');
      const p = await env.DB.prepare('SELECT * FROM pass_payments WHERE id = ?').bind(id).first();
      return json({ payment: payPublic(p), store: publicStore(await myStore(env, u.id)), ...upi });
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
    const u = await me(req, env);
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
    return json({ payment: payPublic(out), store: publicStore(await myStore(env, u.id)) });
  }

  if (path === '/v1/partner/live' && m === 'POST') {
    const u = await me(req, env);
    const s = await myStore(env, u.id);
    if (!s) throw new HttpError(400, 'register_first');
    const { on } = await body(req);
    if (on) {
      if (s.status === 'blocked') throw new HttpError(403, 'blocked');
      if (s.agreement_version !== AGREEMENT_VERSION) throw new HttpError(403, 'agreement_needed');
      if (!(s.pass_until > now())) throw new HttpError(402, 'no_pass');
      // Going live again after the "3 missed orders" pause starts a fresh count for today.
      await env.DB.prepare('UPDATE stores SET live = 1, missed_count = 0 WHERE id = ?').bind(s.id).run();
    } else {
      await env.DB.prepare('UPDATE stores SET live = 0 WHERE id = ?').bind(s.id).run();
    }
    return json({ store: publicStore(await myStore(env, u.id)) });
  }

  if (path === '/v1/partner/agreement' && m === 'GET') {
    const u = await me(req, env);
    const s = await myStore(env, u.id);
    if (!s) throw new HttpError(400, 'register_first');
    const last = await env.DB.prepare('SELECT * FROM agreements WHERE store_id = ? ORDER BY accepted_at DESC LIMIT 1').bind(s.id).first();
    return json({ version: AGREEMENT_VERSION, party: await partySettings(env), vendor: vendorDetails(s, u),
      signed: last ? { version: last.version, name: last.signer_name, date: last.signed_date, acceptedAt: last.accepted_at,
        id: last.id, signature: last.signature, vendor: JSON.parse(last.snapshot).vendor } : null });
  }

  if (path === '/v1/partner/agreement' && m === 'POST') {
    const u = await me(req, env);
    const s = await myStore(env, u.id);
    if (!s) throw new HttpError(400, 'register_first');
    const b = await body(req);
    if (b.version !== AGREEMENT_VERSION) throw new HttpError(409, 'agreement_changed');
    if (b.agree !== true) throw new HttpError(400, 'agree_required');
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
    await env.DB.batch([
      env.DB.prepare(`INSERT INTO agreements (id, store_id, owner_id, version, signer_name, signature, snapshot, signed_date, accepted_at, device, ip)
        VALUES (?,?,?,?,?,?,?,?,?,?,?)`).bind(id, s.id, u.id, AGREEMENT_VERSION, name, sig, snapshot, signedDate, t,
        String(b.device || '').slice(0, 80), req.headers.get('cf-connecting-ip') || ''),
      env.DB.prepare('UPDATE stores SET agreement_version = ? WHERE id = ?').bind(AGREEMENT_VERSION, s.id),
    ]);
    return json({ id, store: publicStore(await myStore(env, u.id)) });
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
    if (b.party && typeof b.party === 'object') {
      for (const [k, key] of Object.entries(PARTY_KEYS)) {
        if (b.party[k] !== undefined) put(key, String(b.party[k] || '').trim().slice(0, 300));
      }
    }
    if (stmts.length) await env.DB.batch(stmts);
    return json({ ...(await upiSettings(env)), party: await partySettings(env) });
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
