// In-app voice calls with no phone numbers shown (WebRTC; audio goes phone-to-phone, or through Cloudflare TURN
// when a network blocks that). The server only checks who may call whom, rings the other phone, and passes the
// connection messages through a Durable Object room. Audio is never recorded; the call log is kept 90 days.
//
//   POST /v1/voice/start { kind: 'order'|'thela', ref }   (auth) → { call, ice }
//        order: the customer ↔ the delivery person on that order (the shop owner while nobody is assigned);
//               from the shop accepting until 30 minutes after delivery.
//        thela: the customer ↔ the thela, while the thela is "Coming" to the customer's street (calls row).
//   GET  /v1/voice/:id                                    (auth) the call (for the screen that opened from a push)
//   POST /v1/voice/:id/answer | decline | end             (auth)
//   GET  /v1/voice/:id/socket?token=                      WebSocket: offer / answer / ice / bye between the two phones
//
// Limits (per order / per street call): at most 10 connected calls (missed ones don't count); at most 3 calls
// started in a minute; after 3 missed in a row, a 2-minute break ("send a chat instead").
import { HttpError, json, body, now, session } from './index.js';
import { sendPush } from './push.js';

export const MAX_CONNECTED = 10;
export const PER_MINUTE = 3;
export const MISSED_IN_ROW = 3;
export const BREAK_S = 120;
export const RING_S = 40; // unanswered after this = missed
export const AFTER_DELIVERY_S = 30 * 60;
export const KEEP_DAYS = 90;

/** Who is on each side of a call about this order / street call, and whether calling is open now. */
export async function parties(env, kind, ref, t = now()) {
  if (kind === 'order') {
    const o = await env.DB.prepare(`SELECT o.id, o.customer_id, o.status, o.accepted_at, o.delivered_at, o.closed_at, o.staff_id, s.owner_id, s.name,
        (SELECT user_id FROM staff WHERE id = o.staff_id AND removed_at IS NULL) AS staff_user
      FROM orders o JOIN stores s ON s.id = o.store_id WHERE o.id = ?`).bind(ref).first();
    if (!o) throw new HttpError(404, 'not_found');
    const open = ['accepted', 'packed', 'out'].includes(o.status)
      || (o.status === 'delivered' && t - (o.delivered_at || o.closed_at || 0) <= AFTER_DELIVERY_S);
    // The customer reaches the delivery person on this order, or the shop while nobody is assigned.
    const seller = o.staff_user || o.owner_id;
    return { open, customer: o.customer_id, seller, sellers: [o.owner_id, o.staff_user].filter(Boolean),
      sellerLabel: 'Delivery partner', customerLabel: 'Customer', title: `Order #${o.id}` };
  }
  if (kind === 'thela') {
    const c = await env.DB.prepare(`SELECT c.id, c.customer_id, c.status, s.owner_id, s.name FROM calls c JOIN stores s ON s.id = c.thela_id WHERE c.id = ?`)
      .bind(ref).first();
    if (!c) throw new HttpError(404, 'not_found');
    return { open: c.status === 'coming', customer: c.customer_id, seller: c.owner_id, sellers: [c.owner_id],
      sellerLabel: c.name || 'Thela', customerLabel: 'Customer', title: c.name || 'Thela' };
  }
  throw new HttpError(400, 'bad_kind');
}

/** Can `uid` start a call now? Returns nothing or throws with the reason the app shows. */
export async function checkLimits(env, kind, ref, t = now()) {
  const { results } = await env.DB.prepare(`SELECT status, answered_at, created_at FROM voice_calls WHERE kind = ? AND ref = ?
    ORDER BY created_at DESC LIMIT 50`).bind(kind, ref).all();
  if (results.some((c) => c.status === 'ringing' && t - c.created_at < RING_S) || results.some((c) => c.status === 'connected')) {
    throw new HttpError(409, 'call_busy');
  }
  const connected = results.filter((c) => c.answered_at).length;
  if (connected >= MAX_CONNECTED) throw new HttpError(429, 'call_limit');
  if (results.filter((c) => t - c.created_at < 60).length >= PER_MINUTE) throw new HttpError(429, 'call_too_fast');
  const last = results.slice(0, MISSED_IN_ROW);
  if (last.length === MISSED_IN_ROW && last.every((c) => !c.answered_at) && t - last[0].created_at < BREAK_S) {
    throw new HttpError(429, 'call_break', String(BREAK_S - (t - last[0].created_at)));
  }
  return { connected, left: MAX_CONNECTED - connected };
}

