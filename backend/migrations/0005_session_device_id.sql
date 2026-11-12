-- Random id made once per app install, so logging in again on the same phone replaces its old session.
ALTER TABLE sessions ADD COLUMN device_id TEXT;
CREATE INDEX idx_sessions_device ON sessions(user_id, device_id);
