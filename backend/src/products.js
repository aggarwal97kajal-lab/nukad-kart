// Partner products: each shop/thela keeps its own list (no shared catalogue).
//   GET    /v1/partner/products?q=&cat=&filter=out|all&before=   (auth) my products, 50 at a time
//   POST   /v1/partner/products                                 (auth) add or update { id?, ... }
//   PATCH  /v1/partner/products/:id/stock { inStock, stock }    (auth) the quick switch / + −
//   DELETE /v1/partner/products/:id                             (auth)
//   PUT    /v1/partner/products/:id/photo   (raw JPEG)          (auth) own photo
//   GET    /v1/partner/barcode/:code                            (auth) name/photo from Open Food Facts (cached)
//   GET    /v1/products/:id/photo                                      product photo
import { HttpError, json, body, now } from './index.js';

export const CATEGORIES = {
  // name: [HSN, GST %, food (needs FSSAI for a shop)]
  'Atta, rice & dal': ['1006', 5, true],
  'Oil, ghee & masala': ['1514', 5, true],
  'Dairy, bread & eggs': ['0401', 0, true],
  'Bakery & biscuits': ['1905', 5, true],
  'Dry fruits & cereals': ['0801', 5, true],
  'Chicken, meat & fish': ['0207', 0, true],
  'Vegetables': ['0709', 0, false],
  'Fruits': ['0810', 0, false],
  'Chips & Namkeen': ['2005', 5, true],
  'Sweets & Chocolates': ['1806', 5, true],
  'Drinks & Juices': ['2202', 5, true],
  'Tea, Coffee & Milk Drinks': ['0902', 5, true],
  'Instant Food': ['1902', 5, true],
  'Sauces & Spreads': ['2103', 5, true],
  'Icecreams & more': ['2105', 5, true],
  'Bath & Body': ['3401', 5, false],
  'Hair': ['3305', 5, false],
  'Skin & Face': ['3304', 5, false],
  'Beauty & Cosmetics': ['3304', 5, false],
  'Feminine Hygiene': ['9619', 0, false],
  'Baby Care': ['9619', 5, false],
  'Health & Pharma': ['3004', 5, false],
  'Cleaners & Repellents': ['3402', 5, false],
  'Electronics': ['8539', 18, false],
  'Stationary & Games': ['4820', 5, false],
  'Home & Pooja': ['3307', 5, false],
};
export const GST_RATES = [0, 5, 18, 40];
export const UNITS = { kg: [100, 250, 500, 1000, 2000, 5000], litre: [250, 500, 1000, 2000, 5000], piece: [1, 2, 3, 6, 12], dozen: [1, 2], bunch: [1, 2, 3] };
const PAGE = 50;

/** Checks a product from the app; returns clean values or throws. */
export function cleanProduct(b, store) {
  const str = (k, max = 120) => String(b[k] ?? '').trim().slice(0, max);
  const kind = b.kind === 'loose' ? 'loose' : 'packed';
  const name = str('name', 80);
  if (name.length < 2) throw new HttpError(400, 'name_required');
  const category = str('category', 60);
  const cat = CATEGORIES[category];
  if (!cat) throw new HttpError(400, 'bad_category');
  if (cat[2] && store.kind !== 'thela' && !store.fssai) throw new HttpError(403, 'fssai_needed');
  const price = Math.round(Number(b.price) * 100) / 100;
  if (!(price > 0) || price > 1_000_000) throw new HttpError(400, 'bad_price');
  let mrp = b.mrp === null || b.mrp === '' || b.mrp === undefined ? null : Math.round(Number(b.mrp) * 100) / 100;
  if (mrp !== null && !(mrp > 0)) throw new HttpError(400, 'bad_mrp');
  if (kind === 'packed' && mrp === null) throw new HttpError(400, 'mrp_required');
  // Legal Metrology: a packed item can't be sold above the MRP printed on it.
  if (mrp !== null && price > mrp) throw new HttpError(400, 'price_above_mrp');
  const gst = b.gst === undefined || b.gst === null || b.gst === '' ? cat[1] : Number(b.gst);
  if (!GST_RATES.includes(gst)) throw new HttpError(400, 'bad_gst');
  const hsn = str('hsn', 8).replace(/\D/g, '') || cat[0];
  const barcode = kind === 'packed' ? str('barcode', 20).replace(/\D/g, '') || null : null;
  let unit = null, options = null, size = str('size', 30);
  if (kind === 'loose') {
    unit = UNITS[b.unit] ? b.unit : null;
    if (!unit) throw new HttpError(400, 'bad_unit');
    options = (Array.isArray(b.options) ? b.options : []).map(Number).filter((x) => UNITS[unit].includes(x));
    options = [...new Set(options)].sort((x, y) => x - y);
    if (!options.length) throw new HttpError(400, 'pick_sizes');
    size = '';
  } else if (!size) throw new HttpError(400, 'size_required');
  let stock = b.stock === null || b.stock === undefined || b.stock === '' ? null : Math.floor(Number(b.stock));
  if (stock !== null && !(stock >= 0 && stock <= 100000)) throw new HttpError(400, 'bad_stock');
  const inStock = stock === null ? b.inStock !== false : stock > 0;
  // Thela produce from the app's photo list (aloo, pyaz…): the key picks the photo, also in the customer app.
  const produceKey = String(b.produceKey || '').trim();
  if (produceKey && !/^[a-z0-9_]{2,40}$/.test(produceKey)) throw new HttpError(400, 'bad_produce');
  if (produceKey && !['Vegetables', 'Fruits'].includes(category)) throw new HttpError(400, 'bad_category');
  return { kind, name, brand: str('brand', 60), size, unit, options: options ? JSON.stringify(options) : null, barcode, category,
    mrp, price, gst, hsn, stock, in_stock: inStock ? 1 : 0, produce_key: produceKey || null };
}