/** Health check: does Cloudflare accept the TURN key? 'turn', or 'turn_error_<status>' (404 = key id wrong, 401/403 = token wrong). */
export async function turnStatus(env) {
  if (!env.CF_TURN_KEY_ID || !env.CF_TURN_TOKEN) return 'stun_only';
  try {
    const r = await fetch(`https://rtc.live.cloudflare.com/v1/turn/keys/${env.CF_TURN_KEY_ID.trim()}/credentials/generate-ice-servers`, {
      method: 'POST',
      headers: { authorization: `Bearer ${env.CF_TURN_TOKEN.trim()}`, 'content-type': 'application/json' },
      body: JSON.stringify({ ttl: 60 }),
    });
    if (!r.ok) return `turn_error_${r.status}`;
    return JSON.stringify(await r.json()).includes('turn:') ? 'turn' : 'turn_error_no_turn';
  } catch {
    return 'turn_error_network';
  }
}

/** Short-lived TURN credentials from Cloudflare (secrets CF_TURN_KEY_ID / CF_TURN_TOKEN); STUN only without them. */
export async function iceServers(env) {
  const stun = { urls: ['stun:stun.cloudflare.com:3478'] };
  if (!env.CF_TURN_KEY_ID || !env.CF_TURN_TOKEN) return [stun];
  try {
    const r = await fetch(`https://rtc.live.cloudflare.com/v1/turn/keys/${env.CF_TURN_KEY_ID.trim()}/credentials/generate-ice-servers`, {
      method: 'POST',
      headers: { authorization: `Bearer ${env.CF_TURN_TOKEN.trim()}`, 'content-type': 'application/json' },
      body: JSON.stringify({ ttl: 3600 }),
    });
    if (!r.ok) return [stun];
    const d = await r.json();
    return Array.isArray(d.iceServers) ? d.iceServers : d.iceServers ? [d.iceServers] : [stun];
  } catch {
    return [stun];
  }
}

function callOut(c, uid) {
  const mine = uid === c.caller_id;
  return { id: c.id, kind: c.kind, ref: c.ref, status: c.status, outgoing: mine,
    // Names and numbers are never shown: only the role ("Delivery partner", "Customer", the thela's name).
    other: mine ? c.callee_label : c.caller_label, title: c.title, createdAt: c.created_at, answeredAt: c.answered_at };
}

async function mine(env, id, uid) {
  const c = await env.DB.prepare('SELECT * FROM voice_calls WHERE id = ?').bind(id).first();
  if (!c || (c.caller_id !== uid && c.callee_id !== uid)) throw new HttpError(404, 'not_found');
  return c;
}

async function relay(env, id, msg) {
  if (!env.CHAT) return;
  try {
    await env.CHAT.get(env.CHAT.idFromName(`voice:${id}`)).fetch('https://chat/broadcast', { method: 'POST', body: JSON.stringify(msg) });
  } catch {}
}

/** Ringing calls nobody answered become missed (also run by the 5-minute cron). */
export async function missOld(env, t = now()) {
  await env.DB.prepare("UPDATE voice_calls SET status = 'missed', ended_at = ? WHERE status = 'ringing' AND created_at < ?").bind(t, t - RING_S).run();
  // A connected call whose phones vanished: close it after 2 hours.
  await env.DB.prepare("UPDATE voice_calls SET status = 'ended', ended_at = ? WHERE status = 'connected' AND answered_at < ?").bind(t, t - 7200).run();
  await env.DB.prepare('DELETE FROM voice_calls WHERE created_at < ?').bind(t - KEEP_DAYS * 86400).run();
}

