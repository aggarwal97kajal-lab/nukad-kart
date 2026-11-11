-- Demo shops around Sector 21, Rohini (28.7180, 77.0960). Remove with: DELETE FROM stores WHERE demo = 1;
INSERT INTO stores (id, name, kind, lat, lng, address, phone, opens_at, closes_at, door_delivery, demo, created_at) VALUES
 ('s1', 'Sharma General Store', 'shop', 28.719617, 77.096000, 'Sector 21, Rohini', '+91 98765 11001', '8 am', '10 pm', 1, 1, 0),
 ('s2', 'Gupta Kirana & Dairy', 'shop', 28.718000, 77.099278, 'Sector 21, Rohini', '+91 98765 11002', '7 am', '9:30 pm', 1, 1, 0),
 ('s3', 'Balaji Provision', 'shop', 28.713778, 77.096000, 'Sector 21, Rohini', '+91 98765 11003', '9 am', '6 pm', 0, 1, 0),
 ('s9', 'Far Away Store (900 m, should not show)', 'shop', 28.726085, 77.096000, 'Sector 22, Rohini', NULL, '9 am', '9 pm', 1, 1, 0);