export function productOut(p) {
  return { id: p.id, kind: p.kind, name: p.name, brand: p.brand || '', size: p.size || '', unit: p.unit, options: p.options ? JSON.parse(p.options) : [],
    barcode: p.barcode || '', produceKey: p.produce_key || '', category: p.category, mrp: p.mrp, price: p.price, gst: p.gst, hsn: p.hsn || '', stock: p.stock,
    inStock: !!p.in_stock, photo: p.photo ? `/v1/products/${p.id}/photo?v=${p.updated_at}` : null, photoCredit: p.photo_credit || '',
    updatedAt: p.updated_at };
}

// Open Food Facts category tags → our categories.
const OFF_MAP = [
  [/biscuit|cookie|cracker|rusk|cake|bread/, 'Bakery & biscuits'], [/chip|crisp|namkeen|snack|bhujia/, 'Chips & Namkeen'],
  [/chocolate|candy|confection|sweet/, 'Sweets & Chocolates'], [/noodle|pasta|instant|ready-meal|soup/, 'Instant Food'],
  [/tea|coffee|malt|health-drink/, 'Tea, Coffee & Milk Drinks'], [/beverage|juice|soda|soft-drink|water/, 'Drinks & Juices'],
  [/sauce|ketchup|jam|spread|honey|pickle/, 'Sauces & Spreads'], [/oil|ghee|spice|masala|condiment/, 'Oil, ghee & masala'],
  [/flour|atta|rice|dal|lentil|pulse|cereal-grain|sugar|salt/, 'Atta, rice & dal'], [/milk|dairy|cheese|butter|paneer|yogurt|curd|egg/, 'Dairy, bread & eggs'],
  [/nut|dried-fruit|breakfast-cereal|oat|muesli/, 'Dry fruits & cereals'], [/ice-cream|frozen-dessert/, 'Icecreams & more'],
  [/soap|shower|body/, 'Bath & Body'], [/shampoo|hair/, 'Hair'], [/skin|face|cream|lotion/, 'Skin & Face'], [/tooth|oral/, 'Bath & Body'],
  [/detergent|clean|dish/, 'Cleaners & Repellents'], [/baby/, 'Baby Care'],
];

export function guessCategory(tags = []) {
  const s = tags.join(' ').toLowerCase();
  for (const [re, cat] of OFF_MAP) if (re.test(s)) return cat;
  return '';
}

