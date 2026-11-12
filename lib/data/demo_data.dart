// Catalogue shapes. Shops, thelas, products and prices come from the server (services/live_data.dart);
// only the category tree and tax table are fixed here.

class SubCategory {
  final String name;
  final String emoji;
  const SubCategory(this.name, this.emoji);

  /// Photo for the category tile (falls back to the emoji if missing).
  String? get photo => _subPhotoKeys[name] == null ? null : 'assets/images/categories/${_subPhotoKeys[name]}.webp';
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
    SubCategory('Fruits', '🍎'),
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

  /// HSN code and GST % used on GST bills. The shop sets these in the Partner app;
  /// the demo uses a typical value for the category.
  (String, double) get hsnGst => kCategoryTax[sub] ?? ('9999', 18);
}

/// Typical HSN and GST % per category (demo values; shops confirm per product).
const Map<String, (String, double)> kCategoryTax = {
  'Atta, rice & dal': ('1006', 5),
  'Oil, ghee & masala': ('1514', 5),
  'Dairy, bread & eggs': ('0401', 0),
  'Bakery & biscuits': ('1905', 5),
  'Dry fruits & cereals': ('0801', 5),
  'Chicken, meat & fish': ('0207', 0),
  'Vegetables': ('0709', 0),
  'Fruits': ('0810', 0),
  'Chips & Namkeen': ('2005', 5),
  'Sweets & Chocolates': ('1806', 5),
  'Drinks & Juices': ('2202', 5),
  'Tea, Coffee & Milk Drinks': ('0902', 5),
  'Instant Food': ('1902', 5),
  'Sauces & Spreads': ('2103', 5),
  'Icecreams & more': ('2105', 5),
  'Bath & Body': ('3401', 5),
  'Hair': ('3305', 5),
  'Skin & Face': ('3304', 5),
  'Beauty & Cosmetics': ('3304', 5),
  'Feminine Hygiene': ('9619', 0),
  'Baby Care': ('9619', 5),
  'Health & Pharma': ('3004', 5),
  'Cleaners & Repellents': ('3402', 5),
  'Electronics': ('8539', 18),
  'Stationary & Games': ('4820', 5),
  'Home & Pooja': ('3307', 5),
};

/// Everything the nearby shops sell (filled from the server).
final List<Product> kProducts = [];

final Map<String, Product> _productSeen = {};

/// Old orders can name a product the shop no longer sells, so unknown ids get a placeholder.
Product productById(String id) =>
    _productSeen[id] ?? kProducts.firstWhere((p) => p.id == id, orElse: () => Product(id, 'Item', '', '🛍️', '', 0));

void rememberProducts(Iterable<Product> list) {
  for (final p in list) {
    _productSeen[p.id] = p;
  }
}

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
  /// Shop photo (server URL). Vendors must upload a real photo of their shop to sign up.
  final String? photoUrl;
  String get photo => photoUrl ?? 'assets/images/stores/$id.jpg';
  final double lat, lng;
  String get ratingText => rating > 0 ? '★ $rating' : 'New';
  String get hours => '$opensAt – $openTill';

  /// Open right now? Uses the shop's daily timings.
  bool isOpenAt(DateTime t) {
    final now = t.hour * 60 + t.minute;
    return now >= _minutes(opensAt) && now < _minutes(openTill);
  }

  bool get isOpen => isOpenAt(DateTime.now());

  // ----- bill settings (set by the shop in the Partner app) -----
  final BillGst gst;
  final String gstin;
  final String fssai;
  final String stateName;
  final String stateCode;
  final String billPrefix;
  final String? logo;
  final List<String> billTerms;

  const Store(this.id, this.name, this.distanceM, this.rating, this.ratingCount, this.door,
      this.pickup, this.openTill, this.phone,
      {this.opensAt = '8 am',
      this.address = '',
      this.gst = BillGst.none,
      this.gstin = '',
      this.fssai = '',
      this.stateName = 'Delhi',
      this.stateCode = '07',
      this.billPrefix = 'NK',
      this.logo,
      this.billTerms = const [],
      this.photoUrl,
      this.lat = 0,
      this.lng = 0});
}

/// How a shop is registered under GST. Decides the bill title and tax columns.
enum BillGst { none, regular, composition }

/// Shops within 500 m of the customer's address (filled from the server).
final List<Store> kStores = [];

/// "9:30 pm" -> minutes after midnight.
int _minutes(String s) {
  final m = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)', caseSensitive: false).firstMatch(s);
  if (m == null) return 0;
  var h = int.parse(m.group(1)!) % 12;
  if (m.group(3)!.toLowerCase() == 'pm') h += 12;
  return h * 60 + int.parse(m.group(2) ?? '0');
}

final Map<String, Store> _storeSeen = {};

/// Old orders can name a shop that is no longer nearby, so unknown ids get a placeholder.
Store storeById(String id) =>
    _storeSeen[id] ?? kStores.firstWhere((s) => s.id == id, orElse: () => Store(id, 'Shop', 0, 0, 0, false, false, '', ''));

void rememberStores(Iterable<Store> list) {
  for (final s in list) {
    _storeSeen[s.id] = s;
  }
}

class Listing {
  final String storeId;
  final String productId;
  final int price;
  final int stock;
  const Listing(this.storeId, this.productId, this.price, this.stock);
}

/// Each shop's price and stock for a product (filled from the server).
final List<Listing> kListings = [];

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
  final String emoji; // an emoji, or the item's photo (asset path or URL)
  final num exactPrice;
  const ThelaItem(this.english, this.hindi, this.price, this.unit, this.emoji, {this.exactPrice = 0});
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
  final double lat, lng;
  final bool moving;
  final String? photoUrl;
  const Thela(this.id, this.name, this.sells, this.distanceM, this.rating, this.door, this.pickup,
      this.phone, this.lastSeenSec, this.items, {this.lat = 0, this.lng = 0, this.moving = false, this.photoUrl});
  String get ratingText => rating > 0 ? '★ $rating' : 'New';
}

/// Thelas whose live location is within 500 m (filled from the server).
final List<Thela> kThelas = [];

Thela thelaById(String id) =>
    kThelas.firstWhere((t) => t.id == id, orElse: () => Thela(id, 'Thela', '', 0, 0, false, false, '', 0, const []));
