-- Letters of intent signed by shops and thelas in the field (nukkadkart.in/loi). Only admins add and read them.
CREATE TABLE IF NOT EXISTS loi (
  id TEXT PRIMARY KEY,
  client_id TEXT NOT NULL UNIQUE,      -- made by the phone, so a retry after a weak network never saves twice
  kind TEXT NOT NULL,                  -- kirana | thela | dairy | other
  shop_name TEXT NOT NULL,
  owner_name TEXT NOT NULL,
  area TEXT NOT NULL,
  years TEXT NOT NULL DEFAULT '',
  mobile TEXT NOT NULL DEFAULT '',
  delivers TEXT NOT NULL DEFAULT '',   -- yes | no
  upi TEXT NOT NULL DEFAULT '',
  android TEXT NOT NULL DEFAULT '',
  pass TEXT NOT NULL DEFAULT '',       -- day | week | month | year
  sign_png TEXT NOT NULL,              -- data:image/png;base64,…
  lat REAL,
  lng REAL,
  collected_by TEXT NOT NULL,
  signed_at INTEGER NOT NULL,          -- when it was signed on the phone
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS loi_signed ON loi (signed_at);
