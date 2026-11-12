-- "Call to my street": a customer asks a LIVE thela to come to their street. No cart, no numbers shared.
CREATE TABLE calls (
  id TEXT PRIMARY KEY,
  thela_id TEXT NOT NULL,
  customer_id TEXT NOT NULL,
  lat REAL NOT NULL,
  lng REAL NOT NULL,
  address TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'waiting', -- waiting | coming | declined | expired | cancelled | no_show | done
  created_at INTEGER NOT NULL,
  answered_at INTEGER,
  told INTEGER NOT NULL DEFAULT 0 -- customer was told the result by push
);
CREATE INDEX calls_thela_status ON calls (thela_id, status, created_at);
CREATE INDEX calls_customer ON calls (customer_id, created_at);
-- 3 "came, nobody there" in 30 days → no calling for 7 days.
ALTER TABLE users ADD COLUMN calls_blocked_until INTEGER NOT NULL DEFAULT 0;
