-- Each partner's own products (packed with barcode/MRP, or loose sold by kg / litre / piece).
CREATE TABLE products (
  id TEXT PRIMARY KEY,
  store_id TEXT NOT NULL,
  kind TEXT NOT NULL DEFAULT 'packed',  -- packed | loose
  name TEXT NOT NULL,
  brand TEXT,
  size TEXT,                            -- packed: "250 g"
  unit TEXT,                            -- loose: kg | litre | piece
  options TEXT,                         -- loose: JSON list of sizes customers can buy (grams / ml / pieces)
  barcode TEXT,
  category TEXT NOT NULL,
  mrp REAL,
  price REAL NOT NULL,                  -- packed: per pack · loose: per kg / litre / piece
  gst REAL NOT NULL,
  hsn TEXT,
  stock INTEGER,                        -- NULL = not counted, only the in-stock switch
  in_stock INTEGER NOT NULL DEFAULT 1,
  photo TEXT,                           -- NULL (category picture) | off | own
  photo_credit TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE INDEX idx_products_store_name ON products (store_id, name);
CREATE INDEX idx_products_store_cat ON products (store_id, category);
CREATE UNIQUE INDEX idx_products_store_barcode ON products (store_id, barcode) WHERE barcode IS NOT NULL;

-- Open Food Facts answers, so the same barcode is looked up once for every shop.
CREATE TABLE barcode_cache (
  code TEXT PRIMARY KEY,
  data TEXT NOT NULL,
  fetched_at INTEGER NOT NULL
);
