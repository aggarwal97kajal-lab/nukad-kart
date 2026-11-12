import { test } from 'node:test';
import assert from 'node:assert/strict';
import { cleanProduct, guessCategory } from '../src/products.js';

const shop = { kind: 'shop', fssai: '12345678901234' };
const base = { name: 'Parle-G Gold', size: '250 g', category: 'Bakery & biscuits', mrp: 30, price: 28 };

test('packed product: MRP rule and GST from category', () => {
  const v = cleanProduct(base, shop);
  assert.equal(v.gst, 5);
  assert.equal(v.in_stock, 1);
  assert.equal(v.stock, null);
  assert.throws(() => cleanProduct({ ...base, price: 31 }, shop), /price_above_mrp/);
  assert.throws(() => cleanProduct({ ...base, mrp: '' }, shop), /mrp_required/);
  assert.equal(cleanProduct({ ...base, stock: 0 }, shop).in_stock, 0);
});

test('food needs FSSAI for a shop, not for a thela', () => {
  assert.throws(() => cleanProduct(base, { kind: 'shop', fssai: '' }), /fssai_needed/);
  assert.ok(cleanProduct({ ...base, category: 'Hair' }, { kind: 'shop', fssai: '' }));
  assert.ok(cleanProduct({ kind: 'loose', name: 'Tomato', category: 'Vegetables', unit: 'kg', options: [500, 1000], price: 40 }, { kind: 'thela' }));
});

test('loose item sizes', () => {
  const v = cleanProduct({ kind: 'loose', name: 'Toor Dal', category: 'Atta, rice & dal', unit: 'kg', options: [1000, 250, 999], price: 160 }, shop);
  assert.equal(v.options, '[250,1000]');
  assert.equal(v.barcode, null);
  assert.throws(() => cleanProduct({ kind: 'loose', name: 'Onion', category: 'Vegetables', unit: 'kg', options: [], price: 1 }, shop), /pick_sizes/);
});

test('Open Food Facts category guess', () => {
  assert.equal(guessCategory(['en:biscuits', 'en:snacks']), 'Bakery & biscuits');
  assert.equal(guessCategory(['en:instant-noodles']), 'Instant Food');
  assert.equal(guessCategory([]), '');
});
