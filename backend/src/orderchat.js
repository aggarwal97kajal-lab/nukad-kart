// Chat on a shop order: customer ↔ the shop and its delivery partner. Same window as calls (from accepting
// until 30 minutes after delivery). Phone numbers are not allowed in messages; kept 30 days.
//   GET/POST /v1/me/orders/:id/chat            (customer)
//   GET/POST /v1/partner/orders/:id/chat       (owner, or staff who handles orders / delivers this one)
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

export async function orderChatRoute(req, env, path, m) {
  const mc = path.match(/^\/v1\/me\/orders\/([\w-]+)\/chat$/);
  const pc = path.match(/^\/v1\/partner\/orders\/([\w-]+)\/chat$/);
  if (!mc && !pc) return null;
  let o, me, notify;
  if (mc) {
    const { uid } = await session(req, env);
    o = await env.DB.prepare('SELECT o.*, s.owner_id FROM orders o JOIN stores s ON s.id = o.store_id WHERE o.id = ? AND o.customer_id = ?').bind(mc[1], uid).first();
    if (!o) throw new HttpError(404, 'not_found');
    me = 'c';
    // The delivery partner on this order, else the shop owner.
    const st = o.staff_id ? await env.DB.prepare('SELECT user_id FROM staff WHERE id = ? AND removed_at IS NULL').bind(o.staff_id).first() : null;
    notify = st?.user_id || o.owner_id;
  } else {
    const c = await shopCtx(req, env);
    o = await env.DB.prepare('SELECT * FROM orders WHERE id = ? AND store_id = ?').bind(pc[1], c.s.id).first();
    if (!o || (c.staff && !c.canOrders && o.staff_id !== c.staff.id)) throw new HttpError(404, 'not_found');
    me = 's';
    notify = o.customer_id;
  }
  if (m === 'GET') {
    const { results } = await env.DB.prepare('SELECT * FROM order_messages WHERE order_id = ? ORDER BY created_at LIMIT 200').bind(o.id).all();
    return json({ messages: results.map((x) => out(x, me)), open: chatOpen(o) });
  }
  if (m !== 'POST') throw new HttpError(405, 'method');
  if (!chatOpen(o)) throw new HttpError(409, 'chat_closed');
  const text = String((await body(req)).text || '').trim().slice(0, MAX_LEN);
  if (!text) throw new HttpError(400, 'empty');
  if (hasNumber(text)) throw new HttpError(400, 'no_numbers');
  const t = now();
  const id = `M${crypto.randomUUID().replace(/-/g, '').slice(0, 14)}`;
  await env.DB.prepare('INSERT INTO order_messages (id, order_id, sender, text, created_at) VALUES (?, ?, ?, ?, ?)').bind(id, o.id, me, text, t).run();
  await sendPush(env, notify, {
    title: me === 'c' ? `💬 Customer · #${o.id}` : `💬 Delivery partner · #${o.id}`,
    body: text.slice(0, 120),
    data: { type: 'order_chat', id: o.id },
  }).catch(() => {});
  return json({ message: out({ id, sender: me, text, created_at: t }, me) });
}
