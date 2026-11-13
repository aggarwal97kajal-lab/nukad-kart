// "Call to my street" (bulao): customer → LIVE thela within 500 m. No cart, no phone numbers.
//   POST /v1/thelas/:id/call   { lat, lng, address }   (customer) ask the thela to come
//   GET  /v1/me/calls/current                           (customer) my latest call and its status
//   POST /v1/me/calls/:id/cancel                        (customer)
//   GET  /v1/partner/calls                              (thela) waiting calls, grouped by street (~100 m)
//   POST /v1/partner/calls/answer { ids, coming }       (thela) "Coming" / "Can't come" for a group
//   POST /v1/partner/calls/no-show { ids }              (thela) came, nobody there → strike for the customer
//   POST /v1/me/calls/:id/out                           (customer) "I'm coming out" after the thela said Coming.
// A "coming" call the customer doesn't confirm (button, or a chat message to the thela) in 3 minutes is dropped,
// so the thela doesn't walk to an empty gate.
import { HttpError, json, body, now, session, haversineM, RADIUS_MAX_M, THELA_STALE_S } from './index.js';
import { ctx, offlineReason } from './partner.js';
import { sendPush } from './push.js';

export const CALL_WAIT_S = 180; // thela has 3 minutes to answer
export const CONFIRM_S = 180; // customer has 3 minutes to say "I'm coming out"
const GROUP_M = 100;
const STRIKES = 3, STRIKE_DAYS = 30, BLOCK_DAYS = 7;

const id = () => crypto.randomUUID();
const first = (name) => String(name || '').split(/\s+/)[0] || 'The thela';

function callOut(c, thela) {
  const t = now();
  return { id: c.id, thelaId: c.thela_id, thelaName: thela?.name || '', status: c.status, address: c.address,
    createdAt: c.created_at, answeredAt: c.answered_at, waitLeft: c.status === 'waiting' ? Math.max(0, c.created_at + CALL_WAIT_S - t) : 0,
    out: !!c.out_at, confirmLeft: c.status === 'coming' && !c.out_at ? Math.max(0, (c.answered_at || t) + CONFIRM_S - t) : 0 };
}

/**
 * The thela's "customers calling you" alert, sent data-only so the Partner app shows ONE notification
 * it can update or remove (count 0 = remove, e.g. the customer cancelled).
 */
async function tellThela(env, s) {
  if (!s.owner_id) return;
  const t = now();
  const { results } = await env.DB.prepare("SELECT * FROM calls WHERE thela_id = ? AND status = 'waiting' AND created_at >= ? ORDER BY created_at")
    .bind(s.id, t - CALL_WAIT_S).all();
  const groups = groupCalls(results, s.live_lat == null ? null : { lat: s.live_lat, lng: s.live_lng });
  const n = results.length, g = groups[0];
  await sendPush(env, s.owner_id, {
    title: '', body: '', dataOnly: true,
    data: n ? { type: 'calls', count: n,
      title: n > 1 ? `${n} people are calling you` : 'A customer is calling you',
      body: `${g.address}${g.distanceM == null ? '' : ` · ${g.distanceM} m`}${groups.length > 1 ? ` (+${groups.length - 1} more streets)` : ''}. Answer within 3 minutes.` }
      : { type: 'calls', count: 0 },
  });
}

/** Calls nobody answered in 3 minutes become "expired". Returns the ones that just expired. */
async function expire(env, where, bind) {
  const t = now();
  const { results } = await env.DB.prepare(`UPDATE calls SET status = 'expired', answered_at = ? WHERE status = 'waiting' AND created_at < ? AND ${where} RETURNING *`)
    .bind(t, t - CALL_WAIT_S, ...bind).all();
  return results;
}

/** Group waiting calls by street: each call joins the first group whose first call is within 100 m. */
export function groupCalls(calls, from) {
  const groups = [];
  for (const c of calls) {
    const g = groups.find((x) => haversineM(x.lat, x.lng, c.lat, c.lng) <= GROUP_M);
    if (g) {
      g.ids.push(c.id);
      g.count++;
      if (c.out_at) g.out++;
    } else {
      groups.push({ ids: [c.id], count: 1, out: c.out_at ? 1 : 0, lat: c.lat, lng: c.lng, address: c.address, since: c.created_at,
        distanceM: from ? Math.round(haversineM(from.lat, from.lng, c.lat, c.lng)) : null,
        waitLeft: Math.max(0, c.created_at + CALL_WAIT_S - now()) });
    }
  }
  return groups;
}

