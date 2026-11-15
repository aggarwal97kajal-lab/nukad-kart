-- Order chat: when each side last read it (for the blue double tick).
ALTER TABLE orders ADD COLUMN chat_c_read INTEGER;
ALTER TABLE orders ADD COLUMN chat_s_read INTEGER;
