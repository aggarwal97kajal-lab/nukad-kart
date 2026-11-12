-- Chat between a customer and a thela (text only, numbers blocked, kept 24 hours).
CREATE TABLE chats (
  id TEXT PRIMARY KEY,
  thela_id TEXT NOT NULL,
  customer_id TEXT NOT NULL,
  address TEXT NOT NULL DEFAULT '',
  lat REAL, lng REAL,
  blocked_by TEXT,            -- 'customer' | 'thela' | NULL
  last_at INTEGER NOT NULL,
  thela_read_at INTEGER NOT NULL DEFAULT 0,
  customer_read_at INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  UNIQUE (thela_id, customer_id)
);
CREATE INDEX chats_thela ON chats (thela_id, last_at);
CREATE TABLE chat_messages (
  id TEXT PRIMARY KEY,
  chat_id TEXT NOT NULL,
  sender TEXT NOT NULL,       -- 'c' customer | 't' thela
  text TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX chat_messages_chat ON chat_messages (chat_id, created_at);
CREATE TABLE reports (
  id TEXT PRIMARY KEY,
  chat_id TEXT,
  by_user TEXT NOT NULL,
  against_user TEXT NOT NULL,
  reason TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL
);
CREATE INDEX reports_against ON reports (against_user, created_at);
ALTER TABLE users ADD COLUMN chat_blocked_until INTEGER NOT NULL DEFAULT 0;
-- A customer is looking at this thela's page: its phone sends location every few seconds until then.
ALTER TABLE stores ADD COLUMN watched_until INTEGER NOT NULL DEFAULT 0;
