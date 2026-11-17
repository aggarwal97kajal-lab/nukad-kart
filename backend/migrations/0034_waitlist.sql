-- Early access list from nukkadkart.in. One row per email; Brevo gets a copy for launch emails.
CREATE TABLE IF NOT EXISTS waitlist (
  email TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  pincode TEXT NOT NULL,
  city TEXT NOT NULL,
  state TEXT NOT NULL,
  consent_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  brevo_synced INTEGER NOT NULL DEFAULT 0,
  brevo_tries INTEGER NOT NULL DEFAULT 0,
  confirm_sent INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS waitlist_unsynced ON waitlist (brevo_synced, brevo_tries);
CREATE INDEX IF NOT EXISTS waitlist_pincode ON waitlist (pincode);
