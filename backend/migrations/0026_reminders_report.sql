-- Pass reminders (the pass_until value each reminder was sent for), the Sunday report week,
-- "I'm coming out" on thela calls, and a daily count of people who looked at a shop or thela.
ALTER TABLE stores ADD COLUMN pass_warn1 INTEGER;
ALTER TABLE stores ADD COLUMN pass_warn2 INTEGER;
ALTER TABLE stores ADD COLUMN report_week TEXT;
ALTER TABLE calls ADD COLUMN out_at INTEGER;
CREATE TABLE IF NOT EXISTS store_views (
  store_id TEXT NOT NULL,
  day TEXT NOT NULL,
  n INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (store_id, day)
);
