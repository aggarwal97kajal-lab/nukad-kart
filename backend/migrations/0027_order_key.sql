-- One checkout = one order: the app's key for a checkout; a repeat with the same key returns the first order.
ALTER TABLE orders ADD COLUMN client_key TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS orders_client_key ON orders (customer_id, client_key) WHERE client_key IS NOT NULL;
