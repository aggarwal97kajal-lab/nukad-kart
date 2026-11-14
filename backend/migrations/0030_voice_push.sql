-- How many of the called person's phones the ring push reached (0 = nobody got it), and FCM's error if any.
ALTER TABLE voice_calls ADD COLUMN pushed INTEGER;
ALTER TABLE voice_calls ADD COLUMN push_err TEXT;
