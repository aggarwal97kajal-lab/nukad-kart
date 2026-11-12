-- Vendor agreement (e-signed in the Partner app) and the 7-day free trial.
ALTER TABLE stores ADD COLUMN agreement_version TEXT;
ALTER TABLE stores ADD COLUMN trial_until INTEGER;
CREATE TABLE agreements (
  id TEXT PRIMARY KEY,
  store_id TEXT NOT NULL,
  owner_id TEXT NOT NULL,
  version TEXT NOT NULL,
  signer_name TEXT NOT NULL,
  signature TEXT NOT NULL,      -- PNG, base64
  snapshot TEXT NOT NULL,       -- JSON: the vendor and platform details shown when signing
  signed_date TEXT NOT NULL,    -- date shown on the phone (DD/MM/YYYY)
  accepted_at INTEGER NOT NULL, -- server time
  device TEXT,
  ip TEXT
);
CREATE INDEX agreements_store ON agreements (store_id, accepted_at);