async function lookupOff(code) {
  const ua = { 'user-agent': 'NukadKart/1.0 (https://github.com/aggarwal97kajal-lab/nukad-kart)' };
  const fields = 'product_name,product_name_en,brands,quantity,image_front_url,categories_tags';
  for (const host of ['world.openfoodfacts.org', 'world.openbeautyfacts.org', 'world.openproductsfacts.org']) {
    try {
      const r = await fetch(`https://${host}/api/v2/product/${code}.json?fields=${fields}`, { headers: ua, cf: { cacheTtl: 86400 } });
      if (!r.ok) continue;
      const d = await r.json();
      if (d.status !== 1 || !d.product) continue;
      const p = d.product;
      const name = String(p.product_name_en || p.product_name || '').trim();
      if (!name) continue;
      return { found: true, source: host.split('.')[1], name, brand: String(p.brands || '').split(',')[0].trim(), size: String(p.quantity || '').trim(),
        image: /^https:\/\/images\.open(food|beauty|products)facts\.org\//.test(p.image_front_url || '') ? p.image_front_url : '',
        category: guessCategory(p.categories_tags || []) };
    } catch {}
  }
  return { found: false };
}

async function savePhoto(env, id, bytes) {
  if (!env.FILES) throw new HttpError(503, 'files_off');
  await env.FILES.put(`products/${id}.jpg`, bytes, { httpMetadata: { contentType: 'image/jpeg' } });
}

