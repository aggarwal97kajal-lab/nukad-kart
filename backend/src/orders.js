// Shop orders (customer → shop) and shop staff.
//
// Customer (Nukad Kart app):
//   POST /v1/orders                     { storeId, door, items:[{id, qty}], address, state, lat, lng, name, phone, gstin?, business? }
//   GET  /v1/me/orders                  my orders (newest first)
//   POST /v1/me/orders/:id/cancel       only while placed / accepted
// Shop (Nukad Partner app, owner or staff):
//   GET  /v1/partner/orders?tab=new|packing|out|done
//   POST /v1/partner/orders/:id/accept | /reject {reason}
//   POST /v1/partner/orders/:id/send    { na:[line index…], staffId? }  packed → out for delivery / ready for pickup
//   POST /v1/partner/orders/:id/deliver { otp, pay: cash|upi }          right code → delivered + bill number
//   POST /v1/partner/rider              { lat, lng }                    delivery person's position while delivering
//   GET/POST /v1/partner/staff, DELETE /v1/partner/staff/:id           owner manages staff
// Staff login (no Google):
//   POST /v1/staff/check { phone }  → is this number staff anywhere?  (before the SMS is sent)
//   POST /v1/staff/login { phone, accessToken, device }
import { HttpError, json, body, now, session, haversineM, verifyMsg91, signSession, RADIUS_MAX_M } from './index.js';
import { ctx, offlineReason, istDate, MISSED_LIMIT } from './partner.js';
import { sendPush } from './push.js';

export const RING_S = 300; // the shop has 5 minutes to accept
const FREE_DELIVERY_MIN = 199, DELIVERY_FEE = 20, MAX_LIVE = 2, MAX_STAFF = 5, MAX_OTP_TRIES = 5;
const OPEN = ['placed', 'accepted', 'packed', 'out'];

const rid = () => crypto.randomUUID();
const orderNo = () => 'NK-' + String(Math.floor(100000 + Math.random() * 900000));
const phone10 = (v) => String(v || '').replace(/\D/g, '').slice(-10);

/** Financial year label for bill numbers, e.g. "2627" for Apr 2026 – Mar 2027 (IST). */
export function fy(t = now()) {
  const d = new Date((t + 5.5 * 3600) * 1000);
  const y = d.getUTCFullYear() % 100, start = d.getUTCMonth() >= 3 ? y : y - 1;
  return `${String(start).padStart(2, '0')}${String((start + 1) % 100).padStart(2, '0')}`;
}

function prefixOf(s) {
  if (s.bill_prefix) return s.bill_prefix;
  const w = String(s.name || '').split(/\s+/).filter(Boolean).map((x) => x[0].toUpperCase()).join('').replace(/[^A-Z0-9]/g, '');
  return (w || 'NK').slice(0, 4);
}

function orderOut(o, forCustomer, store) {
  const lines = JSON.parse(o.lines);
  return {
    id: o.id, storeId: o.store_id, storeName: store?.name, door: !!o.door, status: o.status, lines,
    itemsTotal: o.items_total, fee: o.fee, total: o.total, address: o.address, state: o.state, lat: o.lat, lng: o.lng,
    toName: o.to_name, toPhone: forCustomer ? o.to_phone : o.to_phone, buyerGstin: o.buyer_gstin, buyerBusiness: o.buyer_business,
    otp: forCustomer && o.status === 'out' ? o.otp : undefined, staffId: o.staff_id, payMode: o.pay_mode, billNo: o.bill_no || '',
    reason: o.reason || '', createdAt: o.created_at, acceptedAt: o.accepted_at, packedAt: o.packed_at, outAt: o.out_at, deliveredAt: o.delivered_at, closedAt: o.closed_at,
    ringLeft: o.status === 'placed' ? Math.max(0, o.created_at + RING_S - now()) : 0,
    rider: o.status === 'out' && o.rider_at && now() - o.rider_at < 600 ? { lat: o.rider_lat, lng: o.rider_lng, ago: now() - o.rider_at } : null,
  };
}

