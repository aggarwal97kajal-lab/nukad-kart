-- Real shop orders (customer → shop), shop staff, and each shop's bill number series.
CREATE TABLE orders (
  id TEXT PRIMARY KEY,
  store_id TEXT NOT NULL,
  customer_id TEXT NOT NULL,
  door INTEGER NOT NULL DEFAULT 1,
  status TEXT NOT NULL DEFAULT 'placed', -- placed | accepted | out | delivered | rejected | missed | cancelled
  lines TEXT NOT NULL,                   -- JSON [{pid, name, size, qty, price, gst, hsn, na}]
  items_total INTEGER NOT NULL,
  fee INTEGER NOT NULL DEFAULT 0,
  total INTEGER NOT NULL,
  address TEXT NOT NULL DEFAULT '',
  state TEXT NOT NULL DEFAULT '',
  lat REAL, lng REAL,
  to_name TEXT NOT NULL DEFAULT '',
  to_phone TEXT NOT NULL DEFAULT '',
  buyer_gstin TEXT NOT NULL DEFAULT '',
  buyer_business TEXT NOT NULL DEFAULT '',
  otp TEXT,
  otp_tries INTEGER NOT NULL DEFAULT 0,
  staff_id TEXT,                         -- who delivers (NULL = the owner)
  pay_mode TEXT,                         -- cash | upi
  bill_no TEXT,
  reason TEXT,
  told INTEGER NOT NULL DEFAULT 0,       -- customer told about a missed order
  rider_lat REAL, rider_lng REAL, rider_at INTEGER,
  created_at INTEGER NOT NULL,
  accepted_at INTEGER, out_at INTEGER, delivered_at INTEGER, closed_at INTEGER
);
CREATE INDEX orders_store_status ON orders (store_id, status, created_at);
CREATE INDEX orders_customer ON orders (customer_id, created_at);
CREATE INDEX orders_staff ON orders (staff_id, status);

CREATE TABLE staff (
  id TEXT PRIMARY KEY,
  store_id TEXT NOT NULL,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,              -- 10 digits
  can_orders INTEGER NOT NULL DEFAULT 0, -- accept / reject / pack too (always: deliver + code)
  user_id TEXT,                     -- login account, made at first staff login
  created_at INTEGER NOT NULL,
  removed_at INTEGER
);
CREATE INDEX staff_store ON staff (store_id, removed_at);
CREATE INDEX staff_phone ON staff (phone, removed_at);

CREATE TABLE bill_seq (
  store_id TEXT NOT NULL,
  fy TEXT NOT NULL,
  seq INTEGER NOT NULL,
  PRIMARY KEY (store_id, fy)
);
ALTER TABLE stores ADD COLUMN bill_prefix TEXT;
