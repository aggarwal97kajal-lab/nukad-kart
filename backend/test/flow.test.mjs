import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeDb } from './d1shim.mjs';
import worker, { signSession, now } from '../src/index.js';
import { sha256Hex } from '../src/partner.js';
import { passReminders, weekReport } from '../src/reminders.js';

const SECRET = 's';
const T = now();

async function setup() {
  const DB = makeDb();
  const env = { DB, SESSION_SECRET: SECRET, ADMIN_EMAIL_HASHES: await sha256Hex('admin@x.y') };
  const ins = (table, row) => DB.raw.prepare(`INSERT INTO ${table} (${Object.keys(row)}) VALUES (${Object.keys(row).map(() => '?')})`).run(...Object.values(row));
  for (const u of ['owner', 'admin', 'c1']) {
    ins('users', { id: u, google_sub: 'g' + u, email: u + '@x.y', name: u, created_at: T, updated_at: T, partner_phone: u === 'owner' ? '9999999999' : null });
    ins('sessions', { id: 's' + u, user_id: u, created_at: T, last_seen: T });
  }
  ins('stores', { id: 'sh1', name: 'Gupta Store', kind: 'shop', owner_id: 'owner', lat: 28.7, lng: 77.1, opens_at: '', closes_at: '', status: 'active', live: 1,
    pass_until: T + 86400, active: 1, demo: 0, agreement_version: 1, created_at: T, fssai: '', gst_type: 'none', address: 'A', phone: '9999999999' });
  for (const type of ['pan', 'aadhaar']) ins('partner_docs', { id: 'D' + type, store_id: 'sh1', type, mime: 'application/pdf', name: type + '.pdf', size: 10, chunks: 1, done: 1, created_at: T });
  const tok = async (u) => ({ authorization: `Bearer ${await signSession(u, SECRET, 30, 's' + u)}` });
  const call = async (method, path, body, who) => {
    const r = await worker.fetch(new Request(`https://x${path}`, { method, headers: { 'content-type': 'application/json', ...(who ? await tok(who) : {}) },
      body: body ? JSON.stringify(body) : undefined }), env);
    return { status: r.status, json: await r.json() };
  };
  return { DB, env, ins, call };
}

test('live shop adds FSSAI: certificate can be added, approved docs stay locked, approve waits for the certificate', async () => {
  const { DB, ins, call } = await setup();
  ins('store_changes', { id: 'c_1', store_id: 'sh1', data: JSON.stringify({ fssai: '12345678901234' }), has_photo: 0, status: 'pending', created_at: T });
  let r = await call('GET', '/v1/partner/docs', null, 'owner');
  assert.deepEqual(r.json.required, ['pan', 'aadhaar', 'fssai']);
  assert.deepEqual(r.json.locked, ['pan', 'aadhaar']);
  r = await call('GET', '/v1/partner/me', null, 'owner');
  assert.deepEqual(r.json.change.needsDocs, ['fssai']);
  r = await call('POST', '/v1/partner/docs', { type: 'pan', mime: 'application/pdf', size: 10, chunks: 1 }, 'owner');
  assert.equal(r.json.error, 'docs_locked');
  r = await call('POST', '/v1/admin/changes/c_1/approve', {}, 'admin');
  assert.equal(r.json.error, 'doc_needed');
  r = await call('GET', '/v1/admin/changes', null, 'admin');
  assert.deepEqual(r.json.changes[0].missingDocs, ['fssai']);
  r = await call('POST', '/v1/partner/docs', { type: 'fssai', mime: 'application/pdf', size: 10, chunks: 1 }, 'owner');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  DB.raw.prepare('UPDATE partner_docs SET done = 1 WHERE id = ?').run(r.json.id);
  r = await call('POST', '/v1/admin/changes/c_1/approve', {}, 'admin');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  r = await call('GET', '/v1/partner/me', null, 'owner');
  assert.equal(r.json.store.fssai, '12345678901234');
  assert.equal(r.json.store.docsComplete, true);
});

test('pass reminders: once the evening before, once on the last morning', async () => {
  const { DB, env } = await setup();
  // 8 pm IST, pass ends tomorrow 11:59 pm
  const eve = Math.floor(Date.UTC(2026, 10, 14, 14, 30) / 1000);
  DB.raw.prepare('UPDATE stores SET pass_until = ?').run(eve + 28 * 3600);
  assert.equal(await passReminders(env, eve), 1);
  assert.equal(await passReminders(env, eve + 600), 0);
  const morning = eve + 13 * 3600 + 1800; // next day 9:30 am IST, 14.5 h left
  assert.equal(await passReminders(env, morning), 1);
  assert.equal(await passReminders(env, morning + 600), 0);
});

test('weekly report counts views, calls and new customers', async () => {
  const { DB, env, ins } = await setup();
  ins('store_views', { store_id: 'sh1', day: new Date((T + 5.5 * 3600) * 1000).toISOString().slice(0, 10), n: 12 });
  ins('calls', { id: 'k1', thela_id: 'sh1', customer_id: 'c1', lat: 0, lng: 0, address: 'Gali 4', status: 'done', created_at: T - 100 });
  const s = DB.raw.prepare('SELECT * FROM stores WHERE id = ?').get('sh1');
  const r = await weekReport(env, s, T);
  assert.equal(r.views, 12);
  assert.equal(r.calls, 1);
  assert.equal(r.newCustomers, 1);
  assert.equal(r.streets[0].address, 'Gali 4');
});
