import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeDb } from './d1shim.mjs';
import worker, { signSession, now } from '../src/index.js';
import { staleThelas } from '../src/partner.js';

const SECRET = 'test-secret';
const T = now();

async function setup() {
  const DB = makeDb();
  const env = { DB, SESSION_SECRET: SECRET };
  const ins = (table, row) => DB.raw.prepare(`INSERT INTO ${table} (${Object.keys(row)}) VALUES (${Object.keys(row).map(() => '?')})`).run(...Object.values(row));
  ins('users', { id: 'u1', google_sub: 'g1', email: 'a@b.c', name: 'Ramu', created_at: T, updated_at: T });
  ins('sessions', { id: 's1', user_id: 'u1', created_at: T, last_seen: T });
  const common = { status: 'active', live: 1, pass_until: T + 86400, active: 1, demo: 0, agreement_version: 1, created_at: T };
  ins('stores', { id: 'th1', name: 'Ramu Sabzi', kind: 'thela', owner_id: 'u1', lat: 28.0, lng: 77.0, phone: '+919999999999', opens_at: '', closes_at: '', ...common });
  ins('stores', { id: 'sh1', name: 'Sharma Store', kind: 'shop', lat: 28.70, lng: 77.10, phone: '+918888888888', opens_at: '', closes_at: '', ...common });
  ins('products', { id: 'p1', store_id: 'th1', kind: 'loose', name: 'Aloo (Potato)', category: 'Vegetables', unit: 'kg', options: '[250,500,1000]',
    price: 30, gst: 0, in_stock: 1, produce_key: 'aloo', created_at: T, updated_at: T });
  ins('products', { id: 'p2', store_id: 'th1', kind: 'loose', name: 'Pyaz', category: 'Vegetables', unit: 'kg', options: '[1000]',
    price: 35, gst: 0, in_stock: 0, produce_key: 'pyaz', created_at: T, updated_at: T });
  const auth = { authorization: `Bearer ${await signSession('u1', SECRET, 30, 's1')}`, 'content-type': 'application/json' };
  const call = async (method, path, body, headers = {}) => {
    const r = await worker.fetch(new Request(`https://x${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined }), env);
    return { status: r.status, json: await r.json() };
  };
  return { DB, env, auth, call };
}

test('thela shows at its live location, without its phone number', async () => {
  const { DB, auth, call } = await setup();
  let r = await call('GET', '/v1/stores/nearby?lat=28.7001&lng=77.1001');
  assert.deepEqual(r.json.stores.map((s) => s.id), ['sh1'], 'thela with no location yet is hidden');
  r = await call('POST', '/v1/partner/location', { lat: 28.7010, lng: 77.1010, heading: 90 }, auth);
  assert.equal(r.status, 200, JSON.stringify(r.json));
  // new cell so the nearby cache is not hit
  r = await call('GET', '/v1/stores/nearby?lat=28.6999&lng=77.1001');
  const th = r.json.stores.find((s) => s.id === 'th1');
  assert.ok(th, JSON.stringify(r.json));
  assert.equal(th.phone, '');
  assert.equal(th.moving, true);
  assert.ok(th.distanceM < 200);
  assert.ok(r.json.stores.find((s) => s.id === 'sh1').phone.length > 5);
  const pr = await call('GET', '/v1/stores/th1/products');
  assert.deepEqual(pr.json.products.map((p) => p.produceKey), ['aloo']);
  // 15 minutes without location → hidden, and the seller is told once
  DB.raw.prepare('UPDATE stores SET live_at = ? WHERE id = ?').run(T - 900, 'th1');
  r = await call('GET', '/v1/stores/nearby?lat=28.6998&lng=77.0999');
  assert.equal(r.json.stores.find((s) => s.id === 'th1'), undefined);
  // fresh cell for the shop list check above is fine; stale push:
  assert.equal(await staleThelas({ DB }), 1);
  assert.equal(await staleThelas({ DB }), 0);
});

test('going offline clears the location; location ignored while offline', async () => {
  const { DB, auth, call } = await setup();
  await call('POST', '/v1/partner/location', { lat: 28.7, lng: 77.1 }, auth);
  const r = await call('POST', '/v1/partner/live', { on: false }, auth);
  assert.equal(r.status, 200, JSON.stringify(r.json));
  assert.equal(DB.raw.prepare('SELECT live_lat FROM stores WHERE id = ?').get('th1').live_lat, null);
  const l = await call('POST', '/v1/partner/location', { lat: 28.7, lng: 77.1 }, auth);
  assert.equal(l.json.live, false);
});
