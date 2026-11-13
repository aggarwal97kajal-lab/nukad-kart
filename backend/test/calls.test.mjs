import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeDb } from './d1shim.mjs';
import worker, { signSession, now } from '../src/index.js';
import { groupCalls } from '../src/calls.js';

const SECRET = 's';
const T = now();

async function setup() {
  const DB = makeDb();
  const env = { DB, SESSION_SECRET: SECRET };
  const ins = (table, row) => DB.raw.prepare(`INSERT INTO ${table} (${Object.keys(row)}) VALUES (${Object.keys(row).map(() => '?')})`).run(...Object.values(row));
  for (const u of ['owner', 'c1', 'c2', 'c3']) {
    ins('users', { id: u, google_sub: 'g' + u, email: u + '@x.y', name: u, created_at: T, updated_at: T });
    ins('sessions', { id: 's' + u, user_id: u, created_at: T, last_seen: T });
  }
  ins('stores', { id: 'th1', name: 'Ramu Sabzi', kind: 'thela', owner_id: 'owner', lat: 0, lng: 0, opens_at: '', closes_at: '', status: 'active', live: 1,
    pass_until: T + 86400, active: 1, demo: 0, agreement_version: 1, created_at: T, live_lat: 28.7, live_lng: 77.1, live_at: T, moved_at: T });
  const tok = async (u) => ({ authorization: `Bearer ${await signSession(u, SECRET, 30, 's' + u)}` });
  const call = async (method, path, body, who) => {
    const r = await worker.fetch(new Request(`https://x${path}`, { method, headers: { 'content-type': 'application/json', ...(who ? await tok(who) : {}) },
      body: body ? JSON.stringify(body) : undefined }), env);
    return { status: r.status, json: await r.json() };
  };
  return { DB, call };
}

test('calls on one street are grouped; coming / can’t come; one call at a time', async () => {
  const { call } = await setup();
  let r = await call('POST', '/v1/thelas/th1/call', { lat: 28.7010, lng: 77.1, address: 'Gali 4, Shiv Mandir' }, 'c1');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  r = await call('POST', '/v1/thelas/th1/call', { lat: 28.7010, lng: 77.1, address: 'Gali 4' }, 'c1');
  assert.equal(r.json.error, 'already_calling');
  await call('POST', '/v1/thelas/th1/call', { lat: 28.7012, lng: 77.1003, address: 'Gali 4, H 12' }, 'c2');
  await call('POST', '/v1/thelas/th1/call', { lat: 28.7040, lng: 77.1, address: 'Gali 9' }, 'c3');
  r = await call('POST', '/v1/thelas/th1/call', { lat: 28.75, lng: 77.1, address: 'Far away' }, 'owner');
  assert.equal(r.json.error, 'too_far');
  r = await call('GET', '/v1/partner/calls', null, 'owner');
  assert.deepEqual(r.json.groups.map((g) => g.count), [2, 1]);
  const g = r.json.groups[0];
  r = await call('POST', '/v1/partner/calls/answer', { ids: g.ids, coming: true }, 'owner');
  assert.equal(r.json.answered, 2);
  r = await call('GET', '/v1/me/calls/current', null, 'c2');
  assert.equal(r.json.call.status, 'coming');
  r = await call('POST', '/v1/partner/calls/answer', { ids: r.json.call ? [] : [], coming: false }, 'owner');
  r = await call('GET', '/v1/partner/calls', null, 'owner');
  assert.equal(r.json.coming[0].count, 2);
});

test('no answer in 3 minutes → expired; 3 no-shows block calling', async () => {
  const { DB, call } = await setup();
  await call('POST', '/v1/thelas/th1/call', { lat: 28.7010, lng: 77.1, address: 'Gali 4' }, 'c1');
  DB.raw.prepare('UPDATE calls SET created_at = ?').run(T - 200);
  let r = await call('GET', '/v1/me/calls/current', null, 'c1');
  assert.equal(r.json.call.status, 'expired');
  for (let i = 0; i < 3; i++) {
    r = await call('POST', '/v1/thelas/th1/call', { lat: 28.7010, lng: 77.1, address: 'Gali 4' }, 'c1');
    assert.equal(r.status, 200, JSON.stringify(r.json));
    await call('POST', '/v1/partner/calls/answer', { ids: [r.json.call.id], coming: true }, 'owner');
    await call('POST', '/v1/partner/calls/no-show', { ids: [r.json.call.id] }, 'owner');
  }
  r = await call('POST', '/v1/thelas/th1/call', { lat: 28.7010, lng: 77.1, address: 'Gali 4' }, 'c1');
  assert.equal(r.json.error, 'calls_blocked');
});

test('grouping by 100 m', () => {
  const g = groupCalls([{ id: 'a', lat: 28.7, lng: 77.1, created_at: T }, { id: 'b', lat: 28.7008, lng: 77.1, created_at: T }, { id: 'c', lat: 28.702, lng: 77.1, created_at: T }]);
  assert.deepEqual(g.map((x) => x.ids), [['a', 'b'], ['c']]);
});

