-- In-app voice calls (WebRTC, numbers hidden). Audio is never recorded; this log is kept 90 days.
CREATE TABLE voice_calls (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,           -- order | thela
  ref TEXT NOT NULL,            -- order id / calls.id (street call)
  caller_id TEXT NOT NULL,
  callee_id TEXT NOT NULL,
  caller_label TEXT NOT NULL,   -- what the other phone shows: "Customer", "Delivery partner", the thela's name
  callee_label TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL,         -- ringing | connected | ended | missed | declined
  created_at INTEGER NOT NULL,
  answered_at INTEGER,
  ended_at INTEGER
);
CREATE INDEX voice_calls_ref ON voice_calls (kind, ref, created_at);
CREATE INDEX voice_calls_status ON voice_calls (status, created_at);
