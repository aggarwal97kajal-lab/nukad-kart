// Demo data for the first APK. Replace with API calls when the backend is ready.

class SubCategory {
  final String name;
  final String emoji;
  const SubCategory(this.name, this.emoji);

  /// Photo for the category tile (falls back to the emoji if missing).
  String? get photo => _subPhotoKeys[name] == null ? null : 'assets/images/categories/${_subPhotoKeys[name]}.jpg';
}

const Map<String, String> _subPhotoKeys = {
  'Atta, rice & dal': 'atta_rice_dal',
  'Oil, ghee & masala': 'oil_ghee_masala',
  'Dairy, bread & eggs': 'dairy_bread_eggs',
  'Bakery & biscuits': 'bakery_biscuits',
  'Dry fruits & cereals': 'dry_fruits_cereals',
  'Chicken, meat & fish': 'chicken_meat_fish',
  'Vegetables': 'vegetables',
  'Chips & Namkeen': 'chips_namkeen',
  'Sweets & Chocolates': 'sweets_chocolates',
  'Drinks & Juices': 'drinks_juices',
  'Tea, Coffee & Milk Drinks': 'tea_coffee',
  'Instant Food': 'instant_food',
  'Sauces & Spreads': 'sauces_spreads',
  'Icecreams & more': 'icecreams',
  'Bath & Body': 'bath_body',
  'Hair': 'hair',
  'Skin & Face': 'skin_face',
  'Beauty & Cosmetics': 'beauty_cosmetics',
  'Feminine Hygiene': 'feminine_hygiene',
  'Baby Care': 'baby_care',
  'Health & Pharma': 'health_pharma',
  'Cleaners & Repellents': 'cleaners_repellents',
  'Electronics': 'electronics',
  'Stationary & Games': 'stationary_games',
  'Home & Pooja': 'home_pooja',
};

class MainCategory {
  final String name;
  final String emoji;
  final List<SubCategory> subs;
  const MainCategory(this.name, this.emoji, this.subs);
}

const List<MainCategory> kCategories = [
  MainCategory('Grocery & Kitchen', '🌾', [
    SubCategory('Atta, rice & dal', '🌾'),
    SubCategory('Oil, ghee & masala', '🫙'),
    SubCategory('Dairy, bread & eggs', '🥛'),
    SubCategory('Bakery & biscuits', '🍪'),
    SubCategory('Dry fruits & cereals', '🥜'),
    SubCategory('Chicken, meat & fish', '🍗'),
    SubCategory('Vegetables', '🥦'),
  ]),
  MainCategory('Snacks & Drinks', '🍟', [
    SubCategory('Chips & Namkeen', '🍟'),
    SubCategory('Sweets & Chocolates', '🍫'),
    SubCategory('Drinks & Juices', '🧃'),
    SubCategory('Tea, Coffee & Milk Drinks', '☕'),
    SubCategory('Instant Food', '🍜'),
    SubCategory('Sauces & Spreads', '🍯'),
    SubCategory('Icecreams & more', '🍦'),
  ]),
  MainCategory('Beauty & Personal Care', '🧴', [
    SubCategory('Bath & Body', '🧼'),
    SubCategory('Hair', '💇'),
    SubCategory('Skin & Face', '🧴'),
    SubCategory('Beauty & Cosmetics', '💄'),
    SubCategory('Feminine Hygiene', '🌸'),
    SubCategory('Baby Care', '🍼'),
    SubCategory('Health & Pharma', '🩹'),
  ]),
  MainCategory('Household Essentials', '🏠', [
    SubCategory('Cleaners & Repellents', '🧽'),
    SubCategory('Electronics', '🔌'),
    SubCategory('Stationary & Games', '✏️'),
    SubCategory('Home & Pooja', '🪔'),
  ]),
];

class Product {
  final String id;
  final String name;
  final String size;
  final String emoji;
  final String sub;
  final int mrp;
  const Product(this.id, this.name, this.size, this.emoji, this.sub, this.mrp);
}

