// Chat on a shop order: customer ↔ the shop and its delivery partner. Same window as calls (from accepting
// until 30 minutes after delivery). Phone numbers are not allowed in messages; kept 30 days.
//   GET/POST /v1/me/orders/:id/chat            (customer)
//   GET/POST /v1/partner/orders/:id/chat       (owner, or staff who handles orders / delivers this one)
//   GET      /v1/orders/:id/chat/socket?token= WebSocket: new messages and "read" arrive at once (no waiting for a poll)
// Sending answers at once; the notification to the other side goes out after the answer (waitUntil).
import { HttpError, json, body, now, session } from './index.js';
import { hasNumber } from './chat.js';
import { shopCtx } from './orders.js';
import { sendPush } from './push.js';
import { AFTER_DELIVERY_S } from './voice.js';

const MAX_LEN = 300, KEEP_DAYS = 30;

export const chatOpen = (o, t = now()) => ['accepted', 'packed', 'out'].includes(o.status)
  || (o.status === 'delivered' && t - (o.delivered_at || o.closed_at || 0) <= AFTER_DELIVERY_S);

const out = (m, me) => ({ id: m.id, mine: m.sender === me, text: m.text, at: m.created_at });

export async function cleanOrderChat(env, t = now()) {
  await env.DB.prepare('DELETE FROM order_messages WHERE created_at < ?').bind(t - KEEP_DAYS * 86400).run();
}

const room = (env, orderId) => env.CHAT.get(env.CHAT.idFromName(`ochat:${orderId}`));

/** Send to every phone that has this order's live socket open (chat messages, read ticks, the scooter's spot). */
export async function orderLive(env, orderId, payload) {
  if (!env.CHAT) return;
  try {
    await room(env, orderId).fetch('https://chat/broadcast', { method: 'POST', body: JSON.stringify(payload) });
  } catch {}
}

const later = (ectx, p) => {
  const q = Promise.resolve(p).catch(() => {});
  if (ectx?.waitUntil) ectx.waitUntil(q);
  return ectx?.waitUntil ? null : q;
};

export async function orderChatRoute(req, env, path, m, ectx) {
  const sock = path.match(/^\/v1\/orders\/([\w-]+)\/chat\/socket$/);
  if (sock && m === 'GET') {
    const url = new URL(req.url);
    const authed = new Request(req.url, { headers: { authorization: `Bearer ${url.searchParams.get('token') || ''}` } });
    const { uid } = await session(authed, env);
    const o = await env.DB.prepare(`SELECT o.id, o.customer_id, s.owner_id,
        (SELECT 1 FROM staff st WHERE st.store_id = o.store_id AND st.user_id = ? AND st.removed_at IS NULL) AS is_staff
      FROM orders o JOIN stores s ON s.id = o.store_id WHERE o.id = ?`).bind(uid, sock[1]).first();
    if (!o || (uid !== o.customer_id && uid !== o.owner_id && !o.is_staff)) throw new HttpError(404, 'not_found');
    if (!env.CHAT) throw new HttpError(503, 'live_chat_off');
    return room(env, o.id).fetch(new Request(req.url, { headers: { upgrade: 'websocket' } }));
  }

  const mc = path.match(/^\/v1\/me\/orders\/([\w-]+)\/chat$/);
  const pc = path.match(/^\/v1\/partner\/orders\/([\w-]+)\/chat$/);
  if (!mc && !pc) return null;
  let o, me, notify;
  if (mc) {
    const { uid } = await session(req, env);
    o = await env.DB.prepare('SELECT o.*, s.owner_id FROM orders o JOIN stores s ON s.id = o.store_id WHERE o.id = ? AND o.customer_id = ?').bind(mc[1], uid).first();
    if (!o) throw new HttpError(404, 'not_found');
    me = 'c';
    // The shop owner and the delivery partner on this order both hear about it.
    const st = o.staff_id ? await env.DB.prepare('SELECT user_id FROM staff WHERE id = ? AND removed_at IS NULL').bind(o.staff_id).first() : null;
    notify = [...new Set([o.owner_id, st?.user_id].filter(Boolean))];
  } else {
    const c = await shopCtx(req, env);
    o = await env.DB.prepare('SELECT * FROM orders WHERE id = ? AND store_id = ?').bind(pc[1], c.s.id).first();
    if (!o || (c.staff && !c.canOrders && o.staff_id !== c.staff.id)) throw new HttpError(404, 'not_found');
    me = 's';
    notify = [o.customer_id];
  }
  const t = now();
  const otherRead = (me === 'c' ? o.chat_s_read : o.chat_c_read) || 0;
  if (m === 'GET') {
    const { results } = await env.DB.prepare('SELECT * FROM order_messages WHERE order_id = ? ORDER BY created_at LIMIT 200').bind(o.id).all();
    // Mark read for my side; tell the other phone (its ticks turn blue) only when something new was read.
    const mine = me === 'c' ? 'chat_c_read' : 'chat_s_read';
    const lastOther = results.filter((x) => x.sender !== me).at(-1)?.created_at || 0;
    if (lastOther && (o[mine] || 0) < lastOther) {
      await env.DB.prepare(`UPDATE orders SET ${mine} = ? WHERE id = ?`).bind(t, o.id).run();
      later(ectx, orderLive(env, o.id, { type: 'read', by: me, at: t }));
    }
    return json({ messages: results.map((x) => out(x, me)), open: chatOpen(o), otherReadAt: otherRead });
  }
  if (m !== 'POST') throw new HttpError(405, 'method');
  if (!chatOpen(o)) throw new HttpError(409, 'chat_closed');
  const text = String((await body(req)).text || '').trim().slice(0, MAX_LEN);
  if (!text) throw new HttpError(400, 'empty');
  if (hasNumber(text)) throw new HttpError(400, 'no_numbers');
  const id = `M${crypto.randomUUID().replace(/-/g, '').slice(0, 14)}`;
  await env.DB.prepare('INSERT INTO order_messages (id, order_id, sender, text, created_at) VALUES (?, ?, ?, ?, ?)').bind(id, o.id, me, text, t).run();
  // The other phone's open chat shows it at once; the notification goes out after this answer.
  const rest = Promise.all([
    orderLive(env, o.id, { type: 'message', id, sender: me, text, at: t }),
    ...notify.map((uid) => sendPush(env, uid, {
      title: me === 'c' ? `💬 Customer · #${o.id}` : `💬 ${o.staff_id ? 'Delivery partner' : 'Store'} · #${o.id}`,
      body: text.slice(0, 120),
      data: { type: 'order_chat', id: o.id },
    })),
  ]);
  const wait = later(ectx, rest);
  if (wait) await wait; // tests / no waitUntil
  return json({ message: out({ id, sender: me, text, created_at: t }, me), otherReadAt: otherRead });
}