/** Orders a shop didn't answer in 5 minutes → missed; 5 missed in a day pauses the shop (offlineReason). */
export async function expireOrders(env, storeId = null) {
  const t = now();
  const { results } = await env.DB.prepare(`UPDATE orders SET status = 'missed', closed_at = ? WHERE status = 'placed' AND created_at < ?
    ${storeId ? 'AND store_id = ?' : ''} RETURNING id, store_id, customer_id`).bind(t, t - RING_S, ...(storeId ? [storeId] : [])).all();
  const today = istDate(t);
  for (const o of results) {
    await env.DB.prepare(`UPDATE stores SET missed_count = CASE WHEN missed_date = ? THEN missed_count + 1 ELSE 1 END, missed_date = ? WHERE id = ?`)
      .bind(today, today, o.store_id).run();
  }
  return results;
}

/** Cron: tell customers about missed orders. */
export async function tellMissedOrders(env) {
  await expireOrders(env);
  const { results } = await env.DB.prepare(`SELECT o.id, o.customer_id, s.name FROM orders o JOIN stores s ON s.id = o.store_id
    WHERE o.status = 'missed' AND o.told = 0 AND o.created_at > ? LIMIT 200`).bind(now() - 86400).all();
  for (const o of results) {
    await env.DB.prepare('UPDATE orders SET told = 1 WHERE id = ?').bind(o.id).run();
    await sendPush(env, o.customer_id, { title: `${o.name} didn’t answer`, body: `Order #${o.id} was cancelled. You were not charged. Try another shop nearby.`, data: { type: 'order', id: o.id } });
  }
}

/** Who is calling from the Partner app: the owner (all rights) or a staff member (limited). */
async function shopCtx(req, env) {
  const { u, s } = await ctx(req, env);
  if (s) return { u, s, owner: true, canOrders: true, staff: null };
  if (u.app === 'staff') {
    const st = await env.DB.prepare('SELECT * FROM staff WHERE user_id = ? AND removed_at IS NULL').bind(u.id).first();
    if (!st) throw new HttpError(401, 'not_signed_in');
    const store = await env.DB.prepare('SELECT * FROM stores WHERE id = ? AND active = 1').bind(st.store_id).first();
    if (!store) throw new HttpError(401, 'not_signed_in');
    return { u, s: store, owner: false, canOrders: !!st.can_orders, staff: st };
  }
  throw new HttpError(400, 'register_first');
}

async function ringShop(env, s, o) {
  // Data-only + high priority: the Partner app shows a ringing notification that repeats for up to 5 minutes.
  const data = { type: 'order_new', id: o.id, title: `New order ₹${o.total} · ${o.items} items`, body: `${o.door ? 'Door delivery' : 'Pickup'} · ${o.address}`.slice(0, 120) };
  const staff = (await env.DB.prepare('SELECT user_id FROM staff WHERE store_id = ? AND can_orders = 1 AND removed_at IS NULL AND user_id IS NOT NULL').bind(s.id).all()).results;
  for (const uid of [s.owner_id, ...staff.map((x) => x.user_id)].filter(Boolean)) {
    await sendPush(env, uid, { title: data.title, body: data.body, data, channel: 'orders', dataOnly: true });
  }
}

export function staffOut(st) {
  return { id: st.id, name: st.name, phone: st.phone, canOrders: !!st.can_orders, loggedIn: !!st.user_id, createdAt: st.created_at };
}

/** /v1/partner/me for a staff login. */
export async function staffMe(env, u) {
  const st = await env.DB.prepare('SELECT * FROM staff WHERE user_id = ? AND removed_at IS NULL').bind(u.id).first();
  if (!st) throw new HttpError(401, 'not_signed_in');
  const s = await env.DB.prepare('SELECT id, name, kind, status FROM stores WHERE id = ?').bind(st.store_id).first();
  return { staff: { ...staffOut(st), storeId: s?.id, storeName: s?.name || '', storeKind: s?.kind || 'shop' } };
}

