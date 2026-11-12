-- Phones that can get push notifications (Firebase Cloud Messaging token per install).
CREATE TABLE push_tokens (
  token TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  app TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE INDEX push_tokens_user ON push_tokens (user_id);

-- Indexes for the queries the apps run often (fewer rows read = less database load).
CREATE INDEX IF NOT EXISTS idx_stores_owner_created ON stores (owner_id, created_at);
CREATE INDEX IF NOT EXISTS idx_stores_status_created ON stores (status, created_at);
CREATE INDEX IF NOT EXISTS idx_users_partner_phone ON users (partner_phone);
CREATE INDEX IF NOT EXISTS idx_pay_store_status ON pass_payments (store_id, status, created_at);
CREATE INDEX IF NOT EXISTS idx_pay_created ON pass_payments (created_at);
CREATE INDEX IF NOT EXISTS idx_docs_store_done ON partner_docs (store_id, done, created_at);
