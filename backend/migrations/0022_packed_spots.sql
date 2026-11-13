-- Packed and "out for delivery" are now two steps (the delivery person starts it on their own phone).
ALTER TABLE orders ADD COLUMN packed_at INTEGER;
-- Where a customer wants thela alerts (their chosen address), for "a thela is LIVE near you".
CREATE TABLE customer_spots (
  user_id TEXT PRIMARY KEY,
  lat REAL NOT NULL,
  lng REAL NOT NULL,
  alerts INTEGER NOT NULL DEFAULT 1,
  updated_at INTEGER NOT NULL
);
CREATE INDEX customer_spots_geo ON customer_spots (lat, lng);
CREATE TABLE thela_alerts (
  user_id TEXT NOT NULL,
  thela_id TEXT NOT NULL,
  at INTEGER NOT NULL,
  PRIMARY KEY (user_id, thela_id)
);
ALTER TABLE stores ADD COLUMN alert_lat REAL;
ALTER TABLE stores ADD COLUMN alert_lng REAL;
