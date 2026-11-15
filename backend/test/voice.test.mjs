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

test('no call limit: many calls in a row, missed or connected; one at a time; closed 30 min after delivery', async () => {
  const { DB, call, ins } = await setup();
  for (let i = 0; i < 25; i++) {
    ins('voice_calls', { id: 'm' + i, kind: 'order', ref: 'NK-1', caller_id: 'cust', callee_id: 'owner', caller_label: 'Customer', callee_label: 'Delivery partner',
      status: i % 2 ? 'missed' : 'ended', created_at: T - 50 - i, answered_at: i % 2 ? null : T - 45 - i });
  }
  let r = await call('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1' }, 'cust');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  r = await call('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1' }, 'cust');
  assert.equal(r.json.error, 'call_busy');
  DB.raw.prepare('DELETE FROM voice_calls').run();
  DB.raw.prepare("UPDATE orders SET status = 'delivered', delivered_at = ? WHERE id = 'NK-1'").run(T - 31 * 60);
  r = await call('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1' }, 'cust');
  assert.equal(r.json.error, 'call_closed');
});

test('store button after accepting; rider button only once out for delivery', async () => {
  const { DB, call } = await setup();
  DB.raw.prepare("UPDATE orders SET status = 'accepted', staff_id = 'st1' WHERE id = 'NK-1'").run();
  let r = await call('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1', to: 'rider' }, 'cust');
  assert.equal(r.json.error, 'call_closed');
  r = await call('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1', to: 'store' }, 'cust');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  assert.equal(r.json.call.other, 'Sharma Store');
  assert.equal(DB.raw.prepare('SELECT callee_id FROM voice_calls WHERE id = ?').get(r.json.call.id).callee_id, 'owner');
  await call('POST', `/v1/voice/${r.json.call.id}/end`, {}, 'cust');
  DB.raw.prepare("UPDATE orders SET status = 'out' WHERE id = 'NK-1'").run();
  r = await call('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1', to: 'rider' }, 'cust');
  assert.equal(r.json.call.other, 'Delivery partner');
  assert.equal(DB.raw.prepare('SELECT callee_id FROM voice_calls WHERE id = ?').get(r.json.call.id).callee_id, 'rider');
  await call('POST', `/v1/voice/${r.json.call.id}/end`, {}, 'cust');
  r = await call('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1', to: 'store' }, 'cust');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  await call('POST', `/v1/voice/${r.json.call.id}/end`, {}, 'cust');
  // The shop owner calling the customer shows as the shop; the rider as "Delivery partner".
  r = await call('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1' }, 'owner');
  assert.equal(DB.raw.prepare('SELECT caller_label FROM voice_calls WHERE id = ?').get(r.json.call.id).caller_label, 'Sharma Store');
  await call('POST', `/v1/voice/${r.json.call.id}/end`, {}, 'owner');
  r = await call('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1' }, 'rider');
  assert.equal(DB.raw.prepare('SELECT caller_label FROM voice_calls WHERE id = ?').get(r.json.call.id).caller_label, 'Delivery partner');
});

test('ring push failed: still rings when the app was open in the last 30 s, else "can\u2019t be reached"', async () => {
  const { DB, call } = await setup();
  const env2 = { FCM_SERVICE_ACCOUNT: '{}' }; // a key that can't sign: no phone gets the ring push
  const { default: worker2, signSession: sign } = await import('../src/index.js');
  const go = async (method, path, body, who) => {
    const r = await worker2.fetch(new Request(`https://x${path}`, { method, headers: { 'content-type': 'application/json',
      authorization: `Bearer ${await sign(who, SECRET, 30, 's' + who)}` }, body: body ? JSON.stringify(body) : undefined }), { DB, SESSION_SECRET: SECRET, ...env2 });
    return { status: r.status, json: await r.json() };
  };
  let r = await go('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1' }, 'owner');
  assert.equal(r.json.error, 'callee_offline');
  await call('GET', '/v1/voice/incoming', null, 'cust'); // the customer's app is open
  r = await go('POST', '/v1/voice/start', { kind: 'order', ref: 'NK-1' }, 'owner');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  r = await call('GET', '/v1/voice/incoming', null, 'cust');
  assert.equal(r.json.call.other, 'Delivery partner'); // the owner delivers this one himself (nobody assigned)
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

test('order chat: read ticks; both shop phones see it; rider spot for the map', async () => {
  const { DB, call } = await setup();
  DB.raw.prepare("UPDATE users SET app = 'staff' WHERE id = 'rider'").run();
  DB.raw.prepare("UPDATE orders SET staff_id = 'st1' WHERE id = 'NK-1'").run();
  let r = await call('POST', '/v1/me/orders/NK-1/chat', { text: 'Gate 2' }, 'cust');
  assert.equal(r.json.otherReadAt, 0);
  r = await call('GET', '/v1/partner/orders/NK-1/chat', null, 'owner');
  assert.equal(r.json.messages.length, 1);
  r = await call('GET', '/v1/me/orders/NK-1/chat', null, 'cust');
  assert.ok(r.json.otherReadAt > 0);
  r = await call('GET', '/v1/me/orders/NK-1/rider', null, 'cust');
  assert.equal(r.json.rider, null);
  r = await call('POST', '/v1/partner/rider', { lat: 28.71, lng: 77.11 }, 'rider');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  DB.raw.prepare('UPDATE orders SET door = 1').run();
  await call('POST', '/v1/partner/rider', { lat: 28.71, lng: 77.11 }, 'rider');
  r = await call('GET', '/v1/me/orders/NK-1/rider', null, 'cust');
  assert.equal(r.json.rider.lat, 28.71);
  r = await call('GET', '/v1/me/orders/NK-1/rider', null, 'other');
  assert.equal(r.status, 404);
});

test('unread chat count on orders: customer and shop sides', async () => {
  const { DB, call } = await setup();
  await call('POST', '/v1/me/orders/NK-1/chat', { text: 'Gate 2' }, 'cust');
  await call('POST', '/v1/me/orders/NK-1/chat', { text: 'Jaldi' }, 'cust');
  let r = await call('GET', '/v1/partner/orders?tab=out', null, 'owner');
  assert.equal(r.json.orders[0].chatUnread, 2, JSON.stringify(r.json));
  r = await call('GET', '/v1/partner/orders/NK-1', null, 'owner');
  assert.equal(r.json.order.chatUnread, 2);
  await call('GET', '/v1/partner/orders/NK-1/chat', null, 'owner'); // opened the chat
  DB.raw.prepare('UPDATE orders SET chat_s_read = chat_s_read + 1').run();
  r = await call('GET', '/v1/partner/orders?tab=out', null, 'owner');
  assert.equal(r.json.orders[0].chatUnread, 0);
  await call('POST', '/v1/partner/orders/NK-1/chat', { text: 'Aa raha hoon' }, 'owner');
  r = await call('GET', '/v1/me/orders', null, 'cust');
  assert.equal(r.json.orders[0].chatUnread, 1);
});
