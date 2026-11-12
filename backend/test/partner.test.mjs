import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseTime, openAt, extendPass, offlineReason, istDate, MISSED_LIMIT, distanceM, requiredDocs } from '../src/partner.js';

// 12 Nov 2026, 15:00 IST = 09:30 UTC
const at = (h, m = 0) => Math.floor(Date.UTC(2026, 10, 12, h, m) / 1000) - 5.5 * 3600;

test('timings', () => {
  assert.equal(parseTime('8 am'), 480);
  assert.equal(parseTime('9:30 pm'), 21 * 60 + 30);
  assert.equal(parseTime('12 am'), 0);
  assert.equal(parseTime('21:30'), 21 * 60 + 30);
  assert.equal(parseTime('soon'), null);
  assert.equal(openAt('8 am', '10 pm', at(15)), true);
  assert.equal(openAt('8 am', '10 pm', at(22, 5)), false); // after closing: off the map
  assert.equal(openAt('6 pm', '1 am', at(0, 30)), true); // closes after midnight
  assert.equal(istDate(at(23, 30)), '2026-11-12');
});

test('pass extends from its end, or from now', () => {
  const t = at(12);
  assert.equal(extendPass(0, 30, t), t + 30 * 86400);
  assert.equal(extendPass(t + 86400, 7, t), t + 8 * 86400);
});

test('when a partner shop is hidden', () => {
  const t = at(15);
  const shop = { agreement_version: '1.0', status: 'active', pass_until: t + 86400, live: 1, opens_at: '8 am', closes_at: '10 pm', missed_date: null, missed_count: 0 };
  assert.equal(offlineReason(shop, t), null);
  assert.equal(offlineReason({ ...shop, pass_until: t - 1 }, t), 'no_pass');
  assert.equal(offlineReason({ ...shop, live: 0 }, t), 'switched_off');
  assert.equal(offlineReason(shop, at(22, 30)), 'closed_now');
  assert.equal(offlineReason({ ...shop, missed_date: istDate(t), missed_count: MISSED_LIMIT }, t), 'missed_orders');
  assert.equal(offlineReason({ ...shop, missed_date: '2026-11-11', missed_count: MISSED_LIMIT }, t), null); // new day
  assert.equal(offlineReason({ ...shop, status: 'blocked' }, t), 'blocked');
  assert.equal(offlineReason({ ...shop, agreement_version: null }, t), 'no_agreement');
  assert.equal(MISSED_LIMIT, 5);
  assert.equal(offlineReason({ ...shop, status: 'review' }, t), 'not_verified');
  assert.equal(offlineReason({ ...shop, status: 'pending' }, t), 'not_verified');
  assert.equal(offlineReason({ ...shop, status: 'rejected' }, t), 'rejected');
  assert.equal(offlineReason({ ...shop, missed_date: istDate(t), missed_count: 4 }, t), null);
});

test('admin email is matched by hash', async () => {
  const { sha256Hex } = await import('../src/partner.js');
  assert.equal((await sha256Hex('a@b.c')).length, 64);
});

test('shop pin vs photo GPS distance', () => {
  assert.ok(distanceM(28.5921, 77.046, 28.5921, 77.046) < 1);
  const d = distanceM(28.5921, 77.046, 28.5925, 77.046); // ~44 m north
  assert.ok(d > 40 && d < 50, String(d));
  assert.ok(distanceM(28.5921, 77.046, 28.593, 77.046) > 50);
});

test('documents a shop must upload', () => {
  assert.deepEqual(requiredDocs({ gst_type: 'none', fssai: '' }), ['pan', 'aadhaar']);
  assert.deepEqual(requiredDocs({ gst_type: 'regular', fssai: '12345678901234' }), ['pan', 'aadhaar', 'gst', 'fssai']);
});
