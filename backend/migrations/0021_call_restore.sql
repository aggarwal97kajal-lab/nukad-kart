-- Admin can give "Call to my street" back to a paused customer (once in 90 days, with a reason).
ALTER TABLE users ADD COLUMN calls_restored_at INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN calls_restore_note TEXT;