export async function orderRoute(req, env, path, m) {
  // ---------- customer ----------
  if (path === '/v1/orders' && m === 'POST') {
    const { uid } = await session(req, env);
    const b = await body(req);
    const t = now();
    const items = (Array.isArray(b.items) ? b.items : []).slice(0, 60).map((x) => ({ id: String(x.id || ''), qty: Math.floor(Number(x.qty)) }))
      .filter((x) => x.id && x.qty > 0 && x.qty <= 50);
    if (!items.length) throw new HttpError(400, 'empty_cart');
    const door = b.door !== false;
    const baseIds = [...new Set(items.map((x) => x.id.replace(/_\d+$/, '')))];
    const [sr, pr, lr, ur] = await env.DB.batch([
      env.DB.prepare('SELECT * FROM stores WHERE id = ? AND active = 1').bind(String(b.storeId || '')),
      env.DB.prepare(`SELECT * FROM products WHERE store_id = ? AND in_stock = 1 AND id IN (${baseIds.map(() => '?').join(',')})`).bind(String(b.storeId || ''), ...baseIds),
      env.DB.prepare(`SELECT COUNT(*) AS n FROM orders WHERE customer_id = ? AND status IN ('placed','accepted','packed','out')`).bind(uid),
      env.DB.prepare('SELECT id, deleted_at FROM users WHERE id = ?').bind(uid),
    ]);
    const s = sr.results[0];
    if (!ur.results[0] || ur.results[0].deleted_at) throw new HttpError(401, 'not_signed_in');
    if (!s || s.kind === 'thela' || offlineReason(s, t) != null) throw new HttpError(409, 'shop_closed');
    if (lr.results[0].n >= MAX_LIVE) throw new HttpError(409, 'too_many_orders');
    const lat = Number(b.lat), lng = Number(b.lng);
    if (door) {
      if (!s.door_delivery) throw new HttpError(400, 'no_door_delivery');
      if (!Number.isFinite(lat) || !Number.isFinite(lng) || haversineM(lat, lng, s.lat, s.lng) > RADIUS_MAX_M) throw new HttpError(400, 'too_far');
    }
    const prods = new Map(pr.results.map((p) => [p.id, p]));
    const lines = [];
    for (const it of items) {
      const [pid, n] = it.id.includes('_') ? [it.id.replace(/_\d+$/, ''), Number(it.id.split('_').pop())] : [it.id, null];
      const p = prods.get(pid);
      if (!p) continue; // sold out or removed meanwhile
      let price, size;
      if (p.kind === 'loose') {
        const opts = JSON.parse(p.options || '[]');
        if (!opts.includes(n)) continue;
        price = Math.round(p.unit === 'kg' || p.unit === 'litre' ? (p.price * n) / 1000 : p.price * n);
        size = p.unit === 'kg' ? (n >= 1000 ? `${n / 1000} kg` : `${n} g`) : p.unit === 'litre' ? (n >= 1000 ? `${n / 1000} L` : `${n} ml`) : `${n} ${p.unit}`;
      } else {
        price = Math.round(p.price);
        size = p.size || '';
      }
      lines.push({ pid: it.id, name: p.brand && !p.name.toLowerCase().includes(p.brand.toLowerCase()) ? `${p.brand} ${p.name}` : p.name,
        size, qty: it.qty, price, gst: p.gst, hsn: p.hsn || '', na: false });
    }
    if (!lines.length) throw new HttpError(409, 'items_unavailable');
    const itemsTotal = lines.reduce((a, l) => a + l.price * l.qty, 0);
    const fee = door && itemsTotal < FREE_DELIVERY_MIN ? DELIVERY_FEE : 0;
    const str = (k, max) => String(b[k] ?? '').trim().slice(0, max);
    const gstin = str('gstin', 15).toUpperCase();
    const o = { id: orderNo(), store_id: s.id, customer_id: uid, door: door ? 1 : 0, lines: JSON.stringify(lines), items_total: itemsTotal, fee,
      total: itemsTotal + fee, address: door ? str('address', 240) : 'Pickup from the shop', state: str('state', 40), lat: door ? lat : null, lng: door ? lng : null,
      to_name: str('name', 80), to_phone: phone10(b.phone), buyer_gstin: /^[0-9A-Z]{15}$/.test(gstin) ? gstin : '', buyer_business: gstin ? str('business', 100) : '',
      created_at: t };
    const keys = Object.keys(o);
    for (let i = 0; i < 3; i++) {
      try {
        await env.DB.prepare(`INSERT INTO orders (${keys}) VALUES (${keys.map(() => '?')})`).bind(...Object.values(o)).run();
        break;
      } catch (e) {
        if (i === 2 || !/UNIQUE|PRIMARY/i.test(String(e.message))) throw e;
        o.id = orderNo();
      }
    }
    await ringShop(env, s, { id: o.id, total: o.total, items: lines.reduce((a, l) => a + l.qty, 0), door, address: o.address });
    const row = await env.DB.prepare('SELECT * FROM orders WHERE id = ?').bind(o.id).first();
    return json({ order: orderOut(row, true, s), skipped: items.length - lines.length });
  }

  if (path === '/v1/me/orders' && m === 'GET') {
    const { uid } = await session(req, env);
    const { results } = await env.DB.prepare(`SELECT o.*, s.name AS store_name FROM orders o JOIN stores s ON s.id = o.store_id
      WHERE o.customer_id = ? ORDER BY o.created_at DESC LIMIT 50`).bind(uid).all();
    const t = now();
    // Show "missed" right away (the cron only tells by push every few minutes).
    for (const o of results) if (o.status === 'placed' && o.created_at < t - RING_S) o.status = 'missed';
    return json({ orders: results.map((o) => orderOut(o, true, { name: o.store_name })) });
  }

  const cc = path.match(/^\/v1\/me\/orders\/([\w-]+)\/cancel$/);
  if (cc && m === 'POST') {
    const { uid } = await session(req, env);
    const o = await env.DB.prepare(`UPDATE orders SET status = 'cancelled', reason = 'customer', closed_at = ? WHERE id = ? AND customer_id = ?
      AND status IN ('placed', 'accepted') RETURNING *`).bind(now(), cc[1], uid).first();
    if (!o) throw new HttpError(409, 'cannot_cancel');
    const s = await env.DB.prepare('SELECT owner_id, name FROM stores WHERE id = ?').bind(o.store_id).first();
    if (s?.owner_id) await sendPush(env, s.owner_id, { title: `Order #${o.id} cancelled`, body: 'The customer cancelled it. Don’t pack it.', data: { type: 'order', id: o.id } });
    return json({ order: orderOut(o, true, s) });
  }

  // ---------- staff login ----------
  if (path === '/v1/staff/check' && m === 'POST') {
    const p = phone10((await body(req)).phone);
    if (!/^[6-9]\d{9}$/.test(p)) throw new HttpError(400, 'bad_phone');
    const st = await env.DB.prepare('SELECT id FROM staff WHERE phone = ? AND removed_at IS NULL').bind(p).first();
    if (!st) throw new HttpError(404, 'not_staff');
    return json({ ok: true });
  }

  if (path === '/v1/staff/login' && m === 'POST') {
    if (!env.MSG91_AUTHKEY) throw new HttpError(503, 'phone_check_not_configured');
    const b = await body(req);
    const p = phone10(b.phone);
    const verified = await verifyMsg91(b.accessToken, env.MSG91_AUTHKEY);
    // Strict: the SMS-verified number must be the staff number (no Google account behind a staff login).
    if (!verified || verified !== p) throw new HttpError(401, 'phone_mismatch');
    const st = await env.DB.prepare('SELECT * FROM staff WHERE phone = ? AND removed_at IS NULL').bind(p).first();
    if (!st) throw new HttpError(404, 'not_staff');
    const t = now();
    let uid = st.user_id;
    if (!uid) {
      uid = rid();
      await env.DB.batch([
        env.DB.prepare("INSERT INTO users (id, google_sub, email, name, app, phone, phone_verified, created_at, updated_at) VALUES (?, ?, '', ?, 'staff', ?, 1, ?, ?)")
          .bind(uid, `staff:${st.id}`, st.name, p, t, t),
        env.DB.prepare('UPDATE staff SET user_id = ? WHERE id = ?').bind(uid, st.id),
      ]);
    }
    const d = b.device || {};
    const sid = rid();
    await env.DB.prepare('INSERT INTO sessions (id, user_id, device, platform, city, created_at, last_seen, device_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
      .bind(sid, uid, String(d.name || 'Partner app').slice(0, 60), String(d.platform || 'Android').slice(0, 30), null, t, t, String(d.id || '').slice(0, 80) || null).run();
    return json({ token: await signSession(uid, env.SESSION_SECRET, 30, sid), staff: staffOut({ ...st, user_id: uid }) });
  }

  if (!path.startsWith('/v1/partner/orders') && !path.startsWith('/v1/partner/staff') && path !== '/v1/partner/rider') return null;

  // ---------- staff management (owner only) ----------
  if (path === '/v1/partner/staff' && m === 'GET') {
    const { s, owner } = await shopCtx(req, env);
    if (!owner) throw new HttpError(403, 'owner_only');
    const { results } = await env.DB.prepare('SELECT * FROM staff WHERE store_id = ? AND removed_at IS NULL ORDER BY created_at').bind(s.id).all();
    return json({ staff: results.map(staffOut), max: MAX_STAFF });
  }
  if (path === '/v1/partner/staff' && m === 'POST') {
    const { u, s, owner } = await shopCtx(req, env);
    if (!owner) throw new HttpError(403, 'owner_only');
    const b = await body(req);
    const name = String(b.name || '').trim().slice(0, 60), p = phone10(b.phone);
    if (name.length < 2) throw new HttpError(400, 'name_required');
    if (!/^[6-9]\d{9}$/.test(p)) throw new HttpError(400, 'bad_phone');
    if (p === u.partner_phone) throw new HttpError(400, 'own_number');
    const [cnt, other] = await env.DB.batch([
      env.DB.prepare('SELECT COUNT(*) AS n FROM staff WHERE store_id = ? AND removed_at IS NULL').bind(s.id),
      env.DB.prepare('SELECT store_id FROM staff WHERE phone = ? AND removed_at IS NULL').bind(p),
    ]);
    if (other.results.length) throw new HttpError(409, other.results[0].store_id === s.id ? 'already_staff' : 'staff_elsewhere');
    if (cnt.results[0].n >= MAX_STAFF) throw new HttpError(409, 'staff_limit');
    const st = { id: rid(), store_id: s.id, name, phone: p, can_orders: b.canOrders === true ? 1 : 0, created_at: now() };
    await env.DB.prepare('INSERT INTO staff (id, store_id, name, phone, can_orders, created_at) VALUES (?, ?, ?, ?, ?, ?)')
      .bind(st.id, st.store_id, st.name, st.phone, st.can_orders, st.created_at).run();
    return json({ staff: staffOut(st) });
  }
  const sd = path.match(/^\/v1\/partner\/staff\/([\w-]+)$/);
  if (sd && m === 'DELETE') {
    const { s, owner } = await shopCtx(req, env);
    if (!owner) throw new HttpError(403, 'owner_only');
    const st = await env.DB.prepare('SELECT * FROM staff WHERE id = ? AND store_id = ? AND removed_at IS NULL').bind(sd[1], s.id).first();
    if (!st) throw new HttpError(404, 'not_found');
    const t = now();
    const stmts = [env.DB.prepare('UPDATE staff SET removed_at = ? WHERE id = ?').bind(t, st.id)];
    // Logged out on their phone at once.
    if (st.user_id) stmts.push(env.DB.prepare('UPDATE sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL').bind(t, st.user_id));
    await env.DB.batch(stmts);
    return json({ ok: true });
  }

  // ---------- shop orders ----------
  const c = await shopCtx(req, env);
  const { s } = c;

  if (path === '/v1/partner/rider' && m === 'POST') {
    const b = await body(req);
    const lat = Number(b.lat), lng = Number(b.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) throw new HttpError(400, 'bad_location');
    const who = c.staff ? c.staff.id : null;
    await env.DB.prepare(`UPDATE orders SET rider_lat = ?, rider_lng = ?, rider_at = ? WHERE store_id = ? AND status = 'out' AND door = 1
      AND ${who ? 'staff_id = ?' : 'staff_id IS NULL'}`).bind(lat, lng, now(), s.id, ...(who ? [who] : [])).run();
    return json({ ok: true });
  }

  if (path === '/v1/partner/orders' && m === 'GET') {
    if ((await expireOrders(env, s.id)).length) Object.assign(s, await env.DB.prepare('SELECT missed_date, missed_count FROM stores WHERE id = ?').bind(s.id).first());
    const tab = new URL(req.url).searchParams.get('tab') || 'new';
    const where = { new: "status = 'placed'", packing: "status IN ('accepted','packed')", out: "status = 'out'", done: "status IN ('delivered','rejected','missed','cancelled')" }[tab];
    if (!where) throw new HttpError(400, 'bad_tab');
    // Delivery-only staff see only orders given to them.
    const mineOnly = c.staff && !c.canOrders;
    // Delivery-only staff: their packed orders show under "On the way" (ready to start) and out ones.
    const whereMine = mineOnly && tab === 'out' ? "status IN ('packed','out')" : where;
    const { results } = await env.DB.prepare(`SELECT * FROM orders WHERE store_id = ? AND ${whereMine} ${mineOnly ? 'AND staff_id = ?' : ''}
      AND created_at > ? ORDER BY created_at ${tab === 'done' ? 'DESC' : 'ASC'} LIMIT 50`).bind(s.id, ...(mineOnly ? [c.staff.id] : []), now() - 7 * 86400).all();
    const counts = (await env.DB.prepare(`SELECT status, COUNT(*) AS n FROM orders WHERE store_id = ? AND status IN ('placed','accepted','packed','out')
      ${mineOnly ? 'AND staff_id = ?' : ''} GROUP BY status`).bind(s.id, ...(mineOnly ? [c.staff.id] : [])).all()).results;
    // Staff chips show who is free: "Ramesh · on a delivery" (has a packed / out order), "Suresh · free".
    const staff = c.owner || c.canOrders
      ? (await env.DB.prepare(`SELECT st.*, (SELECT COUNT(*) FROM orders o WHERE o.staff_id = st.id AND o.status IN ('packed','out')) AS busy
          FROM staff st WHERE st.store_id = ? AND st.removed_at IS NULL`).bind(s.id).all()).results.map((x) => ({ ...staffOut(x), busy: x.busy > 0 })) : [];
    const mine = await env.DB.prepare(`SELECT COUNT(*) AS n FROM orders WHERE store_id = ? AND status = 'out' AND door = 1 AND ${c.staff ? 'staff_id = ?' : 'staff_id IS NULL'}`)
      .bind(s.id, ...(c.staff ? [c.staff.id] : [])).first();
    return json({ orders: results.map((o) => orderOut(o, false, s)), counts: Object.fromEntries(counts.map((x) => [x.status, x.n])), staff, myDoorOut: mine.n,
      missedToday: s.missed_date === istDate() ? s.missed_count : 0, missedLimit: MISSED_LIMIT });
  }

  const one = path.match(/^\/v1\/partner\/orders\/([\w-]+)$/);
  if (one && m === 'GET') {
    const o = await env.DB.prepare('SELECT * FROM orders WHERE id = ? AND store_id = ?').bind(one[1], s.id).first();
    if (!o || (c.staff && !c.canOrders && o.staff_id !== c.staff.id)) throw new HttpError(404, 'not_found');
    const staff = (await env.DB.prepare(`SELECT st.*, (SELECT COUNT(*) FROM orders o WHERE o.staff_id = st.id AND o.status IN ('packed','out')) AS busy
      FROM staff st WHERE st.store_id = ? AND st.removed_at IS NULL`).bind(s.id).all()).results.map((x) => ({ ...staffOut(x), busy: x.busy > 0 }));
    return json({ order: orderOut(o, false, s), staff: c.owner || c.canOrders ? staff : [] });
  }

  const act = path.match(/^\/v1\/partner\/orders\/([\w-]+)\/(accept|reject|send|pack|out|deliver)$/);
  if (act && m === 'POST') {
    const [, id, what] = act;
    const b = await body(req);
    const o = await env.DB.prepare('SELECT * FROM orders WHERE id = ? AND store_id = ?').bind(id, s.id).first();
    if (!o) throw new HttpError(404, 'not_found');
    const t = now();
    if (what !== 'deliver' && what !== 'out' && !c.canOrders) throw new HttpError(403, 'not_allowed');
    if (what === 'out') {
      // The delivery person taps "Out for delivery" on their own phone (their location then goes to the customer).
      if (o.status !== 'packed') throw new HttpError(409, o.status === 'out' ? 'already_out' : 'not_packed');
      if (c.staff && !c.canOrders && o.staff_id !== c.staff.id) throw new HttpError(403, 'not_your_delivery');
      const r = await env.DB.prepare("UPDATE orders SET status = 'out', out_at = ? WHERE id = ? AND status = 'packed' RETURNING *").bind(t, id).first();
      await sendPush(env, o.customer_id, {
        title: o.door ? `Order #${id} is on the way` : `Order #${id} is ready for pickup`,
        body: `Your delivery code: ${o.otp}. Give it only after you get your items.`,
        data: { type: 'order', id },
      });
      return json({ order: orderOut(r, false, s) });
    }
    if (what === 'accept' || what === 'reject') {
      if (o.status !== 'placed' || o.created_at < t - RING_S) throw new HttpError(409, o.status === 'placed' ? 'too_late' : 'already_answered');
      const ok = what === 'accept';
      const r = await env.DB.prepare(`UPDATE orders SET status = ?, accepted_at = ?, closed_at = ?, reason = ? WHERE id = ? AND status = 'placed' RETURNING *`)
        .bind(ok ? 'accepted' : 'rejected', ok ? t : null, ok ? null : t, ok ? null : String(b.reason || '').slice(0, 80) || null, id).first();
      await sendPush(env, o.customer_id, ok
        ? { title: `${s.name} accepted your order`, body: `#${id} is being packed.`, data: { type: 'order', id } }
        : { title: `${s.name} couldn’t take your order`, body: `#${id} was not accepted${r.reason ? `: ${r.reason}` : ''}. Try another shop nearby.`, data: { type: 'order', id } });
      return json({ order: orderOut(r, false, s) });
    }
    if (what === 'send' || what === 'pack') {
      if (o.status !== 'accepted') throw new HttpError(409, 'not_packing');
      const lines = JSON.parse(o.lines);
      const na = new Set((Array.isArray(b.na) ? b.na : []).map(Number));
      lines.forEach((l, i) => { l.na = na.has(i); });
      const itemsTotal = lines.filter((l) => !l.na).reduce((a, l) => a + l.price * l.qty, 0);
      if (!itemsTotal) {
        // Nothing left to send: cancel and tell the customer.
        const r = await env.DB.prepare("UPDATE orders SET status = 'cancelled', reason = 'items_unavailable', lines = ?, closed_at = ? WHERE id = ? RETURNING *")
          .bind(JSON.stringify(lines), t, id).first();
        await sendPush(env, o.customer_id, { title: `${s.name} had none of your items`, body: `Order #${id} was cancelled. You were not charged.`, data: { type: 'order', id } });
        return json({ order: orderOut(r, false, s) });
      }
      const fee = o.door && itemsTotal < FREE_DELIVERY_MIN ? DELIVERY_FEE : 0;
      let staffId = b.staffId ? String(b.staffId) : null;
      if (staffId && !(await env.DB.prepare('SELECT id FROM staff WHERE id = ? AND store_id = ? AND removed_at IS NULL').bind(staffId, s.id).first())) staffId = null;
      const otp = String(1000 + Math.floor(Math.random() * 9000));
      const outNow = what === 'send' || !o.door; // pickup orders: packed = ready for pickup at once
      const r = await env.DB.prepare(`UPDATE orders SET status = ?, lines = ?, items_total = ?, fee = ?, total = ?, otp = ?, staff_id = ?, packed_at = ?, out_at = ?
        WHERE id = ? AND status = 'accepted' RETURNING *`).bind(outNow ? 'out' : 'packed', JSON.stringify(lines), itemsTotal, fee, itemsTotal + fee, otp, staffId, t, outNow ? t : null, id).first();
      const gone = lines.filter((l) => l.na);
      if (!outNow) {
        await sendPush(env, o.customer_id, {
          title: `Order #${id} is packed`,
          body: `${gone.length ? `${gone.map((l) => l.name).join(', ')} not available — new total ₹${itemsTotal + fee}. ` : ''}It leaves the shop soon.`,
          data: { type: 'order', id },
        });
        if (staffId) {
          const su = await env.DB.prepare('SELECT user_id FROM staff WHERE id = ?').bind(staffId).first();
          // Data-only: the Partner app shows it with a "Start delivery" button.
          if (su?.user_id) await sendPush(env, su.user_id, { title: '', body: '', dataOnly: true,
            data: { type: 'deliver', id, title: `Deliver #${id} · collect ₹${itemsTotal + fee}`, body: o.address } });
        }
        return json({ order: orderOut(r, false, s) });
      }
      await sendPush(env, o.customer_id, {
        title: o.door ? `Order #${id} is on the way` : `Order #${id} is ready for pickup`,
        body: `${gone.length ? `${gone.map((l) => l.name).join(', ')} not available — new total ₹${itemsTotal + fee}. ` : ''}Your delivery code: ${otp}. Give it only after you get your items.`,
        data: { type: 'order', id },
      });
      if (staffId) {
        const su = await env.DB.prepare('SELECT user_id FROM staff WHERE id = ?').bind(staffId).first();
        if (su?.user_id) await sendPush(env, su.user_id, { title: `Deliver #${id}`, body: `${o.address} · collect ₹${itemsTotal + fee}`, data: { type: 'order', id } });
      }
      return json({ order: orderOut(r, false, s) });
    }
    // deliver
    if (o.status !== 'out') throw new HttpError(409, 'not_out');
    if (c.staff && !c.canOrders && o.staff_id !== c.staff.id) throw new HttpError(403, 'not_your_delivery');
    if (o.otp_tries >= MAX_OTP_TRIES) throw new HttpError(429, 'too_many_tries');
    if (String(b.otp || '').trim() !== o.otp) {
      await env.DB.prepare('UPDATE orders SET otp_tries = otp_tries + 1 WHERE id = ?').bind(id).run();
      throw new HttpError(400, 'wrong_code');
    }
    const year = fy(t);
    const seq = await env.DB.prepare(`INSERT INTO bill_seq (store_id, fy, seq) VALUES (?, ?, 1)
      ON CONFLICT (store_id, fy) DO UPDATE SET seq = seq + 1 RETURNING seq`).bind(s.id, year).first();
    const billNo = `${prefixOf(s)}/${year}/${String(seq.seq).padStart(4, '0')}`;
    const r = await env.DB.prepare(`UPDATE orders SET status = 'delivered', pay_mode = ?, bill_no = ?, delivered_at = ?, closed_at = ? WHERE id = ? AND status = 'out' RETURNING *`)
      .bind(b.pay === 'upi' ? 'upi' : 'cash', billNo, t, t, id).first();
    await sendPush(env, o.customer_id, { title: 'Order delivered', body: `#${id} from ${s.name}. Your bill ${billNo} is in the app.`, data: { type: 'order', id } });
    return json({ order: orderOut(r, false, s) });
  }
  throw new HttpError(404, 'not_found');
}

