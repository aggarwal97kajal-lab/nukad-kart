// Seller reminders and the Sunday report.
//   GET /v1/partner/report        (shop / thela) last 7 days: views, calls, chats, orders, new customers, busiest streets
// Cron (every 5 min): pass ends tomorrow (7–10 pm IST) and pass ends today (9 am – 12 pm IST) pushes,
// and the Sunday report push (Sunday from 9 am IST), each once.
import { HttpError, json, now } from './index.js';
import { ctx, istDate } from './partner.js';
import { sendPush } from './push.js';

const IST = 5.5 * 3600;
const istHour = (t) => new Date((t + IST) * 1000).getUTCHours();
const istDay = (t) => new Date((t + IST) * 1000).getUTCDay(); // 0 = Sunday

/** One more person opened this shop's / thela's page today. */
export async function countView(env, storeId) {
  await env.DB.prepare('INSERT INTO store_views (store_id, day, n) VALUES (?, ?, 1) ON CONFLICT (store_id, day) DO UPDATE SET n = n + 1')
    .bind(storeId, istDate()).run();
}

/** "Pass khatam" a day before (evening) and on the last day (morning). Each once per pass end. */
export async function passReminders(env, t = now()) {
  const h = istHour(t);
  let sent = 0;
  if (h >= 19 && h < 22) {
    const { results } = await env.DB.prepare(`SELECT id, owner_id, pass_until, trial_until FROM stores WHERE status = 'active' AND owner_id IS NOT NULL
      AND pass_until > ? AND pass_until <= ? AND (pass_warn1 IS NULL OR pass_warn1 != pass_until) LIMIT 200`).bind(t + 6 * 3600, t + 30 * 3600).all();
    for (const s of results) {
      await env.DB.prepare('UPDATE stores SET pass_warn1 = ? WHERE id = ?').bind(s.pass_until, s.id).run();
      const trial = s.trial_until && s.trial_until >= s.pass_until;
      await sendPush(env, s.owner_id, {
        title: trial ? '⏰ Free trial kal khatam ho raha hai' : '⏰ Aapka pass kal khatam ho raha hai',
        body: 'Pass khatam hote hi customers ko aap nahi dikhoge. Abhi pass lo aur LIVE rahiye.',
        data: { type: 'pass' },
      }).catch(() => {});
      sent++;
    }
  }
  if (h >= 9 && h < 12) {
    const { results } = await env.DB.prepare(`SELECT id, owner_id, pass_until FROM stores WHERE status = 'active' AND owner_id IS NOT NULL
      AND pass_until > ? AND pass_until <= ? AND (pass_warn2 IS NULL OR pass_warn2 != pass_until) LIMIT 200`).bind(t, t + 16 * 3600).all();
    for (const s of results) {
      await env.DB.prepare('UPDATE stores SET pass_warn2 = ?, pass_warn1 = ? WHERE id = ?').bind(s.pass_until, s.pass_until, s.id).run();
      await sendPush(env, s.owner_id, {
        title: '⏰ Aaj pass ka aakhri din hai',
        body: 'Aaj raat ke baad customers ko aap nahi dikhoge. UPI se pass badhaiye.',
        data: { type: 'pass' },
      }).catch(() => {});
      sent++;
    }
  }
  return sent;
}

/** The last 7 days for one shop / thela. */
export async function weekReport(env, s, t = now()) {
  const from = t - 7 * 86400;
  const fromDay = istDate(from + 86400);
  const [v, calls, chats, orders, newc, streets] = await env.DB.batch([
    env.DB.prepare('SELECT COALESCE(SUM(n), 0) AS n FROM store_views WHERE store_id = ? AND day >= ?').bind(s.id, fromDay),
    env.DB.prepare(`SELECT COUNT(*) AS n, SUM(CASE WHEN status IN ('coming','done') OR out_at IS NOT NULL THEN 1 ELSE 0 END) AS went
      FROM calls WHERE thela_id = ? AND created_at > ?`).bind(s.id, from),
    env.DB.prepare('SELECT COUNT(*) AS n FROM chats WHERE thela_id = ? AND created_at > ?').bind(s.id, from),
    env.DB.prepare("SELECT COUNT(*) AS n, COALESCE(SUM(total), 0) AS amount FROM orders WHERE store_id = ? AND status = 'delivered' AND created_at > ?").bind(s.id, from),
    // Customers who reached this seller this week through the app and never before.
    env.DB.prepare(`SELECT COUNT(*) AS n FROM (
        SELECT customer_id FROM calls WHERE thela_id = ?1 AND created_at > ?2
        UNION SELECT customer_id FROM chats WHERE thela_id = ?1 AND created_at > ?2
        UNION SELECT customer_id FROM orders WHERE store_id = ?1 AND created_at > ?2
      ) w WHERE w.customer_id NOT IN (
        SELECT customer_id FROM calls WHERE thela_id = ?1 AND created_at <= ?2
        UNION SELECT customer_id FROM chats WHERE thela_id = ?1 AND created_at <= ?2
        UNION SELECT customer_id FROM orders WHERE store_id = ?1 AND created_at <= ?2)`).bind(s.id, from),
    env.DB.prepare(`SELECT address, COUNT(*) AS n FROM calls WHERE thela_id = ? AND created_at > ? GROUP BY address ORDER BY n DESC LIMIT 3`).bind(s.id, from),
  ]);
  const one = (r) => r.results[0] || {};
  return {
    from: istDate(from + 86400), to: istDate(t), kind: s.kind, name: s.name,
    views: one(v).n || 0,
    calls: one(calls).n || 0, went: one(calls).went || 0,
    chats: one(chats).n || 0,
    orders: one(orders).n || 0, sales: one(orders).amount || 0,
    newCustomers: one(newc).n || 0,
    streets: streets.results.map((r) => ({ address: r.address, count: r.n })),
  };
}

/** Sunday from 9 am IST: each live seller gets their week, once. */
export async function sundayReports(env, t = now()) {
  if (istDay(t) !== 0 || istHour(t) < 9) return 0;
  const week = istDate(t);
  const { results } = await env.DB.prepare(`SELECT * FROM stores WHERE status = 'active' AND owner_id IS NOT NULL AND demo = 0
    AND (report_week IS NULL OR report_week != ?) LIMIT 100`).bind(week).all();
  for (const s of results) {
    await env.DB.prepare('UPDATE stores SET report_week = ? WHERE id = ?').bind(week, s.id).run();
    const r = await weekReport(env, s, t);
    const what = s.kind === 'thela'
      ? `${r.calls} bulawe · ${r.chats} chat · ${r.newCustomers} naye grahak`
      : `${r.orders} order · ₹${r.sales} · ${r.newCustomers} naye grahak`;
    await sendPush(env, s.owner_id, {
      title: `📊 Aapka hafta: ${r.views} baar aapko dekha gaya`,
      body: `${what}. Poori report dekhiye.`,
      data: { type: 'report' },
    }).catch(() => {});
  }
  return results.length;
}

export async function reportRoute(req, env, path, m) {
  if (path === '/v1/partner/report' && m === 'GET') {
    const { s } = await ctx(req, env);
    if (!s) throw new HttpError(400, 'register_first');
    return json({ report: await weekReport(env, s) });
  }
  return null;
}
