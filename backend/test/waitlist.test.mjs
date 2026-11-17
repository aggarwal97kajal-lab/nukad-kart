// Website early access list: saved in D1 first, then copied to Brevo with one confirmation email.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeDb } from './d1shim.mjs';
import worker from '../src/index.js';
import { syncWaitlist } from '../src/waitlist.js';

const GOOD = { name: 'Ravi  Sharma', email: 'Ravi@Example.com', phone: '+91 98765 43210', pincode: '110077', city: 'New Delhi', state: 'Delhi', consent: true };

function setup(extra = {}) {
  const DB = makeDb();
  const env = { DB, SESSION_SECRET: 's', ...extra };
  const waits = [];
  const ectx = { waitUntil: (p) => waits.push(p) };
  const call = async (method, body, origin = 'https://nukkadkart.in', ip = '1.2.3.4') => {
    const headers = { 'content-type': 'application/json', 'cf-connecting-ip': ip };
    if (origin) headers.origin = origin;
    const r = await worker.fetch(new Request('https://api.nukkadkart.in/v1/waitlist', { method, headers, body: body ? JSON.stringify(body) : undefined }), env, ectx);
    return { status: r.status, headers: r.headers, json: r.status === 204 ? null : await r.json() };
  };
  return { DB, env, call, waits };
}

function fakeBrevo() {
  const calls = [];
  globalThis.fetch = async (url, init) => {
    const path = url.replace('https://api.brevo.com/v3', '');
    calls.push({ path, method: init.method, body: init.body ? JSON.parse(init.body) : null, key: init.headers['api-key'] });
    if (path.startsWith('/contacts/attributes')) return new Response('{}', { status: 201 });
    if (path.startsWith('/contacts/lists?')) return Response.json({ lists: [] });
    if (path.startsWith('/contacts/folders?')) return Response.json({ folders: [{ id: 1 }] });
    if (path === '/contacts/lists') return Response.json({ id: 7 }, { status: 201 });
    if (path === '/contacts') return new Response('{"id":1}', { status: 201 });
    if (path === '/smtp/email') return Response.json({ messageId: 'm' }, { status: 201 });
    return new Response('{}', { status: 404 });
  };
  return calls;
}

test('preflight from the website is allowed; other sites get no CORS header', async () => {
  const { call } = setup();
  let r = await call('OPTIONS');
  assert.equal(r.status, 204);
  assert.equal(r.headers.get('access-control-allow-origin'), 'https://nukkadkart.in');
  r = await call('OPTIONS', null, 'https://evil.example');
  assert.equal(r.headers.get('access-control-allow-origin'), null);
  r = await call('POST', GOOD, 'https://evil.example');
  assert.equal(r.status, 403);
});

test('a good sign-up is saved, cleaned, and a second one with the same email updates the row', async () => {
  const { DB, call } = setup();
  let r = await call('POST', GOOD);
  assert.equal(r.status, 200, JSON.stringify(r.json));
  assert.equal(r.headers.get('access-control-allow-origin'), 'https://nukkadkart.in');
  const row = DB.raw.prepare('SELECT * FROM waitlist').get();
  assert.equal(row.email, 'ravi@example.com');
  assert.equal(row.name, 'Ravi Sharma');
  assert.equal(row.phone, '9876543210');
  r = await call('POST', { ...GOOD, city: 'Delhi', email: 'RAVI@example.com' });
  assert.equal(r.status, 200);
  assert.equal(DB.raw.prepare('SELECT COUNT(*) n FROM waitlist').get().n, 1);
  assert.equal(DB.raw.prepare('SELECT city FROM waitlist').get().city, 'Delhi');
});

test('bad fields are refused with the field name; no consent, no save', async () => {
  const { DB, call } = setup();
  for (const [f, v] of [['email', 'nope'], ['phone', '12345'], ['pincode', '012345'], ['state', 'Atlantis'], ['name', 'R'], ['consent', false], ['city', '<b></b>']]) {
    const r = await call('POST', { ...GOOD, [f]: v });
    assert.equal(r.status, 400, f);
    assert.equal(r.json.field, f);
  }
  assert.equal(DB.raw.prepare('SELECT COUNT(*) n FROM waitlist').get().n, 0);
});

test('bots filling the hidden field get "ok" and nothing is kept', async () => {
  const { DB, call } = setup();
  const r = await call('POST', { ...GOOD, company: 'Acme' });
  assert.equal(r.status, 200);
  assert.equal(DB.raw.prepare('SELECT COUNT(*) n FROM waitlist').get().n, 0);
});

test('one address cannot flood the list', async () => {
  const { call } = setup();
  let last;
  for (let i = 0; i < 22; i++) last = await call('POST', { ...GOOD, email: `a${i}@example.com` }, undefined, '9.9.9.9');
  assert.equal(last.status, 429);
});

test('Brevo gets the contact on the list and one confirmation email; the cron does not resend', async () => {
  const realFetch = globalThis.fetch;
  const calls = fakeBrevo();
  try {
    const { DB, env, call, waits } = setup({ BREVO_API_KEY: 'k' });
    await call('POST', GOOD);
    await Promise.all(waits);
    const contact = calls.find((c) => c.path === '/contacts');
    assert.deepEqual(contact.body.listIds, [7]);
    assert.equal(contact.body.attributes.PINCODE, '110077');
    assert.equal(contact.body.attributes.PHONE, '+919876543210');
    assert.equal(calls.filter((c) => c.path === '/smtp/email').length, 1);
    assert.equal(calls.find((c) => c.path === '/smtp/email').body.sender.email, 'support@nukkadkart.in');
    const row = DB.raw.prepare('SELECT brevo_synced, confirm_sent FROM waitlist').get();
    assert.deepEqual({ ...row }, { brevo_synced: 1, confirm_sent: 1 });
    await syncWaitlist(env);
    assert.equal(calls.filter((c) => c.path === '/smtp/email').length, 1);
    assert.equal(DB.raw.prepare("SELECT value FROM settings WHERE key = 'brevo_list_id'").get().value, '7');
  } finally { globalThis.fetch = realFetch; }
});

test('saved even with no Brevo key; the cron sends it once the key is there', async () => {
  const realFetch = globalThis.fetch;
  const calls = fakeBrevo();
  try {
    const { DB, env, call, waits } = setup();
    await call('POST', GOOD);
    assert.equal(waits.length, 0);
    assert.equal(DB.raw.prepare('SELECT brevo_synced FROM waitlist').get().brevo_synced, 0);
    env.BREVO_API_KEY = 'k';
    await syncWaitlist(env);
    assert.equal(DB.raw.prepare('SELECT confirm_sent FROM waitlist').get().confirm_sent, 1);
    assert.equal(calls.filter((c) => c.path === '/smtp/email').length, 1);
  } finally { globalThis.fetch = realFetch; }
});
