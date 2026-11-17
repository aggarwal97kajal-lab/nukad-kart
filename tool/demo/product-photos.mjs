// Demo only: product photos from Open Food Facts (CC BY-SA), the same source the Partner app's barcode scan uses.
// Reads products.json from seed.mjs; writes jpgs, photos-sql.sql and r2.txt ("key file") into the same folder.
import fs from 'node:fs';
import path from 'node:path';
const dir = process.argv[2] || 'demo-out';
const items = JSON.parse(fs.readFileSync(path.join(dir, 'products.json'), 'utf8')).filter((p) => p.kind === 'packed');
const names = [...new Set(items.map((p) => p.name))];
fs.mkdirSync(path.join(dir, 'pp'), { recursive: true });
const ua = { 'user-agent': 'NukkadKart-demo/1.0 (support@nukkadkart.in)' };
const sql = [], r2 = [], log = [];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const norm = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
for (const name of names) {
  const p = items.find((x) => x.name === name);
  const q = encodeURIComponent(`${name}`);
  let pick = null;
  try {
    // The search API allows about 10 calls a minute and answers an HTML page when over it: pace and retry.
    let d = null;
    for (let tryN = 0; tryN < 4 && !d; tryN++) {
      await sleep(tryN ? 30000 : 7000);
      const r = await fetch(`https://world.openfoodfacts.org/cgi/search.pl?search_terms=${q}&search_simple=1&json=1&page_size=24&fields=code,product_name,brands,image_front_url,countries_tags`, { headers: ua });
      const txt = await r.text();
      try { d = JSON.parse(txt); } catch { log.push(`${name}: busy (${r.status}), retrying`); }
    }
    if (!d) throw new Error('search kept failing');
    const brand = norm(p.brand.split(' ')[0] || name.split(' ')[0]);
    const cands = (d.products || []).filter((x) => x.image_front_url && norm(`${x.brands || ''} ${x.product_name || ''}`).includes(brand));
    cands.sort((a, b) => (b.countries_tags || []).includes('en:india') - (a.countries_tags || []).includes('en:india'));
    pick = cands[0] || null;
  } catch (e) { log.push(`${name}: search failed ${e.message}`); }
  if (!pick) { log.push(`${name}: no photo`); continue; }
  const url = pick.image_front_url.replace(/\.(\d+|full)\.jpg$/, '.400.jpg');
  let img = null;
  for (let tryN = 0; tryN < 3 && !img; tryN++) {
    try { img = new Uint8Array(await (await fetch(url, { headers: ua, signal: AbortSignal.timeout(30000) })).arrayBuffer()); }
    catch (e) { log.push(`${name}: image fetch failed ${e.message}`); await sleep(5000); }
  }
  if (!img || img[0] !== 0xff || img[1] !== 0xd8) { log.push(`${name}: not a jpeg`); continue; }
  const file = path.join(dir, 'pp', norm(name).replace(/ /g, '-') + '.jpg');
  fs.writeFileSync(file, img);
  log.push(`${name}: ${pick.code} ${pick.brands} / ${pick.product_name} ${url}`);
  for (const it of items.filter((x) => x.name === name)) {
    r2.push(`products/${it.id}.jpg ${file}`);
    sql.push(`UPDATE products SET photo = 'off', photo_credit = 'Photo: Open Food Facts (CC BY-SA)' WHERE id = '${it.id}';`);
  }
}
fs.writeFileSync(path.join(dir, 'photos-sql.sql'), sql.join('\n') + '\n');
fs.writeFileSync(path.join(dir, 'r2.txt'), r2.join('\n') + '\n');
fs.writeFileSync(path.join(dir, 'pp', 'choices.txt'), log.join('\n') + '\n');
console.log(log.join('\n'));
