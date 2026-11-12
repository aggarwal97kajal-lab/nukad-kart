-- One row per logged-in phone. A session can be logged out from another phone.
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  device TEXT,
  platform TEXT,
  city TEXT,
  created_at INTEGER NOT NULL,
  last_seen INTEGER NOT NULL,
  revoked_at INTEGER
);
CREATE INDEX idx_sessions_user ON sessions(user_id);

-- 'customer' (default) or 'thela'. Thela accounts may be logged in on one phone only.
ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'customer';
