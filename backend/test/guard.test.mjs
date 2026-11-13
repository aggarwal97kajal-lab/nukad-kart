import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeDb } from './d1shim.mjs';
import worker from '../src/index.js';
import { cleanText, cleanDevice } from '../src/guard.js';

const post = (env, path, b, ip = '1.2.3.4') => worker.fetch(new Request(`https://x${path}`, {
  method: 'POST', headers: { 'content-type': 'application/json', 'cf-connecting-ip': ip }, body: JSON.stringify(b),
}), env, { waitUntil() {} });

test('login: bad input gets one generic error, 11th try in a minute is slowed down', async () => {
  const env = { DB: makeDb(), SESSION_SECRET: 's', GOOGLE_CLIENT_IDS: 'abc' };
  const bad = [{ idToken: '<script>' }, { idToken: 123 }, { idToken: 'x'.repeat(5000) }, { idToken: 'a.b.c', app: 'evil' }, []];
  for (const b of bad) {
    const r = await post(env, '/v1/auth/google', b);
    assert.equal(r.status, 400);
    assert.deepEqual(await r.json(), { error: 'bad_request' });
  }
  for (let i = 0; i < 5; i++) await post(env, '/v1/auth/google', {});
  const r = await post(env, '/v1/auth/google', {});
  assert.equal(r.status, 429);
  assert.equal((await r.json()).error, 'slow_down');
  // Another IP is not affected.
  assert.equal((await post(env, '/v1/auth/google', {}, '5.6.7.8')).status, 400);
});

test('staff login: 5 tries per number per 15 min, wrong format is generic', async () => {
  const env = { DB: makeDb(), SESSION_SECRET: 's', MSG91_AUTHKEY: 'k' };
  const r1 = await post(env, '/v1/staff/login', { phone: '12345', accessToken: 'tok-123456789' });
  assert.deepEqual(await r1.json(), { error: 'bad_request' });
  for (let i = 0; i < 5; i++) await post(env, '/v1/staff/login', { phone: '9876543210', accessToken: 'tok-123456789' }, `9.9.9.${i}`);
  const r = await post(env, '/v1/staff/login', { phone: '9876543210', accessToken: 'tok-123456789' }, '9.9.9.99');
  assert.equal(r.status, 429);
});

test('device text is plain and short', () => {
  assert.equal(cleanText('<script>alert(1)</script>OnePlus\u0000 12', 60), 'alert(1)OnePlus 12');
  assert.deepEqual(cleanDevice({ name: '<b>Redmi</b>', platform: 'Android 15', id: 'a-12;DROP' }), { name: 'Redmi', platform: 'Android 15', id: 'a-12DROP' });
});
