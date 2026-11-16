// Pre-launch security fixes (Nov 2026 audit): each test is one finding that must stay fixed.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeDb } from './d1shim.mjs';
import worker, { signSession, now, phoneMatches, socketAuth, verifySession } from '../src/index.js';
import { sha256Hex } from '../src/partner.js';
import { secureInt } from '../src/orders.js';

const SECRET = 's';
const T = now();

async function setup() {
  const DB = makeDb();
  const files = new Map();
  const FILES = {
    put: async (k, v) => { files.set(k, v); },
    get: async (k) => (files.has(k) ? { body: files.get(k), arrayBuffer: async () => files.get(k) } : null),
    delete: async (k) => { for (const x of [].concat(k)) files.delete(x); },
  };
  const env = { DB, FILES, SESSION_SECRET: SECRET, ADMIN_EMAIL_HASHES: await sha256Hex('admin@x.y') };
  const ins = (table, row) => DB.raw.prepare(`INSERT INTO ${table} (${Object.keys(row)}) VALUES (${Object.keys(row).map(() => '?')})`).run(...Object.values(row));
  for (const u of ['owner', 'owner2', 'admin', 'c1', 'c2']) {
    ins('users', { id: u, google_sub: 'g' + u, email: u + '@x.y', name: u, created_at: T, updated_at: T, phone: u === 'c1' ? '9876500001' : null,
      phone_verified: u === 'c1' ? 1 : 0, partner_phone: u.startsWith('owner') ? `99999999${u.length}0` : null });
    ins('sessions', { id: 's' + u, user_id: u, created_at: T, last_seen: T });
  }
  const shop = (id, owner) => ins('stores', { id, name: 'Gupta Store', kind: 'shop', owner_id: owner, lat: 28.7, lng: 77.1, opens_at: '', closes_at: '',
    status: 'active', live: 1, pass_until: T + 86400, active: 1, demo: 0, agreement_version: '1.0', created_at: T, fssai: '', gst_type: 'none',
    address: 'A', phone: '9999999999', pan: 'ABCDE1234F', aadhaar_last4: '1234', door_delivery: 1, pickup: 1 });
  shop('sh1', 'owner');
  shop('sh2', 'owner2');
  for (const type of ['pan', 'aadhaar']) ins('partner_docs', { id: 'D' + type, store_id: 'sh1', type, mime: 'application/pdf', name: type + '.pdf', size: 10, chunks: 1, done: 1, created_at: T });
  ins('products', { id: 'prmilk', store_id: 'sh1', name: 'Milk', category: 'Dairy, Bread & Eggs', kind: 'packed', price: 27, mrp: 28, gst: 5, size: '500 ml', in_stock: 1, created_at: T, updated_at: T });
  ins('settings', { key: 'upi_id', value: 'nukad@upi' });
  const tok = async (u) => ({ authorization: `Bearer ${await signSession(u, SECRET, 30, 's' + u)}` });
  const call = async (method, path, body, who, raw) => {
    const headers = { ...(raw ? {} : { 'content-type': 'application/json' }), ...(who ? await tok(who) : {}) };
    const r = await worker.fetch(new Request(`https://x${path}`, { method, headers, body: raw ?? (body ? JSON.stringify(body) : undefined) }), env);
    return { status: r.status, json: await r.json() };
  };
  return { DB, files, call };
}

test('F1: "SUCCESS" from the phone does not start a pass; the admin confirm does, once', async () => {
  const { DB, call } = await setup();
  const before = DB.raw.prepare('SELECT pass_until FROM stores WHERE id = ?').get('sh1').pass_until;
  let r = await call('POST', '/v1/partner/payments', { plan: 'monthly', key: 'k'.repeat(20) }, 'owner');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  const id = r.json.payment.id;
  r = await call('POST', `/v1/partner/payments/${'k'.repeat(20)}/done`, { upiStatus: 'SUCCESS', upiRef: 'X1' }, 'owner');
  assert.equal(r.json.payment.status, 'CHECKING');
  assert.equal(DB.raw.prepare('SELECT pass_until FROM stores WHERE id = ?').get('sh1').pass_until, before, 'no free days');
  // Not a second pending claim on top of two being checked.
  await call('POST', '/v1/partner/payments', { plan: 'weekly', key: 'j'.repeat(20) }, 'owner');
  await call('POST', `/v1/partner/payments/${'j'.repeat(20)}/done`, { upiStatus: 'SUCCESS' }, 'owner');
  r = await call('POST', '/v1/partner/payments', { plan: 'weekly', key: 'h'.repeat(20) }, 'owner');
  assert.equal(r.json.error, 'payment_being_checked');
  // Only an admin confirms; a double tap adds the days once.
  r = await call('POST', `/v1/admin/payments/${id}/confirm`, {}, 'owner');
  assert.equal(r.status, 403);
  await call('POST', `/v1/admin/payments/${id}/confirm`, {}, 'admin');
  await call('POST', `/v1/admin/payments/${id}/confirm`, {}, 'admin');
  const p = DB.raw.prepare('SELECT status, pass_until FROM pass_payments WHERE id = ?').get(id);
  assert.equal(p.status, 'PAID');
  assert.equal(DB.raw.prepare('SELECT pass_until FROM stores WHERE id = ?').get('sh1').pass_until, before + 30 * 86400);
});

