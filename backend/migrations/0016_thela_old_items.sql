-- Thelas now pick items from the photo list only. Remove items a thela added by hand earlier
-- (their photos in R2 are left; they are small and no longer linked).
DELETE FROM products WHERE produce_key IS NULL AND store_id IN (SELECT id FROM stores WHERE kind = 'thela');