export async function voiceRoute(req, env, path, m) {
  if (!path.startsWith('/v1/voice')) return null;

  const sock = path.match(/^\/v1\/voice\/([\w-]+)\/socket$/);
  if (sock && m === 'GET') {
    const url = new URL(req.url);
    const authed = new Request(req.url, { headers: { authorization: `Bearer ${url.searchParams.get('token') || ''}` } });
    const { uid } = await session(authed, env);
    const c = await mine(env, sock[1], uid);
    if (!['ringing', 'connected'].includes(c.status)) throw new HttpError(410, 'call_over');
    if (!env.CHAT) throw new HttpError(503, 'calls_off');
    // The room passes each phone's messages to the other one (marked as a voice room, so chat rooms never relay).
    const fwd = new Request(req.url, { headers: { upgrade: 'websocket', 'x-voice': uid === c.caller_id ? 'caller' : 'callee' } });
    return env.CHAT.get(env.CHAT.idFromName(`voice:${c.id}`)).fetch(fwd);
  }

  const { uid } = await session(req, env);
  const t = now();

  if (path === '/v1/voice/start' && m === 'POST') {
    const b = await body(req);
    const kind = String(b.kind || ''), ref = String(b.ref || '').slice(0, 64);
    const p = await parties(env, kind, ref, t);
    const isCustomer = uid === p.customer;
    if (!isCustomer && !p.sellers.includes(uid)) throw new HttpError(403, 'not_yours');
    if (!p.open) throw new HttpError(409, 'call_closed');
    await missOld(env, t);
    const lim = await checkLimits(env, kind, ref, t);
    const callee = isCustomer ? p.seller : p.customer;
    if (!callee || callee === uid) throw new HttpError(409, 'nobody_to_call');
    const id = `V${crypto.randomUUID().replace(/-/g, '').slice(0, 16)}`;
    const callerLabel = isCustomer ? p.customerLabel : p.sellerLabel;
    const calleeLabel = isCustomer ? p.sellerLabel : p.customerLabel;
    await env.DB.prepare(`INSERT INTO voice_calls (id, kind, ref, caller_id, callee_id, caller_label, callee_label, title, status, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'ringing', ?)`).bind(id, kind, ref, uid, callee, callerLabel, calleeLabel, p.title, t).run();
    // Data-only, high priority: the app rings with Answer / Decline. Ring and relay keys at the same time (faster start).
    const [, ice, c] = await Promise.all([
      sendPush(env, callee, { title: '', body: '', dataOnly: true,
        data: { type: 'voice_call', id, from: callerLabel, title: p.title, kind, ref } }).catch(() => {}),
      iceServers(env),
      env.DB.prepare('SELECT * FROM voice_calls WHERE id = ?').bind(id).first(),
    ]);
    return json({ call: callOut(c, uid), ice, left: lim.left });
  }

  const one = path.match(/^\/v1\/voice\/([\w-]+)(?:\/(answer|decline|end))?$/);
  if (one) {
    const c = await mine(env, one[1], uid);
    if (!one[2] && m === 'GET') {
      if (c.status === 'ringing' && t - c.created_at >= RING_S) c.status = 'missed';
      return json({ call: callOut(c, uid), ice: ['ringing', 'connected'].includes(c.status) ? await iceServers(env) : [] });
    }
    if (m !== 'POST') throw new HttpError(405, 'method');
    if (one[2] === 'answer') {
      if (uid !== c.callee_id) throw new HttpError(403, 'not_yours');
      const r = await env.DB.prepare("UPDATE voice_calls SET status = 'connected', answered_at = ? WHERE id = ? AND status = 'ringing' AND created_at > ? RETURNING *")
        .bind(t, c.id, t - RING_S).first();
      if (!r) throw new HttpError(410, 'call_over');
      await relay(env, c.id, { type: 'answered' });
      return json({ call: callOut(r, uid), ice: await iceServers(env) });
    }
    // decline (callee, while ringing) / end (either side, any time)
    const status = c.status === 'connected' ? 'ended' : one[2] === 'decline' ? 'declined' : 'missed';
    if (['ringing', 'connected'].includes(c.status)) {
      await env.DB.prepare('UPDATE voice_calls SET status = ?, ended_at = ? WHERE id = ?').bind(status, t, c.id).run();
      await relay(env, c.id, { type: 'bye' });
      // Caller hung up before an answer: stop the other phone ringing.
      if (c.status === 'ringing') {
        const other = uid === c.caller_id ? c.callee_id : c.caller_id;
        await sendPush(env, other, { title: '', body: '', dataOnly: true, data: { type: 'voice_end', id: c.id } }).catch(() => {});
      }
    }
    const r = await env.DB.prepare('SELECT * FROM voice_calls WHERE id = ?').bind(c.id).first();
    return json({ call: callOut(r, uid) });
  }
  throw new HttpError(404, 'not_found');
}