const List<Product> kProducts = [
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

Product productById(String id) => kProducts.firstWhere((p) => p.id == id);

class Store {
  final String id;
  final String name;
  final int distanceM;
  final double rating;
  final int ratingCount;
  final bool door;
  final bool pickup;
  final String openTill;
  final String phone;
  final String opensAt;
  final String address;
  /// Shop photo. Vendors must upload a real photo of their shop to sign up.
  String get photo => 'assets/images/stores/$id.jpg';
  String get hours => '$opensAt – $openTill';

  /// Open right now? Uses the shop's daily timings.
  bool isOpenAt(DateTime t) {
    final now = t.hour * 60 + t.minute;
    return now >= _minutes(opensAt) && now < _minutes(openTill);
  }

  bool get isOpen => isOpenAt(DateTime.now());
  const Store(this.id, this.name, this.distanceM, this.rating, this.ratingCount, this.door,
      this.pickup, this.openTill, this.phone, {this.opensAt = '8 am', this.address = ''});
}

const List<Store> kStores = [
  Store('s1', 'Sharma General Store', 180, 4.6, 212, true, true, '10 pm', '+91 98765 11001',
      opensAt: '8 am', address: 'Shop 4, Block C Market, Sector 21, Rohini, New Delhi 110086'),
  Store('s2', 'Gupta Kirana & Dairy', 320, 4.4, 98, true, false, '9:30 pm', '+91 98765 11002',
      opensAt: '6 am', address: 'B-118, near Durga Mandir, Sector 21, Rohini, New Delhi 110086'),
  // Demo: closes early so you can see a closed shop in the evening.
  Store('s3', 'Balaji Provision', 470, 4.2, 54, false, true, '6 pm', '+91 98765 11003',
      opensAt: '9 am', address: 'Shop 11, Pocket 3 Market, Sector 22, Rohini, New Delhi 110086'),
];

/// "9:30 pm" -> minutes after midnight.
int _minutes(String s) {
  final m = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)', caseSensitive: false).firstMatch(s);
  if (m == null) return 0;
  var h = int.parse(m.group(1)!) % 12;
  if (m.group(3)!.toLowerCase() == 'pm') h += 12;
  return h * 60 + int.parse(m.group(2) ?? '0');
}

Store storeById(String id) => kStores.firstWhere((s) => s.id == id);

class Listing {
  final String storeId;
  final String productId;
  final int price;
  final int stock;
  const Listing(this.storeId, this.productId, this.price, this.stock);
}

/// Every store sells most products, at its own price (always ≤ MRP, GST included).
final List<Listing> kListings = _buildListings();

List<Listing> _buildListings() {
  final out = <Listing>[];
  for (var si = 0; si < kStores.length; si++) {
    final s = kStores[si];
    for (var pi = 0; pi < kProducts.length; pi++) {
      final p = kProducts[pi];
      if ((pi + si) % 5 == 4) continue; // not every store sells everything
      final discount = ((pi * 7 + si * 3) % 4) * (p.mrp >= 100 ? 5 : 1);
      final int price = p.mrp - discount;
      final stock = ((pi + si * 2) % 9 == 0) ? 0 : 5 + (pi * 3 + si) % 30;
      out.add(Listing(s.id, p.id, price, stock));
    }
  }
  return out;
}

List<Listing> listingsForStore(String storeId) =>
    kListings.where((l) => l.storeId == storeId).toList();

List<Listing> listingsForProduct(String productId) {
  final l = kListings.where((x) => x.productId == productId).toList();
  l.sort((a, b) => a.price.compareTo(b.price));
  return l;
}

Listing? listingFor(String storeId, String productId) {
  for (final l in kListings) {
    if (l.storeId == storeId && l.productId == productId) return l;
  }
  return null;
}

// ---------- Moving sellers (thelas): connect only, no in-app orders ----------
class ThelaItem {
  final String english;
  final String hindi;
  final int price;
  final String unit;
  final String emoji;
  const ThelaItem(this.english, this.hindi, this.price, this.unit, this.emoji);
}

class Thela {
  final String id;
  final String name;
  final String sells;
  final int distanceM;
  final double rating;
  final bool door;
  final bool pickup;
  final String phone;
  final int lastSeenSec;
  final List<ThelaItem> items;
  const Thela(this.id, this.name, this.sells, this.distanceM, this.rating, this.door, this.pickup,
      this.phone, this.lastSeenSec, this.items);
}

const List<Thela> kThelas = [
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

Thela thelaById(String id) => kThelas.firstWhere((t) => t.id == id);