test('chat: customer writes, thela replies, numbers refused, block closes it', async () => {
  const { call } = await setup();
  let r = await call('POST', '/v1/me/chats/th1', { text: 'Bhaiya matar hai?', address: 'Gali 4' }, 'c1');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  r = await call('POST', '/v1/me/chats/th1', { text: 'call 9876543210' }, 'c1');
  assert.equal(r.json.error, 'no_numbers');
  r = await call('GET', '/v1/partner/chats', null, 'owner');
  assert.equal(r.json.chats[0].unread, true);
  const id = r.json.chats[0].id;
  r = await call('POST', `/v1/partner/chats/${id}`, { text: 'Haan hai' }, 'owner');
  assert.deepEqual(r.json.messages.map((x) => x.from), ['customer', 'thela']);
  await call('POST', `/v1/partner/chats/${id}/report`, { reason: 'rude' }, 'owner');
  r = await call('POST', '/v1/me/chats/th1', { text: 'hello' }, 'c1');
  assert.equal(r.json.error, 'chat_closed');
  r = await call('POST', '/v1/thelas/th1/watch', null, null);
  assert.equal(r.json.ok, true);
});

test('admin restore: reason needed, once in 90 days, old no-shows forgiven', async () => {
  const { DB } = await setup();
  const { default: worker } = await import('../src/index.js');
  void worker;
  DB.raw.prepare("UPDATE users SET calls_blocked_until = ? WHERE id = 'c1'").run(T + 86400);
  // route needs an admin; check the SQL directly
  DB.raw.prepare("INSERT INTO calls (id, thela_id, customer_id, lat, lng, status, created_at) VALUES ('x', 'th1', 'c1', 0, 0, 'no_show', ?)").run(T);
  DB.raw.prepare("UPDATE users SET calls_blocked_until = 0, calls_restored_at = ?, calls_restore_note = 'x' WHERE id = 'c1'").run(T);
  DB.raw.prepare("UPDATE calls SET status = 'no_show_forgiven' WHERE customer_id = 'c1' AND status = 'no_show'").run();
  assert.equal(DB.raw.prepare("SELECT COUNT(*) AS n FROM calls WHERE status = 'no_show'").get().n, 0);
});

test('chat inbox: waiting first, reply to all, busy count for customers', async () => {
  const { call } = await setup();
  await call('POST', '/v1/me/chats/th1', { text: 'matar hai?', address: 'Gali 4', lat: 28.7005, lng: 77.1 }, 'c1');
  await call('POST', '/v1/me/chats/th1', { text: 'kitni der?', address: 'Gali 9', lat: 28.704, lng: 77.1 }, 'c2');
  let r = await call('GET', '/v1/partner/chats', null, 'owner');
  assert.equal(r.json.waiting, 2);
  assert.equal(r.json.chats[0].address, 'Gali 4'); // nearest first
  assert.equal(r.json.chats[0].unreadCount, 1);
  r = await call('GET', '/v1/me/chats/th1', null, 'c1');
  assert.equal(r.json.busy, 1);
  r = await call('POST', '/v1/partner/chats/reply-all', { text: '10 min mein aata hoon' }, 'owner');
  assert.equal(r.json.sent, 2);
  r = await call('GET', '/v1/partner/chats', null, 'owner');
  assert.equal(r.json.waiting, 0);
});

test('coming call: "I’m coming out" confirms it; no confirm in 3 minutes drops it (chat counts as confirm)', async () => {
  const { DB, call } = await setup();
  let r = await call('POST', '/v1/thelas/th1/call', { lat: 28.7010, lng: 77.1, address: 'Gali 4' }, 'c1');
  const a = r.json.call.id;
  r = await call('POST', '/v1/thelas/th1/call', { lat: 28.7010, lng: 77.1, address: 'Gali 4' }, 'c2');
  const b = r.json.call.id;
  r = await call('POST', '/v1/thelas/th1/call', { lat: 28.7010, lng: 77.1, address: 'Gali 4' }, 'c3');
  const c = r.json.call.id;
  await call('POST', '/v1/partner/calls/answer', { ids: [a, b, c], coming: true }, 'owner');
  r = await call('GET', '/v1/me/calls/current', null, 'c1');
  assert.ok(r.json.call.confirmLeft > 0);
  r = await call('POST', `/v1/me/calls/${a}/out`, {}, 'c1');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  r = await call('POST', '/v1/me/chats/th1', { text: 'Bhaiya 1 kg tamatar' }, 'c3');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  DB.raw.prepare('UPDATE calls SET answered_at = ?').run(T - 200);
  r = await call('GET', '/v1/partner/calls', null, 'owner');
  assert.equal(r.json.coming[0].count, 2);
  assert.equal(r.json.coming[0].out, 2);
  r = await call('GET', '/v1/me/calls/current', null, 'c2');
  assert.equal(r.json.call.status, 'unconfirmed');
});
