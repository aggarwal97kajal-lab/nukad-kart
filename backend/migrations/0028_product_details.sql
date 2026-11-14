-- Product page like Blinkit: up to 5 photos (main + 4 more) and optional details.
-- photo_slots: JSON list of the extra slots that have a photo, e.g. [1,3] (files products/<id>_<slot>.jpg).
-- details: JSON {desc, veg: 'veg'|'nonveg'|'', ingredients, shelf}
ALTER TABLE products ADD COLUMN photo_slots TEXT;
ALTER TABLE products ADD COLUMN details TEXT;
