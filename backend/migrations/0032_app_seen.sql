-- Last time the app was open on one of this person's phones (it asks for incoming calls every few seconds).
-- A call is said to be "can't be reached" only when the ring push failed AND the app was not open in the last 30 s.
ALTER TABLE users ADD COLUMN app_seen_at INTEGER;
