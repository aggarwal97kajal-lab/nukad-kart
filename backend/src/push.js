// Push notifications through Firebase Cloud Messaging (HTTP v1).
// Needs the secret FCM_SERVICE_ACCOUNT (the service-account JSON from Firebase). Without it, pushes are skipped.
import { b64url } from './index.js';

let cached = { token: '', exp: 0 };

function pemToDer(pem) {
  const b64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

async function accessToken(sa) {
  const t = Math.floor(Date.now() / 1000);
  if (cached.token && cached.exp > t + 60) return cached.token;
  const enc = (o) => b64url(new TextEncoder().encode(JSON.stringify(o)));
  const unsigned = `${enc({ alg: 'RS256', typ: 'JWT' })}.${enc({
    iss: sa.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token', iat: t, exp: t + 3600,
  })}`;
  const key = await crypto.subtle.importKey('pkcs8', pemToDer(sa.private_key), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${unsigned}.${b64url(sig)}`,
  });
  const d = await res.json();
  if (!d.access_token) throw new Error('fcm auth failed');
  cached = { token: d.access_token, exp: t + (d.expires_in || 3600) };
  return cached.token;
}

export const pushReady = (env) => !!env.FCM_SERVICE_ACCOUNT;

/** Send to every phone of this user. Never throws: a failed push must not break the request. */
export async function sendPush(env, userId, { title, body, data = {}, channel = 'updates' }) {
  if (!env.FCM_SERVICE_ACCOUNT || !userId) return 0;
  try {
    const sa = JSON.parse(env.FCM_SERVICE_ACCOUNT);
    const { results } = await env.DB.prepare('SELECT token FROM push_tokens WHERE user_id = ?').bind(userId).all();
    if (!results.length) return 0;
    const at = await accessToken(sa);
    let sent = 0;
    for (const { token } of results) {
      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
        method: 'POST',
        headers: { authorization: `Bearer ${at}`, 'content-type': 'application/json' },
        body: JSON.stringify({ message: {
          token, notification: { title, body },
          data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
          android: { priority: 'high', notification: { channel_id: channel } },
        } }),
      });
      if (res.ok) sent++;
      else if (res.status === 404 || res.status === 400) {
        // App uninstalled or token changed: forget it.
        await env.DB.prepare('DELETE FROM push_tokens WHERE token = ?').bind(token).run();
      }
    }
    return sent;
  } catch {
    return 0;
  }
}
