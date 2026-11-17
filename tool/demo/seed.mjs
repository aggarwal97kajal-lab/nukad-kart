// Demo data for the how-to videos: a local copy of the server (wrangler dev --local) with the website's shops and thelas.
// Never touches the real server. Writes seed.sql, tokens.json and photos.txt into the folder given as argv[2].
//   node tool/demo/seed.mjs out/  (SESSION_SECRET must match backend/.dev.vars)
import fs from 'node:fs';
import path from 'node:path';
import { signSession } from '../../backend/src/index.js';

const out = process.argv[2] || 'demo-out';
const SECRET = process.env.SESSION_SECRET || 'demo-only-secret';
fs.mkdirSync(out, { recursive: true });
const t = Math.floor(Date.now() / 1000);
const AGREE = '1.0', CONSENT = 'c-2026-11-14';

// Customer's home: Gali no. 4, Palam, New Delhi.
const HOME = { lat: 28.5895, lng: 77.0884 };
const at = (north, east) => ({ lat: +(HOME.lat + north / 111000).toFixed(6), lng: +(HOME.lng + east / 97500).toFixed(6) });

const q = (v) => (v === null || v === undefined ? 'NULL' : typeof v === 'number' ? String(v) : `'${String(v).replace(/'/g, "''")}'`);
const sql = [];
const insert = (table, row) => sql.push(`INSERT INTO ${table} (${Object.keys(row).join(', ')}) VALUES (${Object.values(row).map(q).join(', ')});`);

// ---------- people ----------
const people = {
  customer: { id: 'u_neha', email: 'neha.demo@nukkadkart.in', name: 'Neha Sharma', app: 'customer', phone: '9810000001' },
  gupta: { id: 'u_gupta', email: 'gupta.demo@nukkadkart.in', name: 'Raj Gupta', app: 'partner', partner_phone: '9810000002' },
  verma: { id: 'u_verma', email: 'verma.demo@nukkadkart.in', name: 'Sunil Verma', app: 'partner', partner_phone: '9810000003' },
  ganesh: { id: 'u_ganesh', email: 'ganesh.demo@nukkadkart.in', name: 'Ganesh Yadav', app: 'partner', partner_phone: '9810000004' },
  ramesh: { id: 'u_ramesh', email: 'ramesh.demo@nukkadkart.in', name: 'Ramesh Kumar', app: 'partner', partner_phone: '9810000005' },
  sita: { id: 'u_sita', email: 'sita.demo@nukkadkart.in', name: 'Sita Devi', app: 'partner', partner_phone: '9810000006' },
};
const tokens = {};
for (const [k, u] of Object.entries(people)) {
  insert('users', { id: u.id, google_sub: 'demo-' + k, email: u.email, name: u.name, phone: u.phone || null, phone_verified: u.phone ? 1 : 0,
    created_at: t - 86400 * 20, updated_at: t, role: 'customer', app: u.app, partner_phone: u.partner_phone || null,
    consent_version: CONSENT, consent_at: t - 86400 * 20 });
  const sid = 'sess_' + k;
  insert('sessions', { id: sid, user_id: u.id, device: 'Demo phone', platform: 'android', created_at: t, last_seen: t });
  tokens[k] = await signSession(u.id, SECRET, 30, sid);
}
insert('addresses', { id: 'a_home', user_id: 'u_neha', label: 'Home', name: 'Neha Sharma', phone: '9810000001', flat: 'House 21',
  floor: '1st floor', area: 'Gali no. 4, Palam', city: 'New Delhi', state: 'Delhi', country: 'India', pin: '110045',
  lat: HOME.lat, lng: HOME.lng, is_default: 1, created_at: t - 86400 * 20 });

