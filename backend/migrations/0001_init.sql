CREATE TABLE users (
  id TEXT PRIMARY KEY,
  google_sub TEXT UNIQUE NOT NULL,
  email TEXT NOT NULL,
  name TEXT,
  phone TEXT,
  phone_verified INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE addresses (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  label TEXT NOT NULL DEFAULT 'Home',
  name TEXT, phone TEXT,
  flat TEXT, floor TEXT, area TEXT, city TEXT, state TEXT,
  country TEXT NOT NULL DEFAULT 'India',
  pin TEXT,
  lat REAL, lng REAL,
  is_default INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);
CREATE INDEX idx_addresses_user ON addresses(user_id);

CREATE TABLE stores (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  kind TEXT NOT NULL DEFAULT 'shop',   -- 'shop' or 'thela'
  lat REAL NOT NULL,
  lng REAL NOT NULL,
  address TEXT,
  phone TEXT,
  photo_key TEXT,
  opens_at TEXT, closes_at TEXT,
  door_delivery INTEGER NOT NULL DEFAULT 1,
  active INTEGER NOT NULL DEFAULT 1,
  demo INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);
CREATE INDEX idx_stores_lat_lng ON stores(lat, lng);
