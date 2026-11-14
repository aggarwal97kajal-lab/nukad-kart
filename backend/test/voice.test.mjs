import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeDb } from './d1shim.mjs';
import worker, { signSession, now } from '../src/index.js';

const SECRET = 's';
const T = now();

async function setup() {
  const DB = makeDb();
  const env = { DB, SESSION_SECRET: SECRET };
  const ins = (table, row) => DB.raw.prepare(`INSERT INTO ${table} (${Object.keys(row)}) VALUES (${Object.keys(row).map(() => '?')})`).run(...Object.values(row));
  for (const u of ['owner', 'cust', 'rider', 'other']) {
    ins('users', { id: u, google_sub: 'g' + u, email: u + '@x.y', name: u, created_at: T, updated_at: T, app: 'customer' });
    ins('sessions', { id: 's' + u, user_id: u, created_at: T, last_seen: T });
  }
  ins('stores', { id: 'sh1', name: 'Sharma Store', kind: 'shop', owner_id: 'owner', lat: 28.7, lng: 77.1, status: 'active', live: 1, pass_until: T + 86400, active: 1, demo: 0, created_at: T });
  ins('staff', { id: 'st1', store_id: 'sh1', name: 'Raju', phone: '9000000002', can_orders: 0, user_id: 'rider', created_at: T });
  ins('orders', { id: 'NK-1', store_id: 'sh1', customer_id: 'cust', status: 'out', lines: '[]', items_total: 100, total: 100, created_at: T - 600, accepted_at: T - 500 });
  const call = async (method, path, body, who) => {
    const r = await worker.fetch(new Request(`https://x${path}`, { method, headers: { 'content-type': 'application/json',
      authorization: `Bearer ${await signSession(who, SECRET, 30, 's' + who)}` }, body: body ? JSON.stringify(body) : undefined }), env);
    return { status: r.status, json: await r.json() };
  };
  return { DB, call, ins };
}

test('customer calls the shop while nobody is assigned, then the delivery partner; names hidden', async () => {
  const { DB, call } = await setup();
  let r = await call('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1' }, 'cust');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  assert.equal(r.json.call.other, 'Delivery partner');
  assert.equal(DB.raw.prepare('SELECT callee_id FROM voice_calls').get().callee_id, 'owner');
  r = await call('POST', `/v1/voice/${r.json.call.id}/end`, {}, 'cust');
  DB.raw.prepare("UPDATE orders SET staff_id = 'st1' WHERE id = 'NK-1'").run();
  r = await call('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1' }, 'cust');
  const id = r.json.call.id;
  assert.equal(DB.raw.prepare('SELECT callee_id FROM voice_calls WHERE id = ?').get(id).callee_id, 'rider');
  r = await call('POST', `/v1/voice/${id}/answer`, {}, 'cust');
  assert.equal(r.status, 403); // only the called phone answers
  r = await call('POST', `/v1/voice/${id}/answer`, {}, 'rider');
  assert.equal(r.json.call.status, 'connected');
  assert.equal(r.json.call.other, 'Customer');
  r = await call('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1' }, 'rider');
  assert.equal(r.json.error, 'call_busy');
  r = await call('GET', `/v1/voice/${id}`, null, 'other');
  assert.equal(r.status, 404);
});

