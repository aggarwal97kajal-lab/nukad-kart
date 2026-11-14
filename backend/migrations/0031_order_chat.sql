-- Chat on a shop order between the customer and the shop / delivery partner (no phone numbers allowed).
CREATE TABLE order_messages (
  id TEXT PRIMARY KEY,
  order_id TEXT NOT NULL,
  sender TEXT NOT NULL,      -- c = customer, s = shop / delivery partner
  text TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX order_messages_order ON order_messages (order_id, created_at);
