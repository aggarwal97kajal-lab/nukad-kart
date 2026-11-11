import { test } from 'node:test';
import assert from 'node:assert/strict';
import { haversineM, boundingBox, signSession, verifySession, verifyGoogleIdToken, b64url } from '../src/index.js';

test('500 m maths', () => {
  const d = haversineM(28.718, 77.096, 28.719617, 77.096);
  assert.ok(Math.abs(d - 180) < 2, `got ${d}`);
  assert.ok(haversineM(28.718, 77.096, 28.726085, 77.096) > 890);
  const bb = boundingBox(28.718, 77.096, 500);
  assert.ok(28.718 + 0.0044 < bb.maxLat && bb.maxLat < 28.718 + 0.0046);
});

test('session token round trip and tamper', async () => {
  const t = await signSession('u1', 'secret');
  assert.equal((await verifySession(t, 'secret')).uid, 'u1');
  assert.equal(await verifySession(t, 'other'), null);
  assert.equal(await verifySession(t.slice(0, -2) + 'xx', 'secret'), null);
  assert.equal(await verifySession(await signSession('u1', 'secret', -1), 'secret'), null);
});

test('google id token verification', async () => {
  const kp = await crypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['sign', 'verify']);
  const jwk = { ...(await crypto.subtle.exportKey('jwk', kp.publicKey)), kid: 'k1' };
  const make = async (claims) => {
    const e = (o) => b64url(new TextEncoder().encode(JSON.stringify(o)));
    const head = e({ alg: 'RS256', kid: 'k1' }), body = e(claims);
    const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', kp.privateKey, new TextEncoder().encode(`${head}.${body}`));
    return `${head}.${body}.${b64url(sig)}`;
  };
  const now = Math.floor(Date.now() / 1000);
  const good = { iss: 'https://accounts.google.com', aud: 'web', sub: '42', email: 'a@b.c', email_verified: true, exp: now + 600 };
  assert.equal((await verifyGoogleIdToken(await make(good), ['web'], { keys: [jwk] })).sub, '42');
  await assert.rejects(verifyGoogleIdToken(await make({ ...good, aud: 'evil' }), ['web'], { keys: [jwk] }));
  await assert.rejects(verifyGoogleIdToken(await make({ ...good, exp: now - 3600 }), ['web'], { keys: [jwk] }));
  await assert.rejects(verifyGoogleIdToken(await make({ ...good, iss: 'x' }), ['web'], { keys: [jwk] }));
  const t = await make(good);
  await assert.rejects(verifyGoogleIdToken(t.slice(0, -4) + 'AAAA', ['web'], { keys: [jwk] }));
});
