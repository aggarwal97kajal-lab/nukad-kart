// The kirana web panel (nukkadkart.in/partner) may call only a few routes from the browser.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeDb } from './d1shim.mjs';
import worker from '../src/index.js';

const env = { DB: makeDb(), SESSION_SECRET: 's' };
const call = (method, path, origin) => worker.fetch(new Request('https://api.nukkadkart.in' + path, { method, headers: origin ? { origin } : {} }), env, { waitUntil() {} });

test('panel routes answer the preflight for nukkadkart.in only', async () => {
  let r = await call('OPTIONS', '/v1/partner/products', 'https://nukkadkart.in');
  assert.equal(r.status, 204);
  assert.equal(r.headers.get('access-control-allow-origin'), 'https://nukkadkart.in');
  assert.match(r.headers.get('access-control-allow-headers'), /authorization/);
  r = await call('OPTIONS', '/v1/partner/products', 'https://evil.example');
  assert.equal(r.headers.get('access-control-allow-origin'), null);
});

test('other partner routes stay closed to the browser', async () => {
  for (const p of ['/v1/partner/register', '/v1/partner/payments', '/v1/partner/orders/x/accept', '/v1/admin/payments']) {
    const r = await call('OPTIONS', p, 'https://nukkadkart.in');
    assert.equal(r.headers.get('access-control-allow-origin'), null, p);
  }
});

test('errors still carry the CORS header so the panel can show them', async () => {
  const r = await call('GET', '/v1/partner/me', 'https://nukkadkart.in');
  assert.equal(r.status, 401);
  assert.equal(r.headers.get('access-control-allow-origin'), 'https://nukkadkart.in');
});
