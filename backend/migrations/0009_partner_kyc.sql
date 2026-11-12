-- Which app an account belongs to: one Google account is either a customer or a partner.
ALTER TABLE users ADD COLUMN app TEXT;
UPDATE users SET app = 'partner' WHERE id IN (SELECT owner_id FROM stores WHERE owner_id IS NOT NULL AND demo = 0);
UPDATE users SET app = 'customer' WHERE app IS NULL AND id IN (SELECT user_id FROM sessions WHERE device_id IS NULL OR device_id NOT LIKE 'partner-%');
UPDATE users SET app = 'partner' WHERE app IS NULL AND id IN (SELECT user_id FROM sessions WHERE device_id LIKE 'partner-%');

-- Partner KYC details and structured address (area/city/state/PIN come from the map pin).
ALTER TABLE stores ADD COLUMN pan TEXT;
ALTER TABLE stores ADD COLUMN aadhaar_last4 TEXT;
ALTER TABLE stores ADD COLUMN addr_shop TEXT;
ALTER TABLE stores ADD COLUMN addr_landmark TEXT;
ALTER TABLE stores ADD COLUMN addr_area TEXT;
ALTER TABLE stores ADD COLUMN addr_city TEXT;
ALTER TABLE stores ADD COLUMN addr_state TEXT;
ALTER TABLE stores ADD COLUMN addr_pin TEXT;
ALTER TABLE stores ADD COLUMN review_note TEXT;
ALTER TABLE stores ADD COLUMN reviewed_at INTEGER;
ALTER TABLE stores ADD COLUMN reviewed_by TEXT;
ALTER TABLE stores ADD COLUMN phone_verified INTEGER NOT NULL DEFAULT 0;
ALTER TABLE stores ADD COLUMN device_hash TEXT;
-- Partner shops need Nukad team approval now; existing test shops go back to "pending".
UPDATE stores SET status = 'pending' WHERE owner_id IS NOT NULL AND demo = 0 AND status = 'active';

-- Verified partner phone (kept apart from the customer phone on users).
ALTER TABLE users ADD COLUMN partner_phone TEXT;
ALTER TABLE users ADD COLUMN partner_device_hash TEXT;

-- Documents: JPG or PDF up to 2 MB, stored in chunks (a D1 row holds at most 2 MB).
CREATE TABLE partner_docs (
  id TEXT PRIMARY KEY,
  store_id TEXT NOT NULL,
  type TEXT NOT NULL,            -- pan | aadhaar | gst | fssai
  mime TEXT NOT NULL,            -- image/jpeg | application/pdf
  name TEXT,
  size INTEGER NOT NULL,
  chunks INTEGER NOT NULL,
  done INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);
CREATE INDEX partner_docs_store ON partner_docs (store_id, type);
CREATE TABLE doc_chunks (
  doc_id TEXT NOT NULL,
  idx INTEGER NOT NULL,
  data TEXT NOT NULL,            -- base64
  PRIMARY KEY (doc_id, idx)
);

-- Free trial given once per phone number AND once per phone (device). Hashes only.
CREATE TABLE trial_claims (
  id TEXT PRIMARY KEY,
  phone_hash TEXT NOT NULL,
  device_hash TEXT,
  store_id TEXT,
  created_at INTEGER NOT NULL
);
CREATE INDEX trial_claims_phone ON trial_claims (phone_hash);
CREATE INDEX trial_claims_device ON trial_claims (device_hash);
