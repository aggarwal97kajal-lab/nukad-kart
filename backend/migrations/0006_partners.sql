-- Partner shops / thelas: owner, licences, pass and live state.
ALTER TABLE stores ADD COLUMN owner_id TEXT;
ALTER TABLE stores ADD COLUMN pickup INTEGER NOT NULL DEFAULT 1;
ALTER TABLE stores ADD COLUMN fssai TEXT;
ALTER TABLE stores ADD COLUMN gst_type TEXT NOT NULL DEFAULT 'none';
ALTER TABLE stores ADD COLUMN gstin TEXT;
ALTER TABLE stores ADD COLUMN pass_until INTEGER NOT NULL DEFAULT 0;
ALTER TABLE stores ADD COLUMN live INTEGER NOT NULL DEFAULT 0;
ALTER TABLE stores ADD COLUMN missed_date TEXT;
ALTER TABLE stores ADD COLUMN missed_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE stores ADD COLUMN status TEXT NOT NULL DEFAULT 'active';
ALTER TABLE stores ADD COLUMN photo_lat REAL;
ALTER TABLE stores ADD COLUMN photo_lng REAL;
ALTER TABLE stores ADD COLUMN photo_at INTEGER;
CREATE INDEX idx_stores_owner ON stores(owner_id);

-- Camera photo of the shop front (JPEG, base64). Kept in the database for now.
CREATE TABLE store_photos (
  store_id TEXT PRIMARY KEY,
  photo TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Pass payments by UPI. Status: CREATED → PAID (UPI app said SUCCESS, or admin confirmed)
-- | CHECKING (admin must look at the bank) | FAILED | CANCELLED (admin: money never came).
CREATE TABLE pass_payments (
  id TEXT PRIMARY KEY,           -- goes in the UPI note, to find it in the bank statement
  idem_key TEXT UNIQUE NOT NULL, -- one per "Pay" tap
  store_id TEXT NOT NULL,
  owner_id TEXT NOT NULL,
  plan TEXT NOT NULL,
  amount INTEGER NOT NULL,
  status TEXT NOT NULL,
  upi_status TEXT, upi_ref TEXT, app TEXT, reason TEXT,
  pass_until INTEGER,
  decided_by TEXT,
  checked_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE INDEX idx_pay_store ON pass_payments(store_id, created_at);
CREATE INDEX idx_pay_status ON pass_payments(status);