test('F2: a phone check needs MSG91 to return the same number', () => {
  assert.equal(phoneMatches(null, '9876543210'), false);
  assert.equal(phoneMatches('', '9876543210'), false);
  assert.equal(phoneMatches('9876543211', '9876543210'), false);
  assert.equal(phoneMatches('9876543210', '9876543210'), true);
});

test('F3: orders, calls and chats need a verified number; orders have an hourly limit', async () => {
  const { DB, call } = await setup();
  const order = { storeId: 'sh1', door: false, items: [{ id: 'prmilk', qty: 1 }], name: 'C', phone: '9876500001' };
  let r = await call('POST', '/v1/orders', order, 'c2');
  assert.equal(r.json.error, 'phone_needed');
  r = await call('POST', '/v1/me/chats/sh1', { text: 'hi' }, 'c2');
  assert.notEqual(r.status, 200);
  for (let i = 0; i < 6; i++) {
    r = await call('POST', '/v1/orders', order, 'c1');
    assert.equal(r.status, 200, JSON.stringify(r.json));
    await call('POST', `/v1/me/orders/${r.json.order.id}/cancel`, {}, 'c1');
  }
  r = await call('POST', '/v1/orders', order, 'c1');
  assert.equal(r.json.error, 'slow_down');
  // Cancelled by the customer: never counted as missed by the shop.
  assert.equal(DB.raw.prepare('SELECT missed_count FROM stores WHERE id = ?').get('sh1').missed_count || 0, 0);
});

test('F4: no seller number in public lists; staff check is rate limited', async () => {
  const { call } = await setup();
  const r = await call('GET', '/v1/stores/nearby?lat=28.7001&lng=77.1001');
  assert.equal(r.status, 200);
  assert.ok(r.json.stores.length >= 1);
  for (const s of r.json.stores) assert.equal(s.phone, undefined);
  let last;
  for (let i = 0; i < 11; i++) last = await call('POST', '/v1/staff/check', { phone: '9876543210' });
  assert.equal(last.json.error, 'slow_down');
});

test('F5: live sockets read the session from the header; a bad token is just "not signed in"', async () => {
  const h = socketAuth(new Request('https://x/v1/chat/socket?chat=1', { headers: { authorization: 'Bearer abc' } }));
  assert.equal(h.headers.get('authorization'), 'Bearer abc');
  const q = socketAuth(new Request('https://x/v1/chat/socket?chat=1&token=old'));
  assert.equal(q.headers.get('authorization'), null); // a token in the URL is never read
  assert.equal(await verifySession('!!!.@@@', SECRET), null);
});

test('F6: deleting an account wipes name, number and spot from past orders and cancels open ones', async () => {
  const { DB, call } = await setup();
  const r = await call('POST', '/v1/orders', { storeId: 'sh1', door: true, items: [{ id: 'prmilk', qty: 2 }], address: 'Flat 4, Gali 2', lat: 28.7001, lng: 77.1001,
    name: 'Chintu', phone: '9876500001' }, 'c1');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  await call('POST', '/v1/me/delete', { reason: 'x' }, 'c1');
  const o = DB.raw.prepare('SELECT status, to_name, to_phone, address, lat, items_total FROM orders WHERE id = ?').get(r.json.order.id);
  assert.equal(o.status, 'cancelled');
  assert.equal(o.to_name, '');
  assert.equal(o.to_phone, '');
  assert.equal(o.address, 'Deleted account');
  assert.equal(o.lat, null);
  assert.equal(o.items_total, 54); // the bill amount stays
});

test('F9: public /health has no call-relay check or secret shapes', async () => {
  const { call } = await setup();
  const r = await call('GET', '/health?calls=1');
  assert.equal(r.json.turnShape, undefined);
  assert.equal(r.json.calls, 'stun_only');
});

test('F10: secure random numbers stay in range', () => {
  for (let i = 0; i < 2000; i++) {
    const n = secureInt(1000, 9999);
    assert.ok(n >= 1000 && n <= 9999);
  }
});

test('F13: a document part for another shop is refused before anything is stored', async () => {
  const { DB, files, call } = await setup();
  DB.raw.prepare("INSERT INTO partner_docs (id, store_id, type, mime, name, size, chunks, done, created_at) VALUES ('Dother', 'sh2', 'gst', 'application/pdf', 'g.pdf', 10, 2, 0, ?)").run(T);
  files.set('docs/Dother/0', new Uint8Array([1, 2, 3]));
  const r = await call('PUT', '/v1/partner/docs/Dother/0', null, 'owner', new Uint8Array([9, 9, 9]));
  assert.equal(r.status, 404);
  assert.deepEqual([...files.get('docs/Dother/0')], [1, 2, 3], 'the other shop\'s part is untouched');
});
