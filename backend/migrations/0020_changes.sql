-- A live shop / thela asks to change its name, address (map pin) or photo: Nukad team checks first.
CREATE TABLE store_changes (
  id TEXT PRIMARY KEY,
  store_id TEXT NOT NULL,
  data TEXT NOT NULL,            -- JSON of the new store columns
  has_photo INTEGER NOT NULL DEFAULT 0, -- new photo in R2 at changes/<id>.jpg
  status TEXT NOT NULL DEFAULT 'pending', -- pending | approved | rejected | replaced
  note TEXT,
  created_at INTEGER NOT NULL,
  reviewed_at INTEGER,
  reviewed_by TEXT
);
CREATE INDEX store_changes_status ON store_changes (status, created_at);
CREATE INDEX store_changes_store ON store_changes (store_id, created_at);
