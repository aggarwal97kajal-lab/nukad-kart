// The old built-in demo shops, used only by tests (the app now loads real shops from the server).
import 'package:nukad_kart/data/demo_data.dart';

const List<Product> _products = [
  Product('p1', 'Chakki Atta', '5 kg', '🌾', 'Atta, rice & dal', 260),
  Product('p2', 'Basmati Rice', '1 kg', '🍚', 'Atta, rice & dal', 130),
  Product('p3', 'Toor Dal', '1 kg', '🫘', 'Atta, rice & dal', 180),
  Product('p4', 'Mustard Oil', '1 L', '🫙', 'Oil, ghee & masala', 190),
  Product('p5', 'Desi Ghee', '500 ml', '🧈', 'Oil, ghee & masala', 340),
  Product('p6', 'Toned Milk', '500 ml', '🥛', 'Dairy, bread & eggs', 34),
  Product('p7', 'Brown Bread', '400 g', '🍞', 'Dairy, bread & eggs', 50),
  Product('p8', 'Eggs', '6 pc', '🥚', 'Dairy, bread & eggs', 48),
  Product('p9', 'Glucose Biscuits', '250 g', '🍪', 'Bakery & biscuits', 30),
  Product('p10', 'Cashews', '200 g', '🥜', 'Dry fruits & cereals', 220),
  Product('p11', 'Potato', '1 kg', '🥔', 'Vegetables', 30),
  Product('p12', 'Tomato', '1 kg', '🍅', 'Vegetables', 40),
  Product('p13', 'Onion', '1 kg', '🧅', 'Vegetables', 35),
  Product('p14', 'Salted Chips', '52 g', '🍟', 'Chips & Namkeen', 20),
  Product('p15', 'Milk Chocolate', '50 g', '🍫', 'Sweets & Chocolates', 50),
  Product('p16', 'Mango Juice', '1 L', '🧃', 'Drinks & Juices', 110),
  Product('p17', 'Assam Tea', '250 g', '☕', 'Tea, Coffee & Milk Drinks', 140),
  Product('p18', 'Masala Noodles', '70 g', '🍜', 'Instant Food', 15),
  Product('p19', 'Tomato Ketchup', '500 g', '🍯', 'Sauces & Spreads', 120),
  Product('p20', 'Vanilla Ice Cream', '500 ml', '🍦', 'Icecreams & more', 150),
  Product('p21', 'Bath Soap', '4 × 100 g', '🧼', 'Bath & Body', 160),
  Product('p22', 'Herbal Shampoo', '180 ml', '🧴', 'Hair', 190),
  Product('p23', 'Face Wash', '100 ml', '🧴', 'Skin & Face', 175),
  Product('p24', 'Kajal', '0.35 g', '💄', 'Beauty & Cosmetics', 199),
  Product('p25', 'Sanitary Pads', '8 pc', '🌸', 'Feminine Hygiene', 60),
  Product('p26', 'Baby Wipes', '72 pc', '🍼', 'Baby Care', 99),
  Product('p27', 'Bandage Strips', '20 pc', '🩹', 'Health & Pharma', 40),
  Product('p28', 'Dishwash Liquid', '500 ml', '🧽', 'Cleaners & Repellents', 110),
  Product('p29', 'Mosquito Coil', '10 pc', '🦟', 'Cleaners & Repellents', 45),
  Product('p30', 'LED Bulb', '9 W', '💡', 'Electronics', 99),
  Product('p31', 'AA Batteries', '4 pc', '🔋', 'Electronics', 80),
  Product('p32', 'Notebook', '172 pages', '📓', 'Stationary & Games', 60),
  Product('p33', 'Diya Set', '6 pc', '🪔', 'Home & Pooja', 60),
  Product('p34', 'Agarbatti', '100 g', '🪔', 'Home & Pooja', 50),
  Product('p35', 'Camphor', '50 g', '🕯️', 'Home & Pooja', 70),
  Product('p36', 'Floor Cleaner', '1 L', '🧴', 'Cleaners & Repellents', 199),
];

