-- Thela live location: where the thela is now, when it last sent it, when it last moved.
ALTER TABLE stores ADD COLUMN live_lat REAL;
ALTER TABLE stores ADD COLUMN live_lng REAL;
ALTER TABLE stores ADD COLUMN live_at INTEGER;
ALTER TABLE stores ADD COLUMN moved_at INTEGER;
ALTER TABLE stores ADD COLUMN heading REAL;
ALTER TABLE stores ADD COLUMN stale_pushed INTEGER NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS stores_thela_live ON stores (kind, live, live_lat, live_lng);
