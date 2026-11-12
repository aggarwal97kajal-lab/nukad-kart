-- Thelas have no shop timings (they show while LIVE); clear the ones saved by mistake.
UPDATE stores SET opens_at = '', closes_at = '' WHERE kind = 'thela';