export async function productRoute(req, env, path, m, ctx) {
  const photo = path.match(/^\/v1\/products\/([\w-]+)\/photo$/);
  if (photo && m === 'GET') {
    const o = env.FILES && (await env.FILES.get(`products/${photo[1]}.jpg`));
    if (!o) throw new HttpError(404, 'no_photo');
    return new Response(o.body, { headers: { 'content-type': 'image/jpeg', 'cache-control': 'public, max-age=604800' } });
  }

  if (!path.startsWith('/v1/partner/products') && !path.startsWith('/v1/partner/barcode/') && path !== '/v1/partner/categories') return null;

  if (path === '/v1/partner/categories' && m === 'GET') {
    return json({ categories: Object.entries(CATEGORIES).map(([name, [hsn, gst, food]]) => ({ name, hsn, gst, food })), gstRates: GST_RATES, units: UNITS });
  }

  const { s } = await ctx(req, env);
  if (!s) throw new HttpError(400, 'register_first');

  if (path === '/v1/partner/products/bulk' && m === 'POST') {
    if (s.kind === 'thela') throw new HttpError(400, 'shops_only');
    return json(await bulkUpsert(env, s, (await body(req)).rows));
  }

  if (path === '/v1/partner/products/confirm-prices' && m === 'POST') {
    // "Same prices as yesterday": nothing changes except the date the thela confirmed today's prices.
    const today = new Date((now() + 5.5 * 3600) * 1000).toISOString().slice(0, 10);
    await env.DB.prepare('UPDATE stores SET prices_confirmed = ? WHERE id = ?').bind(today, s.id).run();
    return json({ pricesConfirmed: today });
  }

  const bc = path.match(/^\/v1\/partner\/barcode\/(\d{6,14})$/);
  if (bc && m === 'GET') {
    const code = bc[1];
    const [mine, cached] = await env.DB.batch([
      env.DB.prepare('SELECT * FROM products WHERE store_id = ? AND barcode = ?').bind(s.id, code),
      env.DB.prepare('SELECT data, fetched_at FROM barcode_cache WHERE code = ?').bind(code),
    ]);
    if (mine.results[0]) return json({ existing: productOut(mine.results[0]) });
    const c = cached.results[0];
    // Found items are kept 30 days; "not found" is retried after a day (Open Food Facts grows every day).
    if (c) {
      const d = JSON.parse(c.data);
      if (now() - c.fetched_at < (d.found ? 30 : 1) * 86400) return json(d);
    }
    const d = await lookupOff(code);
    await env.DB.prepare('INSERT OR REPLACE INTO barcode_cache (code, data, fetched_at) VALUES (?, ?, ?)').bind(code, JSON.stringify(d), now()).run();
    return json(d);
  }

  if (path === '/v1/partner/products' && m === 'GET') {
    const u = new URL(req.url);
    const q = String(u.searchParams.get('q') || '').trim().toLowerCase().slice(0, 40);
    const cat = String(u.searchParams.get('cat') || '');
    const out = u.searchParams.get('filter') === 'out';
    const before = String(u.searchParams.get('before') || '');
    const all = u.searchParams.get('all') === '1'; // thela picker: every item at once (a thela has at most a few hundred)
    const where = ['store_id = ?'], args = [s.id];
    if (q) { where.push("(lower(name) LIKE ? OR lower(brand) LIKE ? OR barcode = ?)"); args.push(`%${q}%`, `%${q}%`, q); }
    if (cat) { where.push('category = ?'); args.push(cat); }
    if (out) where.push('in_stock = 0');
    if (before) { where.push('lower(name) > ?'); args.push(before.toLowerCase()); }
    const [list, counts] = await env.DB.batch([
      env.DB.prepare(`SELECT * FROM products WHERE ${where.join(' AND ')} ORDER BY lower(name) LIMIT ${all ? 1000 : PAGE + 1}`).bind(...args),
      env.DB.prepare(`SELECT category, COUNT(*) AS n, SUM(CASE WHEN in_stock = 0 THEN 1 ELSE 0 END) AS outN FROM products WHERE store_id = ? GROUP BY category`).bind(s.id),
    ]);
    const rows = list.results;
    const more = !all && rows.length > PAGE;
    if (more) rows.pop();
    const total = counts.results.reduce((n, r) => n + r.n, 0);
    const outOfStock = counts.results.reduce((n, r) => n + (r.outN || 0), 0);
    return json({ products: rows.map(productOut), more, total, outOfStock,
      categories: counts.results.map((r) => ({ name: r.category, count: r.n })).sort((a, b) => b.count - a.count) });
  }

  if (path === '/v1/partner/products' && m === 'POST') {
    const b = await body(req);
    const v = cleanProduct(b, s);
    const t = now();
    let id = String(b.id || '');
    if (id) {
      const own = await env.DB.prepare('SELECT id FROM products WHERE id = ? AND store_id = ?').bind(id, s.id).first();
      if (!own) throw new HttpError(404, 'no_product');
    }
    if (v.barcode) {
      const same = await env.DB.prepare('SELECT id FROM products WHERE store_id = ? AND barcode = ? AND id != ?').bind(s.id, v.barcode, id).first();
      if (same) throw new HttpError(409, 'barcode_exists');
    }
    if (v.produce_key) {
      const same = await env.DB.prepare('SELECT id FROM products WHERE store_id = ? AND produce_key = ? AND id != ?').bind(s.id, v.produce_key, id).first();
      if (same) id = same.id; // picking the same item again updates it
    }
    const isNew = !id;
    if (isNew) id = `pr_${crypto.randomUUID().replace(/-/g, '').slice(0, 12)}`;
    // Photo from Open Food Facts: copied once into our storage (with credit), so it never breaks later.
    let photo = null, credit = null;
    const img = String(b.offImage || '');
    if (img && /^https:\/\/images\.open(food|beauty|products)facts\.org\//.test(img) && env.FILES) {
      try {
        const r = await fetch(img, { headers: { 'user-agent': 'NukadKart/1.0' } });
        const buf = new Uint8Array(await r.arrayBuffer());
        if (r.ok && buf.length < 2_000_000 && buf[0] === 0xff && buf[1] === 0xd8) {
          await savePhoto(env, id, buf);
          photo = 'off';
          credit = `Photo: Open ${img.includes('beauty') ? 'Beauty' : img.includes('products') ? 'Products' : 'Food'} Facts (CC BY-SA)`;
        }
      } catch {}
    }
    const cols = { ...v, updated_at: t, ...(photo ? { photo, photo_credit: credit } : {}) };
    const keys = Object.keys(cols);
    if (isNew) {
      await env.DB.prepare(`INSERT INTO products (id, store_id, ${keys.join(', ')}, created_at) VALUES (?, ?, ${keys.map(() => '?').join(', ')}, ?)`)
        .bind(id, s.id, ...keys.map((k) => cols[k]), t).run();
    } else {
      await env.DB.prepare(`UPDATE products SET ${keys.map((k) => `${k} = ?`).join(', ')} WHERE id = ? AND store_id = ?`)
        .bind(...keys.map((k) => cols[k]), id, s.id).run();
    }
    const p = await env.DB.prepare('SELECT * FROM products WHERE id = ?').bind(id).first();
    return json({ product: productOut(p) });
  }

  const one = path.match(/^\/v1\/partner\/products\/(pr_\w+)(\/stock|\/photo)?$/);
  if (one) {
    const id = one[1];
    if (one[2] === '/stock' && m === 'PATCH') {
      const b = await body(req);
      const stock = b.stock === null || b.stock === undefined ? null : Math.max(0, Math.min(100000, Math.floor(Number(b.stock))));
      const inStock = stock === null ? b.inStock !== false : stock > 0;
      const [, r] = await env.DB.batch([
        env.DB.prepare('UPDATE products SET stock = ?, in_stock = ?, updated_at = ? WHERE id = ? AND store_id = ?').bind(stock, inStock ? 1 : 0, now(), id, s.id),
        env.DB.prepare('SELECT * FROM products WHERE id = ? AND store_id = ?').bind(id, s.id),
      ]);
      if (!r.results[0]) throw new HttpError(404, 'no_product');
      return json({ product: productOut(r.results[0]) });
    }
    if (one[2] === '/photo' && m === 'PUT') {
      const own = await env.DB.prepare('SELECT id FROM products WHERE id = ? AND store_id = ?').bind(id, s.id).first();
      if (!own) throw new HttpError(404, 'no_product');
      const buf = new Uint8Array(await req.arrayBuffer());
      if (!buf.length || buf.length > 1_500_000) throw new HttpError(413, 'photo_too_big');
      if (!(buf[0] === 0xff && buf[1] === 0xd8)) throw new HttpError(400, 'photo_must_be_jpeg');
      await savePhoto(env, id, buf);
      await env.DB.prepare("UPDATE products SET photo = 'own', photo_credit = NULL, updated_at = ? WHERE id = ?").bind(now(), id).run();
      const p = await env.DB.prepare('SELECT * FROM products WHERE id = ?').bind(id).first();
      return json({ product: productOut(p) });
    }
    if (!one[2] && m === 'DELETE') {
      await env.DB.prepare('DELETE FROM products WHERE id = ? AND store_id = ?').bind(id, s.id).run();
      if (env.FILES) await env.FILES.delete(`products/${id}.jpg`);
      return json({ ok: true });
    }
  }
  throw new HttpError(404, 'not_found');
}