test('limits: 3 per minute, 2-minute break after 3 missed, 10 connected, closed 30 min after delivery', async () => {
  const { DB, call, ins } = await setup();
  for (let i = 0; i < 3; i++) {
    ins('voice_calls', { id: 'm' + i, kind: 'order', ref: 'NK-1', caller_id: 'cust', callee_id: 'owner', caller_label: 'Customer', callee_label: 'Delivery partner',
      status: 'missed', created_at: T - 30 - i });
  }
  let r = await call('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1' }, 'cust');
  assert.equal(r.json.error, 'call_too_fast');
  DB.raw.prepare('UPDATE voice_calls SET created_at = created_at - 40').run(); // a minute later, still within the break
  r = await call('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1' }, 'cust');
  assert.equal(r.json.error, 'call_break');
  assert.ok(Number(r.json.detail) > 0);
  DB.raw.prepare('DELETE FROM voice_calls').run();
  for (let i = 0; i < 10; i++) {
    ins('voice_calls', { id: 'c' + i, kind: 'order', ref: 'NK-1', caller_id: 'cust', callee_id: 'owner', caller_label: 'Customer', callee_label: 'Delivery partner',
      status: 'ended', created_at: T - 3000 - i * 100, answered_at: T - 2990 - i * 100 });
  }
  r = await call('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1' }, 'cust');
  assert.equal(r.json.error, 'call_limit');
  DB.raw.prepare('DELETE FROM voice_calls').run();
  DB.raw.prepare("UPDATE orders SET status = 'delivered', delivered_at = ? WHERE id = 'NK-1'").run(T - 31 * 60);
  r = await call('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1' }, 'cust');
  assert.equal(r.json.error, 'call_closed');
});

test('thela: only while coming to the street', async () => {
  const { DB, call, ins } = await setup();
  ins('stores', { id: 'th1', name: 'Ramu Sabzi', kind: 'thela', owner_id: 'other', lat: 28.7, lng: 77.1, status: 'active', live: 1, pass_until: T + 86400, active: 1, demo: 0, created_at: T });
  ins('calls', { id: 'k1', thela_id: 'th1', customer_id: 'cust', lat: 0, lng: 0, status: 'waiting', created_at: T });
  let r = await call('POST', '/v1/voice/start', { kind: 'thela', ref: 'k1' }, 'cust');
  assert.equal(r.json.error, 'call_closed');
  DB.raw.prepare("UPDATE calls SET status = 'coming'").run();
  r = await call('POST', '/v1/voice/start', { kind: 'thela', ref: 'k1' }, 'cust');
  assert.equal(r.json.call.other, 'Ramu Sabzi');
  r = await call('POST', `/v1/voice/${r.json.call.id}/decline`, {}, 'other');
  assert.equal(r.json.call.status, 'declined');
});

test('order chat: customer ↔ delivery partner, no numbers, closed 30 min after delivery', async () => {
  const { DB, call } = await setup();
  DB.raw.prepare("UPDATE users SET app = 'staff' WHERE id = 'rider'").run();
  DB.raw.prepare("UPDATE orders SET staff_id = 'st1' WHERE id = 'NK-1'").run();
  let r = await call('POST', '/v1/me/orders/NK-1/chat', { text: 'Gate 2 par aana' }, 'cust');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  r = await call('POST', '/v1/me/orders/NK-1/chat', { text: 'call me 98765 43210' }, 'cust');
  assert.equal(r.json.error, 'no_numbers');
  r = await call('GET', '/v1/partner/orders/NK-1/chat', null, 'rider');
  assert.equal(r.json.messages.length, 1);
  assert.equal(r.json.messages[0].mine, false);
  r = await call('POST', '/v1/partner/orders/NK-1/chat', { text: 'Aa raha hoon' }, 'rider');
  r = await call('GET', '/v1/me/orders/NK-1/chat', null, 'cust');
  assert.deepEqual(r.json.messages.map((x) => x.mine), [true, false]);
  r = await call('GET', '/v1/me/orders/NK-1/chat', null, 'other');
  assert.equal(r.status, 404);
  DB.raw.prepare("UPDATE orders SET status = 'delivered', delivered_at = ? WHERE id = 'NK-1'").run(now() - 31 * 60);
  r = await call('POST', '/v1/me/orders/NK-1/chat', { text: 'thanks' }, 'cust');
  assert.equal(r.json.error, 'chat_closed');
});

test('incoming: the called phone can find a ringing call without the push', async () => {
  const { call } = await setup();
  let r = await call('GET', '/v1/voice/incoming', null, 'owner');
  assert.equal(r.json.call, null);
  r = await call('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1' }, 'cust');
  r = await call('GET', '/v1/voice/incoming', null, 'owner');
  assert.equal(r.json.call.other, 'Customer');
  r = await call('GET', '/v1/voice/incoming', null, 'cust');
  assert.equal(r.json.call, null);
});
