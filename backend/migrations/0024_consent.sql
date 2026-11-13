-- DPDP: record when the person said they are 18+ and agreed to the privacy notice (which version).
ALTER TABLE users ADD COLUMN consent_version TEXT;
ALTER TABLE users ADD COLUMN consent_at INTEGER;
