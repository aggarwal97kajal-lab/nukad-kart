-- Rate limit counters for login / phone-check routes (per IP, per phone), one row per key per window.
CREATE TABLE IF NOT EXISTS auth_hits (
  k TEXT PRIMARY KEY,
  win INTEGER NOT NULL,
  n INTEGER NOT NULL DEFAULT 0,
  at INTEGER NOT NULL DEFAULT 0
);
