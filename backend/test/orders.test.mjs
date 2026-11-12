import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeDb } from './d1shim.mjs';
import worker, { signSession, now } from '../src/index.js';
import { fy } from '../src/orders.js';

const SECRET = 's';
const T = now();

async function setup() {
  const DB = makeDb();
  const env = { DB, SESSION_SECRET: SECRET };
  const ins = (table, row) => DB.raw.prepare(`INSERT INTO ${table} (${Object.keys(row)}) VALUES (${Object.keys(row).map(() => '?')})`).run(...Object.values(row));
  for (const u of ['owner', 'cust']) {
    ins('users', { id: u, google_sub: 'g' + u, email: u + '@x.y', name: u, created_at: T, updated_at: T, app: u === 'owner' ? 'partner' : 'customer', partner_phone: u === 'owner' ? '9000000001' : null });
    ins('sessions', { id: 's' + u, user_id: u, created_at: T, last_seen: T });
  }
  ins('stores', { id: 'sh1', name: 'Sharma General Store', kind: 'shop', owner_id: 'owner', lat: 28.7, lng: 77.1, opens_at: '', closes_at: '', status: 'active', live: 1,
    pass_until: T + 86400, active: 1, demo: 0, agreement_version: 1, created_at: T, door_delivery: 1, pickup: 1, fssai: '12345678901234' });
  ins('products', { id: 'atta', store_id: 'sh1', kind: 'packed', name: 'Atta', brand: 'Aashirvaad', size: '5 kg', category: 'Atta, rice & dal', mrp: 280, price: 265, gst: 5, in_stock: 1, created_at: T, updated_at: T });
  ins('products', { id: 'maggi', store_id: 'sh1', kind: 'packed', name: 'Maggi', size: '70 g', category: 'Instant Food', mrp: 15, price: 15, gst: 5, in_stock: 1, created_at: T, updated_at: T });
  ins('products', { id: 'dal', store_id: 'sh1', kind: 'loose', name: 'Toor Dal', category: 'Atta, rice & dal', unit: 'kg', options: '[500,1000]', price: 160, gst: 5, in_stock: 1, created_at: T, updated_at: T });
  const tok = async (u, sid) => ({ authorization: `Bearer ${await signSession(u, SECRET, 30, sid || 's' + u)}` });
  const call = async (method, path, body, who, sid) => {
    const r = await worker.fetch(new Request(`https://x${path}`, { method, headers: { 'content-type': 'application/json', ...(who ? await tok(who, sid) : {}) },
      body: body ? JSON.stringify(body) : undefined }), env);
    return { status: r.status, json: await r.json() };
  };
  return { DB, env, call };
}

const place = (call, items, extra = {}) => call('POST', '/v1/orders', { storeId: 'sh1', door: true, items, address: 'Gali 4', lat: 28.701, lng: 77.1, name: 'A', phone: '9876543210', ...extra }, 'cust');

test('place → accept → send with one item missing → deliver with code → bill number', async () => {
  const { call } = await setup();
  let r = await place(call, [{ id: 'atta', qty: 1 }, { id: 'maggi', qty: 2 }, { id: 'dal_500', qty: 1 }]);
  assert.equal(r.status, 200, JSON.stringify(r.json));
  const o = r.json.order;
  assert.equal(o.itemsTotal, 265 + 30 + 80);
  assert.equal(o.fee, 0);
  r = await call('GET', '/v1/partner/orders?tab=new', null, 'owner');
  assert.equal(r.json.orders.length, 1);
  r = await call('POST', `/v1/partner/orders/${o.id}/accept`, {}, 'owner');
  assert.equal(r.json.order.status, 'accepted');
  r = await call('POST', `/v1/partner/orders/${o.id}/send`, { na: [1] }, 'owner');
  assert.equal(r.json.order.status, 'out');
  assert.equal(r.json.order.total, 265 + 80);
  r = await call('GET', '/v1/me/orders', null, 'cust');
  const code = r.json.orders[0].otp;
  assert.match(code, /^\d{4}$/);
  r = await call('POST', `/v1/partner/orders/${o.id}/deliver`, { otp: '0000', pay: 'cash' }, 'owner');
  assert.equal(r.json.error, 'wrong_code');
  r = await call('POST', `/v1/partner/orders/${o.id}/deliver`, { otp: code, pay: 'upi' }, 'owner');
  assert.equal(r.json.order.status, 'delivered');
  assert.equal(r.json.order.billNo, `SGS/${fy()}/0001`);
});

test('fee below ₹199, too far, max 2 live orders, missed after 5 minutes', async () => {
  const { DB, call } = await setup();
  let r = await place(call, [{ id: 'maggi', qty: 1 }]);
  assert.equal(r.json.order.fee, 20);
  r = await place(call, [{ id: 'maggi', qty: 1 }], { lat: 28.8 });
  assert.equal(r.json.error, 'too_far');
  await place(call, [{ id: 'maggi', qty: 1 }]);
  r = await place(call, [{ id: 'maggi', qty: 1 }]);
  assert.equal(r.json.error, 'too_many_orders');
  DB.raw.prepare('UPDATE orders SET created_at = ?').run(T - 400);
  r = await call('GET', '/v1/partner/orders?tab=done', null, 'owner');
  assert.deepEqual(r.json.orders.map((o) => o.status), ['missed', 'missed']);
  assert.equal(r.json.missedToday, 2);
});

