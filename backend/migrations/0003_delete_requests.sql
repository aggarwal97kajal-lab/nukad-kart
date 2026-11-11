ALTER TABLE users ADD COLUMN deleted_at INTEGER;

-- One row per delete request: proof that the customer asked, and why.
CREATE TABLE deletion_requests (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  reason TEXT,
  feedback TEXT,
  created_at INTEGER NOT NULL
);

CREATE INDEX idx_users_phone ON users(phone);
