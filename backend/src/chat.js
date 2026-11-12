// Chat customer ↔ thela. Text only; phone numbers are refused; messages are deleted after 24 hours.
//   GET  /v1/me/chats/:thelaId                 (customer) messages with this thela
//   POST /v1/me/chats/:thelaId { text, address?, lat?, lng? }
//   POST /v1/me/chats/:thelaId/block | /report { reason }
//   GET  /v1/partner/chats                     (thela) list
//   GET  /v1/partner/chats/:id                 (thela) messages
//   POST /v1/partner/chats/:id { text }  ·  /block  ·  /report { reason }
//   POST /v1/thelas/:id/watch                  (anyone) someone is looking at this thela: faster location for 30 s
import { HttpError, json, body, now, session } from './index.js';
import { ctx } from './partner.js';
import { sendPush } from './push.js';

export const CHAT_KEEP_S = 86400;
const REPORTS = 3, REPORT_DAYS = 30, BLOCK_DAYS = 7, MAX_LEN = 300;
const NUM_WORDS = /\b(zero|shunya|one|ek|two|do|three|teen|four|char|chaar|five|paanch|panch|six|chhe|che|seven|saat|eight|aath|nine|nau|ten|das)\b/gi;

/** True when the text carries a phone number: 7+ digits (spaces, dashes, dots ignored) or 7+ number words. */
export function hasNumber(text) {
  const digits = String(text).replace(/[\s\-.()+]/g, '').match(/\d{7,}/);
  if (digits) return true;
  const words = String(text).match(NUM_WORDS) || [];
  return words.length >= 7;
}

/**
 * Live chat: one Durable Object per chat holds the open phone connections (WebSocket) and passes
 * every new message on at once. Messages are still saved in D1 (the source of truth).
 */
export class ChatRoom {
  constructor(state) {
    this.state = state;
  }

  async fetch(req) {
    if (new URL(req.url).pathname === '/broadcast') {
      const msg = await req.text();
      for (const ws of this.state.getWebSockets()) {
        try {
          ws.send(msg);
        } catch {}
      }
      return new Response('ok');
    }
    if (req.headers.get('upgrade') !== 'websocket') return new Response('expected websocket', { status: 426 });
    const pair = new WebSocketPair();
    this.state.acceptWebSocket(pair[1]); // hibernates while idle: no cost between messages
    return new Response(null, { status: 101, webSocket: pair[0] });
  }

  webSocketMessage(ws, msg) {
    if (msg === 'ping') ws.send('pong');
  }

  webSocketClose(ws, code) {
    try {
      ws.close(code, 'bye');
    } catch {}
  }
}

async function broadcast(env, chatId, payload) {
  if (!env.CHAT) return;
  try {
    await env.CHAT.get(env.CHAT.idFromName(chatId)).fetch('https://chat/broadcast', { method: 'POST', body: JSON.stringify(payload) });
  } catch {}
}

const msgOut = (m) => ({ id: m.id, from: m.sender === 'c' ? 'customer' : 'thela', text: m.text, at: m.created_at });

async function messages(env, chatId) {
  const { results } = await env.DB.prepare('SELECT * FROM chat_messages WHERE chat_id = ? AND created_at > ? ORDER BY created_at LIMIT 200')
    .bind(chatId, now() - CHAT_KEEP_S).all();
  return results.map(msgOut);
}

async function report(env, chat, by, against, reason) {
  const t = now();
  await env.DB.prepare('INSERT INTO reports (id, chat_id, by_user, against_user, reason, created_at) VALUES (?, ?, ?, ?, ?, ?)')
    .bind(crypto.randomUUID(), chat?.id || null, by, against, String(reason || '').slice(0, 200), t).run();
  const r = await env.DB.prepare('SELECT COUNT(DISTINCT by_user) AS n FROM reports WHERE against_user = ? AND created_at > ?').bind(against, t - REPORT_DAYS * 86400).first();
  if (r.n >= REPORTS) await env.DB.prepare('UPDATE users SET chat_blocked_until = ? WHERE id = ?').bind(t + BLOCK_DAYS * 86400, against).run();
}

function clean(text) {
  const s = String(text || '').trim().slice(0, MAX_LEN);
  if (!s) throw new HttpError(400, 'empty');
  if (hasNumber(s)) throw new HttpError(400, 'no_numbers');
  return s;
}