// ---------- shops and thelas (photos from the website) ----------
const shops = [
  { id: 's_gupta', owner: 'u_gupta', name: 'Gupta General Store', photo: 'shop-gupta', pos: at(95, 75), door: 1, pickup: 1, area: 'Main Market, Palam' },
  { id: 's_verma', owner: 'u_verma', name: 'Verma Provision Store', photo: 'shop-verma', pos: at(-160, 205), door: 0, pickup: 1, area: 'Palam Gaon' },
  { id: 's_ganesh', owner: 'u_ganesh', name: 'Ganesh Kirana Store', photo: 'shop-ganesh', pos: at(330, -240), door: 1, pickup: 1, area: 'Raj Nagar' },
];
const thelas = [
  { id: 't_ramesh', owner: 'u_ramesh', name: 'Ramesh Sabzi Thela', photo: 'thela-veg', pos: at(140, -110) },
  { id: 't_sita', owner: 'u_sita', name: 'Sita Fruit Thela', photo: 'thela-fruit', pos: at(-230, -180) },
];
const photos = [];
for (const s of shops) {
  insert('stores', { id: s.id, name: s.name, kind: 'shop', lat: s.pos.lat, lng: s.pos.lng, address: `${s.area}, New Delhi 110045`,
    opens_at: '12:00 am', closes_at: '11:59 pm', door_delivery: s.door, active: 1, demo: 0, created_at: t - 86400 * 15, owner_id: s.owner,
    pickup: s.pickup, fssai: '13323999000123', gst_type: 'none', pass_until: t + 86400 * 25, live: 1, status: 'active',
    photo_lat: s.pos.lat, photo_lng: s.pos.lng, photo_at: t - 86400 * 15, agreement_version: AGREE, addr_shop: s.name, addr_area: s.area,
    addr_city: 'New Delhi', addr_state: 'Delhi', addr_pin: '110045', phone_verified: 1, prices_confirmed: null });
  photos.push(`photos/${s.id}.jpg ${s.photo}`);
}
for (const th of thelas) {
  insert('stores', { id: th.id, name: th.name, kind: 'thela', lat: th.pos.lat, lng: th.pos.lng, address: '', opens_at: null, closes_at: null,
    door_delivery: 0, active: 1, demo: 0, created_at: t - 86400 * 10, owner_id: th.owner, pickup: 1, gst_type: 'none',
    pass_until: t + 86400 * 25, live: 1, status: 'active', photo_at: t - 86400 * 10, agreement_version: AGREE, phone_verified: 1,
    live_lat: th.pos.lat, live_lng: th.pos.lng, live_at: t, moved_at: t, heading: 90, prices_confirmed: new Date((t + 19800) * 1000).toISOString().slice(0, 10),
    alert_lat: th.pos.lat, alert_lng: th.pos.lng });
  photos.push(`photos/${th.id}.jpg ${th.photo}`);
}

