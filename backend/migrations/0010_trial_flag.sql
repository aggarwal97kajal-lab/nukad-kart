-- Whether this partner's verified number + phone can still get the free trial (saves a lookup on every app open).
ALTER TABLE users ADD COLUMN partner_trial_ok INTEGER;
