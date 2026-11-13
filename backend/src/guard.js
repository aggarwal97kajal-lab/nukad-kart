// Login and phone-check routes: rate limits and strict input checks.
// No outside library (the Worker has no npm dependencies); the checks are small and explicit.
import { HttpError } from './index.js';

/** Count one hit for `key` in the current window; over `max` → 429 "slow_down". */
export async function rateLimit(env, key, max, windowS) {
  const t = Math.floor(Date.now() / 1000);
  const win = Math.floor(t / windowS);
  const row = await env.DB.prepare(
    `INSERT INTO auth_hits (k, win, n, at) VALUES (?, ?, 1, ?)
     ON CONFLICT(k) DO UPDATE SET n = CASE WHEN win = excluded.win THEN n + 1 ELSE 1 END, win = excluded.win, at = excluded.at
     RETURNING n`,
  ).bind(key, win, t).first();
  if ((row?.n || 0) > max) {
    console.warn('rate_limited', key.split(':')[0]);
    throw new HttpError(429, 'slow_down');
  }
}

export const clientIp = (req) => req.headers.get('cf-connecting-ip') || 'unknown';

/** Plain text only: no tags, no control characters, trimmed and cut to `max`. */
export function cleanText(v, max) {
  return String(v ?? '')
    .replace(/<[^>]*>/g, '')
    .replace(/[\u0000-\u001f\u007f<>]/g, '')
    .trim()
    .slice(0, max);
}

/** Field checks for login bodies. Any failure → one generic 400, the field is logged on the server only. */
const RULES = {
  idToken: (v) => typeof v === 'string' && v.length >= 100 && v.length <= 4096 && /^[\w-]+\.[\w-]+\.[\w-]+$/.test(v),
  accessToken: (v) => typeof v === 'string' && v.length >= 10 && v.length <= 2048 && /^[\w.\-=+/]+$/.test(v),
  phone: (v) => /^[6-9]\d{9}$/.test(String(v ?? '').replace(/\D/g, '').slice(-10)),
  app: (v) => v === undefined || v === 'customer' || v === 'partner',
  device: (v) => v === undefined || v === null || (typeof v === 'object' && !Array.isArray(v)),
};

export function checkFields(route, b, fields) {
  if (!b || typeof b !== 'object' || Array.isArray(b)) {
    console.warn('bad_input', route, 'body');
    throw new HttpError(400, 'bad_request');
  }
  for (const f of fields) {
    if (!RULES[f](b[f])) {
      console.warn('bad_input', route, f);
      throw new HttpError(400, 'bad_request');
    }
  }
}

/** Device info shown under Logged-in devices: plain text, short. */
export function cleanDevice(d) {
  const o = d && typeof d === 'object' ? d : {};
  return {
    name: cleanText(o.name, 60),
    platform: cleanText(o.platform, 40),
    id: String(o.id ?? '').replace(/[^\w-]/g, '').slice(0, 80),
  };
}
