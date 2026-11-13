-- Customer can turn chat-reply notifications off (Notification preferences).
ALTER TABLE customer_spots ADD COLUMN chat_alerts INTEGER NOT NULL DEFAULT 1;