// ---------- products ----------
let n = 0;
const plist = [];
const product = (store, p) => {
  n++;
  plist.push({ id: `pr_demo${String(n).padStart(3, '0')}`, store, name: p.name, brand: p.brand || '', size: p.size || '', kind: p.kind || 'packed' });
  insert('products', { id: `pr_demo${String(n).padStart(3, '0')}`, store_id: store, kind: p.kind || 'packed', name: p.name, brand: p.brand || '',
    size: p.size || '', unit: p.unit || null, options: p.options ? JSON.stringify(p.options) : null, barcode: null, category: p.cat,
    mrp: p.mrp ?? null, price: p.price, gst: p.gst ?? 5, hsn: null, stock: p.stock ?? null, in_stock: 1, photo: null,
    created_at: t - 86400 * 5, updated_at: t - 3600, produce_key: p.key || null });
};
const kirana = [
  { name: 'Aashirvaad Shudh Chakki Atta', brand: 'Aashirvaad', size: '5 kg', cat: 'Atta, rice & dal', mrp: 295, price: 282, stock: 14 },
  { name: 'Toor Dal', kind: 'loose', unit: 'kg', options: [250, 500, 1000], cat: 'Atta, rice & dal', price: 168 },
  { name: 'India Gate Basmati Rice', brand: 'India Gate', size: '1 kg', cat: 'Atta, rice & dal', mrp: 165, price: 155, stock: 20 },
  { name: 'Amul Taaza Toned Milk', brand: 'Amul', size: '500 ml', cat: 'Dairy, bread & eggs', mrp: 28, price: 28, gst: 0, stock: 40 },
  { name: 'Amul Butter', brand: 'Amul', size: '100 g', cat: 'Dairy, bread & eggs', mrp: 62, price: 60, stock: 18 },
  { name: 'Brown Bread', brand: 'Harvest Gold', size: '400 g', cat: 'Dairy, bread & eggs', mrp: 50, price: 50, gst: 0, stock: 10 },
  { name: 'Tata Salt', brand: 'Tata', size: '1 kg', cat: 'Oil, ghee & masala', mrp: 28, price: 27, stock: 25 },
  { name: 'Fortune Soya Health Oil', brand: 'Fortune', size: '1 L', cat: 'Oil, ghee & masala', mrp: 165, price: 158, stock: 8 },
  { name: 'Parle-G Gold Biscuits', brand: 'Parle', size: '250 g', cat: 'Bakery & biscuits', mrp: 30, price: 28, stock: 60 },
  { name: 'Maggi 2-Minute Noodles', brand: 'Nestlé', size: '70 g', cat: 'Instant Food', mrp: 15, price: 15, stock: 72 },
  { name: 'Lay’s Classic Salted', brand: 'Lay’s', size: '52 g', cat: 'Chips & Namkeen', mrp: 20, price: 20, stock: 30 },
  { name: 'Red Label Tea', brand: 'Brooke Bond', size: '250 g', cat: 'Tea, Coffee & Milk Drinks', mrp: 140, price: 132, stock: 12 },
  { name: 'Surf Excel Easy Wash', brand: 'Surf Excel', size: '1 kg', cat: 'Cleaners & Repellents', mrp: 140, price: 136, stock: 12, gst: 18 },
  { name: 'Dettol Soap', brand: 'Dettol', size: '4 × 75 g', cat: 'Bath & Body', mrp: 180, price: 170, stock: 9, gst: 18 },
];
for (const s of shops) kirana.forEach((p, i) => product(s.id, { ...p, price: s.id === 's_gupta' ? p.price : Math.max(p.price - (i % 3), 1) }));
const veg = [['Aloo (Potato)', 'aloo', 30], ['Pyaz (Onion)', 'pyaz', 40], ['Tamatar (Tomato)', 'tamatar', 36], ['Bhindi (Okra)', 'bhindi', 60],
  ['Gobhi (Cauliflower)', 'phool_gobhi', 50], ['Lauki (Bottle gourd)', 'lauki', 40], ['Hari Mirch (Green chilli)', 'hari_mirch', 80],
  ['Dhaniya (Coriander)', 'dhaniya', 120], ['Nimbu (Lemon)', 'nimbu', 100]];
for (const [name, key, price] of veg) product('t_ramesh', { name, key, price, kind: 'loose', unit: 'kg', options: [250, 500, 1000], cat: 'Vegetables', gst: 0 });
const fruit = [['Kela (Banana)', 'kela', 60, 'dozen', [1, 2]], ['Seb (Apple)', 'seb', 160, 'kg', [500, 1000]], ['Santra (Orange)', 'santra', 90, 'kg', [500, 1000]],
  ['Papita (Papaya)', 'papita', 50, 'kg', [500, 1000]], ['Anaar (Pomegranate)', 'anaar', 180, 'kg', [500, 1000]]];
for (const [name, key, price, unit, options] of fruit) product('t_sita', { name, key, price, kind: 'loose', unit, options, cat: 'Fruits', gst: 0 });

fs.writeFileSync(path.join(out, 'seed.sql'), sql.join('\n') + '\n');
fs.writeFileSync(path.join(out, 'tokens.json'), JSON.stringify({ ...tokens, home: HOME, thelas: Object.fromEntries(thelas.map((x) => [x.id, x.pos])),
  shops: Object.fromEntries(shops.map((x) => [x.id, x.pos])) }, null, 2));
fs.writeFileSync(path.join(out, 'products.json'), JSON.stringify(plist, null, 1));
fs.writeFileSync(path.join(out, 'photos.txt'), photos.join('\n') + '\n');
console.log(`seed: ${sql.length} rows, ${photos.length} photos`);
