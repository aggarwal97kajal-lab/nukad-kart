/** Same phone logging in again: its old sessions are replaced, not listed twice.
 * Ids starting "a-" / "pa-" are the phone's Android ID (same after a reinstall).
 * Older sessions carry a per-install random id (or none): when this login has an Android ID,
 * those are matched by phone model + Android version instead. */
export function samePhoneOut(env, t, userId, devId, devName, devPlatform) {
  const stable = /^p?a-/.test(devId);
  return env.DB.prepare(
    `UPDATE sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL
     AND (device_id = ? OR (device = ? AND platform = ? AND (device_id IS NULL OR (? = 1
       AND device_id NOT LIKE 'a-%' AND device_id NOT LIKE 'pa-%'))))`,
  ).bind(t, userId, devId, devName, devPlatform, stable ? 1 : 0);
}