const List<Store> _stores = [
  Store('s1', 'Sharma General Store', 180, 4.6, 212, true, true, '10 pm', '+91 98765 11001',
      opensAt: '8 am',
      address: 'Shop 4, Block C Market, Sector 21, Rohini, New Delhi 110086',
      gst: BillGst.regular,
      gstin: '07ABCPS1234K1ZO',
      fssai: '13324011000704',
      billPrefix: 'SGS',
      logo: 'assets/images/stores/s1_logo.png',
      billTerms: ['Goods once sold will be exchanged only if damaged.', 'Fresh items: no return.', 'Queries: call +91 98765 11001.']),
  Store('s2', 'Gupta Kirana & Dairy', 320, 4.4, 98, true, false, '9:30 pm', '+91 98765 11002',
      opensAt: '6 am',
      address: 'B-118, near Durga Mandir, Sector 21, Rohini, New Delhi 110086',
      gst: BillGst.composition,
      gstin: '07AAGPG5678L1Z8',
      fssai: '23324011000881',
      billPrefix: 'GKD',
      billTerms: ['Milk and curd: no return.', 'Please check items at the door.']),
  // Demo: closes early so you can see a closed shop in the evening.
  Store('s3', 'Balaji Provision', 470, 4.2, 54, false, true, '6 pm', '+91 98765 11003',
      opensAt: '9 am',
      address: 'Shop 11, Pocket 3 Market, Sector 22, Rohini, New Delhi 110086',
      fssai: '23324011000992',
      billPrefix: 'BP'),
];

const List<Thela> _thelas = [
  Thela('t1', 'Ramu Sabzi Wala', 'Vegetables', 220, 4.8, true, true, '+91 98111 22001', 20, [
    ThelaItem('Tomato', 'Tamatar', 40, 'kg', '🍅'),
    ThelaItem('Onion', 'Pyaaz', 35, 'kg', '🧅'),
    ThelaItem('Potato', 'Aloo', 28, 'kg', '🥔'),
    ThelaItem('Spinach', 'Palak', 15, 'bunch', '🥬'),
    ThelaItem('Lady finger', 'Bhindi', 60, 'kg', '🫛'),
  ]),
  Thela('t2', 'Fresh Phal Thela', 'Fruits', 380, 4.5, false, true, '+91 98111 22002', 45, [
    ThelaItem('Banana', 'Kela', 60, 'dozen', '🍌'),
    ThelaItem('Apple', 'Seb', 160, 'kg', '🍎'),
    ThelaItem('Papaya', 'Papita', 50, 'pc', '🥭'),
    ThelaItem('Grapes', 'Angoor', 90, 'kg', '🍇'),
  ]),
  Thela('t3', 'Lakshmi Sabzi', 'Vegetables & herbs', 450, 4.3, true, false, '+91 98111 22003', 90, [
    ThelaItem('Coriander', 'Dhaniya', 10, 'bunch', '🌿'),
    ThelaItem('Green chilli', 'Hari mirch', 80, 'kg', '🌶️'),
    ThelaItem('Cauliflower', 'Gobhi', 30, 'pc', '🥦'),
    ThelaItem('Carrot', 'Gajar', 40, 'kg', '🥕'),
  ]),
];

/// Fills the app's shared lists with the demo shops, products and prices.
void seedDemo() {
  kProducts
    ..clear()
    ..addAll(_products);
  kStores
    ..clear()
    ..addAll(_stores);
  kThelas
    ..clear()
    ..addAll(_thelas);
  kListings.clear();
  for (var si = 0; si < _stores.length; si++) {
    for (var pi = 0; pi < _products.length; pi++) {
      final p = _products[pi];
      if ((pi + si) % 5 == 4) continue;
      final discount = ((pi * 7 + si * 3) % 4) * (p.mrp >= 100 ? 5 : 1);
      final stock = ((pi + si * 2) % 9 == 0) ? 0 : 5 + (pi * 3 + si) % 30;
      kListings.add(Listing(_stores[si].id, p.id, p.mrp - discount, stock));
    }
  }
  rememberProducts(_products);
  rememberStores(_stores);
}