export async function chatRoute(req, env, path, m) {
  // GET /v1/chat/socket?chat=<id>&token=<session>  → WebSocket to that chat's room (only its two people).
  if (path === '/v1/chat/socket' && m === 'GET') {
    const url = new URL(req.url);
    const chatId = url.searchParams.get('chat') || '';
    const authed = new Request(req.url, { headers: { authorization: `Bearer ${url.searchParams.get('token') || ''}` } });
    const chat = await env.DB.prepare('SELECT c.*, s.owner_id FROM chats c JOIN stores s ON s.id = c.thela_id WHERE c.id = ?').bind(chatId).first();
    if (!chat) throw new HttpError(404, 'not_found');
    const { uid } = await session(authed, env);
    if (uid !== chat.customer_id && uid !== chat.owner_id) throw new HttpError(403, 'not_yours');
    if (!env.CHAT) throw new HttpError(503, 'live_chat_off');
    return env.CHAT.get(env.CHAT.idFromName(chatId)).fetch(req);
  }

  const watch = path.match(/^\/v1\/thelas\/([\w-]+)\/watch$/);
  if (watch && m === 'POST') {
    await env.DB.prepare("UPDATE stores SET watched_until = ? WHERE id = ? AND kind = 'thela'").bind(now() + 30, watch[1]).run();
    return json({ ok: true });
  }

  const mc = path.match(/^\/v1\/me\/chats\/([\w-]+)(?:\/(block|unblock|report))?$/);
  if (mc) {
    const { uid } = await session(req, env);
    const thelaId = mc[1];
    const chat = await env.DB.prepare('SELECT * FROM chats WHERE thela_id = ? AND customer_id = ?').bind(thelaId, uid).first();
    if (m === 'GET' && !mc[2]) {
      if (!chat) return json({ chatId: null, messages: [], blocked: null });
      await env.DB.prepare('UPDATE chats SET customer_read_at = ? WHERE id = ?').bind(now(), chat.id).run();
      return json({ chatId: chat.id, messages: await messages(env, chat.id), blocked: chat.blocked_by });
    }
    if (m !== 'POST') throw new HttpError(405, 'method');
    const s = await env.DB.prepare("SELECT id, name, owner_id FROM stores WHERE id = ? AND kind = 'thela'").bind(thelaId).first();
    if (!s) throw new HttpError(404, 'not_found');
    const b = await body(req);
    if (mc[2] === 'unblock') {
      // Only the side that blocked can open it again.
      if (chat) await env.DB.prepare("UPDATE chats SET blocked_by = NULL WHERE id = ? AND blocked_by = 'customer'").bind(chat.id).run();
      return json({ ok: true });
    }
    if (mc[2] === 'block') {
      if (chat) await env.DB.prepare("UPDATE chats SET blocked_by = 'customer' WHERE id = ?").bind(chat.id).run();
      return json({ ok: true });
    }
    if (mc[2] === 'report') {
      if (s.owner_id) await report(env, chat, uid, s.owner_id, b.reason);
      if (chat) await env.DB.prepare("UPDATE chats SET blocked_by = 'customer' WHERE id = ?").bind(chat.id).run();
      return json({ ok: true });
    }
    const u = await env.DB.prepare('SELECT chat_blocked_until FROM users WHERE id = ?').bind(uid).first();
    if (u?.chat_blocked_until > now()) throw new HttpError(403, 'chat_blocked');
    if (chat?.blocked_by) throw new HttpError(403, 'chat_closed');
    const text = clean(b.text);
    const t = now();
    let id = chat?.id;
    if (!id) {
      id = crypto.randomUUID();
      await env.DB.prepare('INSERT INTO chats (id, thela_id, customer_id, address, lat, lng, last_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
        .bind(id, thelaId, uid, String(b.address || '').slice(0, 160), Number(b.lat) || null, Number(b.lng) || null, t, t).run();
    } else if (b.address) {
      await env.DB.prepare('UPDATE chats SET address = ?, lat = ?, lng = ? WHERE id = ?').bind(String(b.address).slice(0, 160), Number(b.lat) || null, Number(b.lng) || null, id).run();
    }
    await env.DB.batch([
      env.DB.prepare("INSERT INTO chat_messages (id, chat_id, sender, text, created_at) VALUES (?, ?, 'c', ?, ?)").bind(crypto.randomUUID(), id, text, t),
      env.DB.prepare('UPDATE chats SET last_at = ?, customer_read_at = ? WHERE id = ?').bind(t, t, id),
    ]);
    await broadcast(env, id, { type: 'message', from: 'customer', text, at: t });
    if (s.owner_id) {
      const addr = b.address || chat?.address || '';
      await sendPush(env, s.owner_id, { title: `Message${addr ? ` · ${addr}` : ''}`, body: text, data: { type: 'chat', chatId: id }, channel: 'calls' });
    }
    return json({ chatId: id, messages: await messages(env, id), blocked: null });
  }

  if (path === '/v1/partner/chats' && m === 'GET') {
    const { s } = await ctx(req, env);
    if (!s || s.kind !== 'thela') return json({ chats: [] });
    const { results } = await env.DB.prepare(`SELECT c.*, (SELECT text FROM chat_messages WHERE chat_id = c.id ORDER BY created_at DESC LIMIT 1) AS last_text
      FROM chats c WHERE c.thela_id = ? AND c.last_at > ? ORDER BY c.last_at DESC LIMIT 50`).bind(s.id, now() - CHAT_KEEP_S).all();
    return json({ chats: results.map((c) => ({ id: c.id, address: c.address, lastText: c.last_text || '', lastAt: c.last_at, unread: c.last_at > c.thela_read_at, blocked: c.blocked_by })) });
  }

  const pc = path.match(/^\/v1\/partner\/chats\/([\w-]+)(?:\/(block|unblock|report))?$/);
  if (pc) {
    const { u, s } = await ctx(req, env);
    if (!s || s.kind !== 'thela') throw new HttpError(400, 'thela_only');
    const chat = await env.DB.prepare('SELECT * FROM chats WHERE id = ? AND thela_id = ?').bind(pc[1], s.id).first();
    if (!chat) throw new HttpError(404, 'not_found');
    if (m === 'GET' && !pc[2]) {
      await env.DB.prepare('UPDATE chats SET thela_read_at = ? WHERE id = ?').bind(now(), chat.id).run();
      return json({ messages: await messages(env, chat.id), blocked: chat.blocked_by, address: chat.address });
    }
    if (m !== 'POST') throw new HttpError(405, 'method');
    const b = await body(req);
    if (pc[2] === 'unblock') {
      await env.DB.prepare("UPDATE chats SET blocked_by = NULL WHERE id = ? AND blocked_by = 'thela'").bind(chat.id).run();
      return json({ ok: true });
    }
    if (pc[2] === 'block' || pc[2] === 'report') {
      if (pc[2] === 'report') await report(env, chat, u.id, chat.customer_id, b.reason);
      await env.DB.prepare("UPDATE chats SET blocked_by = 'thela' WHERE id = ?").bind(chat.id).run();
      return json({ ok: true });
    }
    if (chat.blocked_by) throw new HttpError(403, 'chat_closed');
    const text = clean(b.text);
    const t = now();
    await env.DB.batch([
      env.DB.prepare("INSERT INTO chat_messages (id, chat_id, sender, text, created_at) VALUES (?, ?, 't', ?, ?)").bind(crypto.randomUUID(), chat.id, text, t),
      env.DB.prepare('UPDATE chats SET last_at = ?, thela_read_at = ? WHERE id = ?').bind(t, t, chat.id),
    ]);
    await broadcast(env, chat.id, { type: 'message', from: 'thela', text, at: t });
    await sendPush(env, chat.customer_id, { title: s.name, body: text, data: { type: 'chat', thelaId: s.id } });
    return json({ messages: await messages(env, chat.id), blocked: null });
  }
  return null;
}

/** Cron: delete chat messages older than 24 hours. */
export async function cleanChats(env) {
  const t = now() - CHAT_KEEP_S;
  await env.DB.batch([
    env.DB.prepare('DELETE FROM chat_messages WHERE created_at < ?').bind(t),
    env.DB.prepare('DELETE FROM chats WHERE last_at < ?').bind(t),
  ]);
}
