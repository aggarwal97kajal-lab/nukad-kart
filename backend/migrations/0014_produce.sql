-- Thela produce: picked from the app's photo list (aloo, pyaz…), one row per item per thela.
ALTER TABLE products ADD COLUMN produce_key TEXT;
CREATE UNIQUE INDEX idx_products_store_produce ON products (store_id, produce_key) WHERE produce_key IS NOT NULL;
-- Date (India) when the thela last confirmed today's prices.
ALTER TABLE stores ADD COLUMN prices_confirmed TEXT;