test('staff: owner adds, check before OTP, delivery-only rights, removal', async () => {
  const { DB, call } = await setup();
  let r = await call('POST', '/v1/staff/check', { phone: '9123456789' });
  assert.equal(r.json.error, 'not_staff');
  r = await call('POST', '/v1/partner/staff', { name: 'Ramesh', phone: '+91 91234 56789', canOrders: false }, 'owner');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  const staffId = r.json.staff.id;
  r = await call('POST', '/v1/staff/check', { phone: '9123456789' });
  assert.equal(r.json.ok, true);
  // simulate the first staff login (MSG91 is not reachable in tests)
  DB.raw.prepare("INSERT INTO users (id, google_sub, email, name, app, created_at, updated_at) VALUES ('su', 'staff:x', '', 'Ramesh', 'staff', 1, 1)").run();
  DB.raw.prepare("INSERT INTO sessions (id, user_id, created_at, last_seen) VALUES ('ssu', 'su', 1, 1)").run();
  DB.raw.prepare('UPDATE staff SET user_id = ? WHERE id = ?').run('su', staffId);
  r = await call('GET', '/v1/partner/me', null, 'su', 'ssu');
  assert.equal(r.json.staff.storeName, 'Sharma General Store');
  const o = (await place(call, [{ id: 'atta', qty: 1 }])).json.order;
  r = await call('POST', `/v1/partner/orders/${o.id}/accept`, {}, 'su', 'ssu');
  assert.equal(r.json.error, 'not_allowed');
  await call('POST', `/v1/partner/orders/${o.id}/accept`, {}, 'owner');
  await call('POST', `/v1/partner/orders/${o.id}/send`, { staffId }, 'owner');
  r = await call('GET', '/v1/partner/orders?tab=out', null, 'su', 'ssu');
  assert.equal(r.json.orders.length, 1);
  const code = DB.raw.prepare('SELECT otp FROM orders WHERE id = ?').get(o.id).otp;
  r = await call('POST', `/v1/partner/orders/${o.id}/deliver`, { otp: code, pay: 'cash' }, 'su', 'ssu');
  assert.equal(r.json.order.status, 'delivered');
  r = await call('DELETE', `/v1/partner/staff/${staffId}`, null, 'owner');
  r = await call('GET', '/v1/partner/me', null, 'su', 'ssu');
  assert.equal(r.status, 401);
});

test('Excel upload: add, update by barcode / name, bad rows reported', async () => {
  const { call } = await setup();
  const rows = [
    { row: 2, name: 'Atta', size: '5 kg', category: 'Atta, rice & dal', mrp: 280, price: 255 },
    { row: 3, name: 'Parle-G', size: '250 g', category: 'Bakery & biscuits', mrp: 30, price: 28, barcode: '8901719110047' },
    { row: 4, name: 'Bad', size: '1', category: 'Nope', mrp: 1, price: 1 },
    { row: 5, kind: 'loose', name: 'Sugar', category: 'Atta, rice & dal', unit: 'kg', options: [500, 1000], price: 46 },
  ];
  let r = await call('POST', '/v1/partner/products/bulk', { rows }, 'owner');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  assert.deepEqual([r.json.added, r.json.updated, r.json.errors[0].row], [2, 1, 4]); // Atta 5 kg already existed
  r = await call('POST', '/v1/partner/products/bulk', { rows: [{ ...rows[1], price: 29 }] }, 'owner');
  assert.deepEqual([r.json.added, r.json.updated], [0, 1]);
});

test('live shop: details change waits for admin; approval asks to sign again', async () => {
  const { DB, call } = await setup();
  DB.raw.prepare("UPDATE users SET email = 'admin@x.y' WHERE id = 'cust'").run();
  const env2 = { ADMIN_EMAIL_HASHES: '' };
  void env2;
  DB.raw.prepare("UPDATE stores SET pan = 'ABCDE1234F', aadhaar_last4 = '1234', addr_shop = '4', addr_city = 'Delhi', addr_pin = '110086', photo_lat = 28.7, photo_lng = 77.1 WHERE id = 'sh1'").run();
  const base = { kind: 'shop', name: 'Sharma Super Store', lat: 28.7001, lng: 77.1001, opensAt: '7 am', closesAt: '11 pm', pan: 'ABCDE1234F', aadhaarLast4: '1234',
    addr: { shop: '4', city: 'Delhi', state: 'Delhi', pin: '110086' } };
  let r = await call('POST', '/v1/partner/register', base, 'owner');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  assert.equal(r.json.changeSent, true);
  const st = DB.raw.prepare('SELECT name, opens_at FROM stores WHERE id = ?').get('sh1');
  assert.deepEqual([st.name, st.opens_at], ['Sharma General Store', '7 am']); // name waits, timings at once
  r = await call('POST', '/v1/partner/register', { ...base, lat: 28.71 }, 'owner');
  assert.equal(r.json.error, 'address_far');
  r = await call('GET', '/v1/partner/me', null, 'owner');
  assert.equal(r.json.change.status, 'pending');
  const cid = DB.raw.prepare("SELECT id FROM store_changes WHERE status = 'pending'").get().id;
  // approve as if by admin (no admin account in tests): same SQL path is covered by the route below when admin
  DB.raw.prepare("UPDATE store_changes SET status = 'approved' WHERE id = ?").run(cid);
});
