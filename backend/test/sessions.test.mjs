import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeDb } from './d1shim.mjs';
import { samePhoneOut } from '../src/sessions.js';

test('one phone shows once in Logged-in devices', async () => {
  const DB = makeDb();
  const env = { DB };
  const add = (id, dev, plat, did) => DB.prepare(
    'INSERT INTO sessions (id, user_id, device, platform, city, created_at, last_seen, device_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
  ).bind(id, 'u1', dev, plat, null, 1, 1, did).run();
  // Old logins from the same phone after reinstalls (random install ids) + one other phone model.
  await add('s1', 'OnePlus CPH2767', 'Android 16', 'aa11');
  await add('s2', 'OnePlus CPH2767', 'Android 16', 'bb22');
  await add('s3', 'OnePlus CPH2767', 'Android 16', null);
  await add('s4', 'Redmi Note 13', 'Android 15', 'cc33');
  await add('s5', 'OnePlus CPH2767', 'Android 16', 'a-other-phone');
  await samePhoneOut(env, 9, 'u1', 'a-myphone', 'OnePlus CPH2767', 'Android 16').run();
  const live = (await DB.prepare('SELECT id FROM sessions WHERE revoked_at IS NULL ORDER BY id').all()).results.map((r) => r.id);
  // Old random-id rows of this model are gone; the other model and a different phone with its own Android ID stay.
  assert.deepEqual(live, ['s4', 's5']);
  // Logging in again from the same phone replaces its own Android-ID session.
  await add('s6', 'OnePlus CPH2767', 'Android 16', 'a-myphone');
  await samePhoneOut(env, 10, 'u1', 'a-myphone', 'OnePlus CPH2767', 'Android 16').run();
  const live2 = (await DB.prepare('SELECT id FROM sessions WHERE revoked_at IS NULL ORDER BY id').all()).results.map((r) => r.id);
  assert.deepEqual(live2, ['s4', 's5']);
  // Old app (random id) does not log out other phones of the same model.
  await samePhoneOut(env, 11, 'u1', 'zz99', 'Redmi Note 13', 'Android 15').run();
  assert.equal((await DB.prepare("SELECT revoked_at FROM sessions WHERE id = 's4'").first()).revoked_at, null);
});
