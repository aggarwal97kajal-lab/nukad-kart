import { test } from 'node:test';
import assert from 'node:assert/strict';
import { hasNumber } from '../src/chat.js';

test('phone numbers are caught, prices and quantities are not', () => {
  assert.equal(hasNumber('Mera number 98765 43210 hai'), true);
  assert.equal(hasNumber('call 9876-543-210'), true);
  assert.equal(hasNumber('nau aath saat chhe paanch char teen do'), true);
  assert.equal(hasNumber('2 kg tamatar, 40 rupaye'), false);
  assert.equal(hasNumber('ghar no. 1234, gali 4'), false);
  assert.equal(hasNumber('do kilo aloo aur ek dozen kela'), false);
});