/**
 * Excel upload: add or update many products at once. A row matches an existing product by barcode,
 * else by name + size (loose: name + unit). Bad rows are skipped and reported with their row number.
 */
export async function bulkUpsert(env, s, rows) {
  if (!Array.isArray(rows) || !rows.length) throw new HttpError(400, 'no_rows');
  if (rows.length > 2000) throw new HttpError(400, 'too_many_rows');
  const { results: existing } = await env.DB.prepare('SELECT id, barcode, name, size, unit, kind FROM products WHERE store_id = ?').bind(s.id).all();
  const byCode = new Map(existing.filter((p) => p.barcode).map((p) => [p.barcode, p.id]));
  const key = (name, size, unit, kind) => `${kind}|${String(name).trim().toLowerCase()}|${kind === 'loose' ? unit : String(size || '').trim().toLowerCase()}`;
  const byName = new Map(existing.map((p) => [key(p.name, p.size, p.unit, p.kind), p.id]));
  const t = now();
  const stmts = [], errors = [];
  let added = 0, updated = 0;
  rows.forEach((r, i) => {
    const row = Number(r?.row) || i + 2; // Excel row number (row 1 = headings)
    let v;
    try {
      v = cleanProduct(r || {}, s);
    } catch (e) {
      errors.push({ row, error: e.code || 'bad_row' });
      return;
    }
    if (v.produce_key) v.produce_key = null;
    const k = key(v.name, v.size, v.unit, v.kind);
    let id = (v.barcode && byCode.get(v.barcode)) || byName.get(k);
    const cols = { ...v, updated_at: t };
    const keys = Object.keys(cols);
    if (id) {
      updated++;
      stmts.push(env.DB.prepare(`UPDATE products SET ${keys.map((c) => `${c} = ?`).join(', ')} WHERE id = ? AND store_id = ?`).bind(...keys.map((c) => cols[c]), id, s.id));
    } else {
      added++;
      id = `pr_${crypto.randomUUID().replace(/-/g, '').slice(0, 12)}`;
      if (v.barcode) byCode.set(v.barcode, id);
      byName.set(k, id);
      stmts.push(env.DB.prepare(`INSERT INTO products (id, store_id, ${keys.join(', ')}, created_at) VALUES (?, ?, ${keys.map(() => '?').join(', ')}, ?)`)
        .bind(id, s.id, ...keys.map((c) => cols[c]), t));
    }
  });
  for (let i = 0; i < stmts.length; i += 50) await env.DB.batch(stmts.slice(i, i + 50));
  return { added, updated, errors: errors.slice(0, 200), errorCount: errors.length };
}