export async function callRoute(req, env, path, m) {
  const call = path.match(/^\/v1\/thelas\/([\w-]+)\/call$/);
  if (call && m === 'POST') {
    const { uid } = await session(req, env);
    const b = await body(req);
    const lat = Number(b.lat), lng = Number(b.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) throw new HttpError(400, 'bad_location');
    const address = String(b.address || '').trim().slice(0, 160);
    if (address.length < 3) throw new HttpError(400, 'address_needed');
    const t = now();
    await expire(env, 'customer_id = ?', [uid]);
    const [ur, sr, mine] = await env.DB.batch([
      env.DB.prepare('SELECT id, calls_blocked_until FROM users WHERE id = ? AND deleted_at IS NULL').bind(uid),
      env.DB.prepare('SELECT * FROM stores WHERE id = ? AND active = 1').bind(call[1]),
      env.DB.prepare("SELECT id FROM calls WHERE customer_id = ? AND status = 'waiting'").bind(uid),
    ]);
    const u = ur.results[0], s = sr.results[0];
    if (!u) throw new HttpError(401, 'not_signed_in');
    if (u.calls_blocked_until > t) throw new HttpError(403, 'calls_blocked');
    if (mine.results.length) throw new HttpError(409, 'already_calling');
    if (!s || s.kind !== 'thela' || offlineReason(s, t) != null || !s.live_at || t - s.live_at > THELA_STALE_S) throw new HttpError(404, 'thela_not_live');
    if (haversineM(lat, lng, s.live_lat, s.live_lng) > RADIUS_MAX_M) throw new HttpError(400, 'too_far');
    const c = { id: id(), thela_id: s.id, customer_id: uid, lat, lng, address, status: 'waiting', created_at: t };
    await env.DB.prepare('INSERT INTO calls (id, thela_id, customer_id, lat, lng, address, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
      .bind(c.id, c.thela_id, c.customer_id, lat, lng, address, 'waiting', t).run();
    // One alert per street: "3 people on Gali 4 are calling you".
    const { results } = await env.DB.prepare("SELECT * FROM calls WHERE thela_id = ? AND status = 'waiting' AND created_at >= ?")
      .bind(s.id, t - CALL_WAIT_S).all();
    const g = groupCalls(results, { lat: s.live_lat, lng: s.live_lng }).find((x) => x.ids.includes(c.id));
    await tellThela(env, s);
    return json({ call: callOut(c, s) });
  }

  if (path === '/v1/me/calls/current' && m === 'GET') {
    const { uid } = await session(req, env);
    await expire(env, 'customer_id = ?', [uid]);
    await dropUnconfirmed(env, 'c.customer_id = ?', [uid]);
    const t = now();
    const [cr, sr, ur] = await env.DB.batch([
      env.DB.prepare('SELECT c.*, s.name AS thela_name FROM calls c JOIN stores s ON s.id = c.thela_id WHERE c.customer_id = ? AND c.created_at > ? ORDER BY c.created_at DESC LIMIT 1').bind(uid, t - 3600),
      env.DB.prepare("SELECT COUNT(*) AS n FROM calls WHERE customer_id = ? AND status = 'no_show' AND created_at > ?").bind(uid, t - STRIKE_DAYS * 86400),
      env.DB.prepare('SELECT calls_blocked_until FROM users WHERE id = ?').bind(uid),
    ]);
    const c = cr.results[0];
    return json({ call: c ? callOut(c, { name: c.thela_name }) : null, strikes: sr.results[0].n, strikesMax: STRIKES,
      blockedUntil: (ur.results[0]?.calls_blocked_until || 0) > t ? ur.results[0].calls_blocked_until : 0 });
  }

  const cancel = path.match(/^\/v1\/me\/calls\/([\w-]+)\/cancel$/);
  if (cancel && m === 'POST') {
    const { uid } = await session(req, env);
    const c = await env.DB.prepare("UPDATE calls SET status = 'cancelled', answered_at = ? WHERE id = ? AND customer_id = ? AND status IN ('waiting', 'coming') RETURNING thela_id")
      .bind(now(), cancel[1], uid).first();
    if (c) {
      const s = await env.DB.prepare('SELECT id, owner_id, live_lat, live_lng FROM stores WHERE id = ?').bind(c.thela_id).first();
      if (s) await tellThela(env, s); // the thela's alert updates / disappears at once
    }
    return json({ ok: true });
  }

  const out = path.match(/^\/v1\/me\/calls\/([\w-]+)\/out$/);
  if (out && m === 'POST') {
    const { uid } = await session(req, env);
    const c = await env.DB.prepare("UPDATE calls SET out_at = ? WHERE id = ? AND customer_id = ? AND status = 'coming' AND out_at IS NULL RETURNING thela_id, address")
      .bind(now(), out[1], uid).first();
    if (!c) throw new HttpError(409, 'call_not_coming');
    const s = await env.DB.prepare('SELECT owner_id FROM stores WHERE id = ?').bind(c.thela_id).first();
    if (s?.owner_id) await sendPush(env, s.owner_id, { title: '✋ Grahak bahar aa raha hai', body: `${c.address} · the customer is coming out to meet you.`, data: { type: 'calls_out' } });
    return json({ ok: true });
  }

  if (path === '/v1/partner/calls' && m === 'GET') {
    const { s } = await ctx(req, env);
    if (!s || s.kind !== 'thela') return json({ groups: [], coming: [] });
    await expire(env, 'thela_id = ?', [s.id]);
    await dropUnconfirmed(env, 'c.thela_id = ?', [s.id]);
    const t = now();
    const { results } = await env.DB.prepare("SELECT * FROM calls WHERE thela_id = ? AND status IN ('waiting', 'coming') AND created_at > ? ORDER BY created_at")
      .bind(s.id, t - 3600).all();
    const from = s.live_lat == null ? null : { lat: s.live_lat, lng: s.live_lng };
    return json({
      groups: groupCalls(results.filter((c) => c.status === 'waiting'), from),
      coming: groupCalls(results.filter((c) => c.status === 'coming'), from),
    });
  }

  if (path === '/v1/partner/calls/answer' && m === 'POST') {
    const { s } = await ctx(req, env);
    if (!s || s.kind !== 'thela') throw new HttpError(400, 'thela_only');
    const b = await body(req);
    const ids = (Array.isArray(b.ids) ? b.ids : []).map(String).slice(0, 50);
    const coming = b.coming === true;
    const t = now();
    if (!ids.length) return json({ ok: true, answered: 0 });
    const q = ids.map(() => '?').join(',');
    const { results } = await env.DB.prepare(`UPDATE calls SET status = ?, answered_at = ?, told = 1 WHERE thela_id = ? AND status = 'waiting'
      AND created_at >= ? AND id IN (${q}) RETURNING *`).bind(coming ? 'coming' : 'declined', t, s.id, t - CALL_WAIT_S, ...ids).all();
    await tellThela(env, s);
    for (const c of results) {
      await sendPush(env, c.customer_id, coming
        ? { title: `${first(s.name)} is coming`, body: `${s.name} is on the way to ${c.address}. Pay the seller directly.`, data: { type: 'call', status: 'coming', thelaId: s.id } }
        : { title: `${first(s.name)} can't come right now`, body: 'Try again later, or call another thela nearby.', data: { type: 'call', status: 'declined', thelaId: s.id } });
    }
    return json({ ok: true, answered: results.length });
  }

  if (path === '/v1/partner/calls/no-show' && m === 'POST') {
    const { s } = await ctx(req, env);
    if (!s || s.kind !== 'thela') throw new HttpError(400, 'thela_only');
    const b = await body(req);
    const ids = (Array.isArray(b.ids) ? b.ids : []).map(String).slice(0, 50);
    return json(await noShow(env, s, ids));
  }

  if (path === '/v1/partner/calls/done' && m === 'POST') {
    const { s } = await ctx(req, env);
    if (!s || s.kind !== 'thela') throw new HttpError(400, 'thela_only');
    const b = await body(req);
    const ids = (Array.isArray(b.ids) ? b.ids : []).map(String).slice(0, 50);
    if (ids.length) {
      await env.DB.prepare(`UPDATE calls SET status = 'done' WHERE thela_id = ? AND status = 'coming' AND id IN (${ids.map(() => '?').join(',')})`)
        .bind(s.id, ...ids).run();
    }
    return json({ ok: true });
  }
  return null;
}

/** "Came, nobody there": a strike for each customer; 3 in 30 days blocks calling for 7 days. */
export async function noShow(env, s, ids) {
  if (!ids.length) return { ok: true, reported: 0 };
  const t = now();
  const { results } = await env.DB.prepare(`UPDATE calls SET status = 'no_show' WHERE thela_id = ? AND status = 'coming'
    AND id IN (${ids.map(() => '?').join(',')}) RETURNING customer_id`).bind(s.id, ...ids).all();
  for (const { customer_id } of results) {
    const r = await env.DB.prepare("SELECT COUNT(*) AS n FROM calls WHERE customer_id = ? AND status = 'no_show' AND created_at > ?")
      .bind(customer_id, t - STRIKE_DAYS * 86400).first();
    const blocked = r.n >= STRIKES;
    if (blocked) {
      await env.DB.prepare('UPDATE users SET calls_blocked_until = ? WHERE id = ?').bind(t + BLOCK_DAYS * 86400, customer_id).run();
    }
    await sendPush(env, customer_id, {
      title: `${first(s.name)} came but couldn’t find you`,
      body: blocked ? `This happened ${r.n} times. Calling thelas is paused for ${BLOCK_DAYS} days.` : `This is ${r.n} of ${STRIKES}. At ${STRIKES}, calling thelas is paused for ${BLOCK_DAYS} days.`,
      data: { type: 'call', status: 'no_show', thelaId: s.id },
    });
  }
  return { ok: true, reported: results.length };
}

/**
 * "Coming" calls with no "I'm coming out" (button, or a chat message to this thela after it answered) within
 * 3 minutes become "unconfirmed": the thela is told not to go. No strike for the customer.
 */
export async function dropUnconfirmed(env, where = '1 = 1', bind = []) {
  const t = now();
  const { results } = await env.DB.prepare(`SELECT c.id, c.customer_id, c.thela_id, c.address, c.answered_at FROM calls c
    WHERE c.status = 'coming' AND c.out_at IS NULL AND c.answered_at < ? AND ${where}`).bind(t - CONFIRM_S, ...bind).all();
  const dropped = [];
  for (const c of results) {
    const chat = await env.DB.prepare(`SELECT 1 AS y FROM chat_messages m JOIN chats h ON h.id = m.chat_id
      WHERE h.thela_id = ? AND h.customer_id = ? AND m.sender = 'c' AND m.created_at >= ? LIMIT 1`).bind(c.thela_id, c.customer_id, c.answered_at - 600).first();
    if (chat) {
      // Wrote the items in chat: that counts as "coming out".
      await env.DB.prepare('UPDATE calls SET out_at = ? WHERE id = ?').bind(t, c.id).run();
      continue;
    }
    await env.DB.prepare("UPDATE calls SET status = 'unconfirmed' WHERE id = ? AND status = 'coming'").bind(c.id).run();
    dropped.push(c);
  }
  for (const c of dropped) {
    const s = await env.DB.prepare('SELECT name, owner_id FROM stores WHERE id = ?').bind(c.thela_id).first();
    if (s?.owner_id) await sendPush(env, s.owner_id, { title: 'Mat jaiye: grahak ne confirm nahi kiya', body: `${c.address} · the customer didn't say they are coming out. The call is cancelled.`, data: { type: 'calls_out' } });
    await sendPush(env, c.customer_id, { title: 'Call cancelled', body: `You didn't confirm in 3 minutes, so ${first(s?.name)} was told not to come. Call again when you are ready.`, data: { type: 'call', status: 'unconfirmed', thelaId: c.thela_id } });
  }
  return dropped.length;
}

/** Cron: tell customers whose call expired (the thela didn't answer in 3 minutes). */
export async function tellExpiredCalls(env) {
  const t = now();
  await expire(env, '1 = 1', []);
  const { results } = await env.DB.prepare(`SELECT c.id, c.customer_id, c.thela_id, s.name FROM calls c JOIN stores s ON s.id = c.thela_id
    WHERE c.status = 'expired' AND c.told = 0 AND c.created_at > ? LIMIT 200`).bind(t - 3600).all();
  for (const c of results) {
    await env.DB.prepare('UPDATE calls SET told = 1 WHERE id = ?').bind(c.id).run();
    await sendPush(env, c.customer_id, { title: `${first(c.name)} can't come right now`, body: 'No answer in 3 minutes. Try again later, or call another thela nearby.', data: { type: 'call', status: 'expired', thelaId: c.thela_id } });
  }
}
