// Early access list from the website (nukkadkart.in).
//   OPTIONS/POST /v1/waitlist  { name, email, phone, pincode, city, state, consent: true, company: '' }
// Every sign-up is saved in D1 first, so none is lost if Brevo is down or not set up yet.
// A copy goes to Brevo (contact list for launch emails) and one confirmation email is sent.
// Brevo failures are retried by the 5-minute cron.
import { HttpError, json, now } from './index.js';
import { rateLimit, clientIp, cleanText } from './guard.js';

const ORIGINS = ['https://nukkadkart.in', 'https://www.nukkadkart.in'];
const BREVO = 'https://api.brevo.com/v3';
const LIST_NAME = 'Nukkad Kart early access';
const ATTRS = ['PHONE', 'PINCODE', 'CITY', 'STATE'];
const MAX_TRIES = 288; // about a day of 5-minute retries

export const STATES = ['Andaman and Nicobar Islands', 'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chandigarh', 'Chhattisgarh',
  'Dadra and Nagar Haveli and Daman and Diu', 'Delhi', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jammu and Kashmir', 'Jharkhand',
  'Karnataka', 'Kerala', 'Ladakh', 'Lakshadweep', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha',
  'Puducherry', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal'];

function cors(req) {
  const o = req.headers.get('origin') || '';
  return ORIGINS.includes(o)
    ? { 'access-control-allow-origin': o, 'access-control-allow-methods': 'POST, OPTIONS', 'access-control-allow-headers': 'content-type',
      'access-control-max-age': '86400', vary: 'origin' }
    : { vary: 'origin' };
}

function withCors(res, req) {
  const h = new Headers(res.headers);
  for (const [k, v] of Object.entries(cors(req))) h.set(k, v);
  return new Response(res.body, { status: res.status, headers: h });
}

/** Checks one sign-up. Any bad field → 400 with the field name, so the form can point at it. */
export function checkSignup(b) {
  if (!b || typeof b !== 'object' || Array.isArray(b)) throw new HttpError(400, 'bad_request');
  const out = {
    name: cleanText(b.name, 80).replace(/\s+/g, ' '),
    email: String(b.email ?? '').trim().toLowerCase().slice(0, 120),
    phone: String(b.phone ?? '').replace(/\D/g, '').replace(/^(91|0)(?=[6-9]\d{9}$)/, ''),
    pincode: String(b.pincode ?? '').replace(/\D/g, ''),
    city: cleanText(b.city, 60).replace(/\s+/g, ' '),
    state: String(b.state ?? '').trim(),
  };
  const bad = (f) => { throw new HttpError(400, 'bad_field', f); };
  if (out.name.length < 2) bad('name');
  if (!/^[^@\s<>()",;:]+@[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}$/.test(out.email)) bad('email');
  if (!/^[6-9]\d{9}$/.test(out.phone)) bad('phone');
  if (!/^[1-9]\d{5}$/.test(out.pincode)) bad('pincode');
  if (out.city.length < 2) bad('city');
  if (!STATES.includes(out.state)) bad('state');
  if (b.consent !== true) bad('consent');
  return out;
}

export async function waitlistRoute(req, env, path, m, ectx) {
  if (path !== '/v1/waitlist') return null;
  if (m === 'OPTIONS') return new Response(null, { status: 204, headers: cors(req) });
  try {
    if (m !== 'POST') throw new HttpError(405, 'method_not_allowed');
    const o = req.headers.get('origin');
    if (o && !ORIGINS.includes(o)) throw new HttpError(403, 'bad_origin');
    await rateLimit(env, `wait:${clientIp(req)}`, 20, 600);
    let b;
    try { b = await req.json(); } catch { throw new HttpError(400, 'bad_json'); }
    // Hidden field only bots fill in: answer "ok" and keep nothing.
    if (b && typeof b === 'object' && b.company) return withCors(json({ ok: true }), req);
    const s = checkSignup(b);
    const t = now();
    await env.DB.prepare(
      `INSERT INTO waitlist (email, name, phone, pincode, city, state, consent_at, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(email) DO UPDATE SET name = excluded.name, phone = excluded.phone, pincode = excluded.pincode, city = excluded.city,
         state = excluded.state, consent_at = excluded.consent_at, updated_at = excluded.updated_at, brevo_synced = 0, brevo_tries = 0`,
    ).bind(s.email, s.name, s.phone, s.pincode, s.city, s.state, t, t, t).run();
    if (env.BREVO_API_KEY && ectx?.waitUntil) ectx.waitUntil(syncOne(env, s.email).catch((e) => console.error('brevo', e.message)));
    // Same answer for a new or an existing email: the page does not reveal who is on the list.
    return withCors(json({ ok: true }), req);
  } catch (e) {
    if (e instanceof HttpError) return withCors(json({ error: e.code, field: e.code === 'bad_field' ? e.message : undefined }, e.status), req);
    console.error(e);
    return withCors(json({ error: 'server_error' }, 500), req);
  }
}

// ---------- Brevo ----------
async function brevo(env, method, path, body) {
  const r = await fetch(BREVO + path, {
    method,
    headers: { 'api-key': env.BREVO_API_KEY, accept: 'application/json', 'content-type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await r.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = { raw: text.slice(0, 200) }; }
  return { ok: r.ok, status: r.status, data };
}

/** Creates the contact attributes and the list once; remembers the list id in settings. */
export async function brevoListId(env) {
  const row = await env.DB.prepare("SELECT value FROM settings WHERE key = 'brevo_list_id'").first();
  if (row?.value) return Number(row.value);
  for (const a of ATTRS) {
    const r = await brevo(env, 'POST', `/contacts/attributes/normal/${a}`, { type: 'text' });
    // 400 here means it already exists.
    if (!r.ok && r.status !== 400) throw new Error(`attribute ${a}: ${r.status} ${JSON.stringify(r.data)}`);
  }
  const lists = await brevo(env, 'GET', '/contacts/lists?limit=50&offset=0');
  if (!lists.ok) throw new Error(`lists: ${lists.status} ${JSON.stringify(lists.data)}`);
  let id = (lists.data?.lists || []).find((l) => l.name === LIST_NAME)?.id;
  if (!id) {
    const folders = await brevo(env, 'GET', '/contacts/folders?limit=10&offset=0');
    let folderId = folders.data?.folders?.[0]?.id;
    if (!folderId) {
      const f = await brevo(env, 'POST', '/contacts/folders', { name: 'Nukkad Kart' });
      folderId = f.data?.id;
    }
    const c = await brevo(env, 'POST', '/contacts/lists', { name: LIST_NAME, folderId });
    if (!c.ok) throw new Error(`create list: ${c.status} ${JSON.stringify(c.data)}`);
    id = c.data.id;
  }
  await env.DB.prepare("INSERT INTO settings (key, value) VALUES ('brevo_list_id', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value")
    .bind(String(id)).run();
  return id;
}

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

export function confirmEmail(row) {
  const first = row.name.split(' ')[0];
  const text = `Hi ${first},\n\nYou're on the Nukkad Kart early access list for ${row.city} (${row.pincode}).\n\n`
    + `We will email you once, on the day the app opens in your area. Nothing before that.\n\n`
    + `Did not sign up, or want to be removed? Reply to this email and we will delete your details.\n\n— Nukkad Kart\nhttps://nukkadkart.in`;
  const html = `<!doctype html><html><body style="margin:0;background:#f6f3ea;font-family:Arial,Helvetica,sans-serif;color:#0d1f14">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:32px 16px">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#ffffff;border-radius:16px">
<tr><td style="padding:28px 28px 8px;font-size:22px;font-weight:bold;color:#023717">Nukkad <span style="color:#248A09">Kart</span></td></tr>
<tr><td style="padding:8px 28px 0;font-size:16px;line-height:1.6">
<p>Hi ${esc(first)},</p>
<p>You're on the early access list for <b>${esc(row.city)}</b> (${esc(row.pincode)}).</p>
<p>We will email you once, on the day the app opens in your area. Nothing before that.</p>
</td></tr>
<tr><td style="padding:8px 28px 28px;font-size:13px;line-height:1.6;color:#5b6b60">
Did not sign up, or want to be removed? Reply to this email and we will delete your details.<br>
<a href="https://nukkadkart.in" style="color:#248A09">nukkadkart.in</a></td></tr>
</table></td></tr></table></body></html>`;
  return { subject: `You're on the list, ${first}`, text, html };
}

/** Sends one row to Brevo (contact + list), then the confirmation email once. */
export async function syncOne(env, email) {
  if (!env.BREVO_API_KEY) return;
  const row = await env.DB.prepare('SELECT * FROM waitlist WHERE email = ?').bind(email).first();
  if (!row) return;
  try {
    if (!row.brevo_synced) {
      const listId = await brevoListId(env);
      const [first, ...rest] = row.name.split(' ');
      const r = await brevo(env, 'POST', '/contacts', {
        email: row.email, updateEnabled: true, listIds: [listId],
        attributes: { FIRSTNAME: first, LASTNAME: rest.join(' '), PHONE: '+91' + row.phone, PINCODE: row.pincode, CITY: row.city, STATE: row.state },
      });
      if (!r.ok) throw new Error(`contact: ${r.status} ${JSON.stringify(r.data)}`);
      await env.DB.prepare('UPDATE waitlist SET brevo_synced = 1 WHERE email = ?').bind(email).run();
    }
    if (!row.confirm_sent) {
      const m = confirmEmail(row);
      const r = await brevo(env, 'POST', '/smtp/email', {
        sender: { name: 'Nukkad Kart', email: env.BREVO_SENDER || 'support@nukkadkart.in' },
        replyTo: { email: env.BREVO_SENDER || 'support@nukkadkart.in', name: 'Nukkad Kart' },
        to: [{ email: row.email, name: row.name }], subject: m.subject, htmlContent: m.html, textContent: m.text, tags: ['waitlist-confirm'],
      });
      if (!r.ok) throw new Error(`email: ${r.status} ${JSON.stringify(r.data)}`);
      await env.DB.prepare('UPDATE waitlist SET confirm_sent = 1 WHERE email = ?').bind(email).run();
    }
  } catch (e) {
    await env.DB.prepare('UPDATE waitlist SET brevo_tries = brevo_tries + 1 WHERE email = ?').bind(email).run();
    throw e;
  }
}

/** Cron: retry rows Brevo has not taken yet (Brevo down, key added later, sender not verified yet). */
export async function syncWaitlist(env) {
  if (!env.BREVO_API_KEY) return;
  await keepKeyAlive(env);
  const { results } = await env.DB.prepare(
    `SELECT email FROM waitlist WHERE (brevo_synced = 0 OR confirm_sent = 0) AND brevo_tries < ? ORDER BY created_at LIMIT 20`,
  ).bind(MAX_TRIES).all();
  for (const r of results) {
    try { await syncOne(env, r.email); } catch (e) { console.error('brevo_retry', e.message); }
  }
}

/** Brevo switches off an API key after 90 days without use. One small read a day keeps it alive before launch. */
async function keepKeyAlive(env) {
  const day = Math.floor(now() / 86400);
  const row = await env.DB.prepare("SELECT value FROM settings WHERE key = 'brevo_ping_day'").first();
  if (row && Number(row.value) === day) return;
  const r = await brevo(env, 'GET', '/contacts/lists?limit=1&offset=0');
  if (!r.ok) { console.error('brevo_ping', r.status, JSON.stringify(r.data)); return; }
  await env.DB.prepare("INSERT INTO settings (key, value) VALUES ('brevo_ping_day', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value")
    .bind(String(day)).run();
}
