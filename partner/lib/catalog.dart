// Product categories (same names as the customer app), GST defaults, units, and the ready list of loose items.

class Cat {
  final String name, file, hsn;
  final double gst;
  final bool food; // a shop needs an FSSAI number to sell these
  const Cat(this.name, this.file, this.hsn, this.gst, this.food);
  String get image => 'assets/categories/$file.webp';
}

const kCats = [
  Cat('Atta, rice & dal', 'atta_rice_dal', '1006', 5, true),
  Cat('Oil, ghee & masala', 'oil_ghee_masala', '1514', 5, true),
  Cat('Dairy, bread & eggs', 'dairy_bread_eggs', '0401', 0, true),
  Cat('Bakery & biscuits', 'bakery_biscuits', '1905', 5, true),
  Cat('Dry fruits & cereals', 'dry_fruits_cereals', '0801', 5, true),
  Cat('Chicken, meat & fish', 'chicken_meat_fish', '0207', 0, true),
  Cat('Vegetables', 'vegetables', '0709', 0, false),
  Cat('Fruits', 'vegetables', '0810', 0, false),
  Cat('Chips & Namkeen', 'chips_namkeen', '2005', 5, true),
  Cat('Sweets & Chocolates', 'sweets_chocolates', '1806', 5, true),
  Cat('Drinks & Juices', 'drinks_juices', '2202', 5, true),
  Cat('Tea, Coffee & Milk Drinks', 'tea_coffee', '0902', 5, true),
  Cat('Instant Food', 'instant_food', '1902', 5, true),
  Cat('Sauces & Spreads', 'sauces_spreads', '2103', 5, true),
  Cat('Icecreams & more', 'icecreams', '2105', 5, true),
  Cat('Bath & Body', 'bath_body', '3401', 5, false),
  Cat('Hair', 'hair', '3305', 5, false),
  Cat('Skin & Face', 'skin_face', '3304', 5, false),
  Cat('Beauty & Cosmetics', 'beauty_cosmetics', '3304', 5, false),
  Cat('Feminine Hygiene', 'feminine_hygiene', '9619', 0, false),
  Cat('Baby Care', 'baby_care', '9619', 5, false),
  Cat('Health & Pharma', 'health_pharma', '3004', 5, false),
  Cat('Cleaners & Repellents', 'cleaners_repellents', '3402', 5, false),
  Cat('Electronics', 'electronics', '8539', 18, false),
  Cat('Stationary & Games', 'stationary_games', '4820', 5, false),
  Cat('Home & Pooja', 'home_pooja', '3307', 5, false),
];

Cat? catByName(String n) {
  for (final c in kCats) {
    if (c.name == n) return c;
  }
  return null;
}

const kGstRates = [0.0, 5.0, 18.0, 40.0];

/// Sizes a customer can buy, per unit (grams, ml, pieces).
const kUnitSizes = {
  'kg': [100, 250, 500, 1000, 2000, 5000],
  'litre': [250, 500, 1000, 2000, 5000],
  'piece': [1, 2, 3, 6, 12],
  'dozen': [1, 2],
  'bunch': [1, 2, 3],
};

/// Sizes a thela's customers can buy by default, per unit.
const kThelaSizes = {
  'kg': [250, 500, 1000],
  'piece': [1, 2, 6],
  'dozen': [1, 2],
  'bunch': [1, 2],
  'litre': [500, 1000],
};

String sizeLabel(String unit, int n) => switch (unit) {
      'kg' => n >= 1000 ? '${n ~/ 1000} kg' : '$n g',
      'litre' => n >= 1000 ? '${n ~/ 1000} L' : '$n ml',
      'dozen' => n == 1 ? '1 dozen' : '$n dozen',
      'bunch' => n == 1 ? '1 bunch' : '$n bunches',
      _ => n == 1 ? '1 pc' : '$n pcs',
    };

/// Price of one size for a loose item (price is per kg / litre / piece).
num sizePrice(String unit, num perUnit, int n) {
  final v = unit == 'kg' || unit == 'litre' ? perUnit * n / 1000 : perUnit * n;
  return (v * 100).round() / 100;
}

class Loose {
  final String name, cat, unit;
  final List<int> sizes;
  const Loose(this.name, this.cat, this.unit, this.sizes);
}

const _k = [250, 500, 1000];
const _kSmall = [100, 250, 500];
const _veg = [250, 500, 1000];

/// Ready list: the vendor only picks one and types the price.
const kLooseItems = [
  Loose('Wheat Atta', 'Atta, rice & dal', 'kg', [1000, 2000, 5000]),
  Loose('Chakki Atta', 'Atta, rice & dal', 'kg', [1000, 2000, 5000]),
  Loose('Basmati Rice', 'Atta, rice & dal', 'kg', _k),
  Loose('Sona Masoori Rice', 'Atta, rice & dal', 'kg', [1000, 2000, 5000]),
  Loose('Parmal Rice', 'Atta, rice & dal', 'kg', [1000, 2000, 5000]),
  Loose('Poha', 'Atta, rice & dal', 'kg', _k),
  Loose('Suji (Rava)', 'Atta, rice & dal', 'kg', _k),
  Loose('Maida', 'Atta, rice & dal', 'kg', _k),
  Loose('Besan', 'Atta, rice & dal', 'kg', _k),
  Loose('Toor Dal', 'Atta, rice & dal', 'kg', _k),
  Loose('Moong Dal', 'Atta, rice & dal', 'kg', _k),
  Loose('Moong Dal Chilka', 'Atta, rice & dal', 'kg', _k),
  Loose('Masoor Dal', 'Atta, rice & dal', 'kg', _k),
  Loose('Urad Dal', 'Atta, rice & dal', 'kg', _k),
  Loose('Chana Dal', 'Atta, rice & dal', 'kg', _k),
  Loose('Rajma', 'Atta, rice & dal', 'kg', _k),
  Loose('Kabuli Chana', 'Atta, rice & dal', 'kg', _k),
  Loose('Kala Chana', 'Atta, rice & dal', 'kg', _k),
  Loose('Sabudana', 'Atta, rice & dal', 'kg', _kSmall),
  Loose('Sugar', 'Atta, rice & dal', 'kg', [500, 1000, 2000, 5000]),
  Loose('Jaggery (Gud)', 'Atta, rice & dal', 'kg', _k),
  Loose('Mustard Oil', 'Oil, ghee & masala', 'litre', [500, 1000, 2000, 5000]),
  Loose('Refined Oil', 'Oil, ghee & masala', 'litre', [500, 1000, 2000, 5000]),
  Loose('Haldi Powder', 'Oil, ghee & masala', 'kg', _kSmall),
  Loose('Lal Mirch Powder', 'Oil, ghee & masala', 'kg', _kSmall),
  Loose('Dhaniya Powder', 'Oil, ghee & masala', 'kg', _kSmall),
  Loose('Jeera', 'Oil, ghee & masala', 'kg', _kSmall),
  Loose('Rai (Mustard Seeds)', 'Oil, ghee & masala', 'kg', _kSmall),
  Loose('Ajwain', 'Oil, ghee & masala', 'kg', _kSmall),
  Loose('Saunf', 'Oil, ghee & masala', 'kg', _kSmall),
  Loose('Kali Mirch', 'Oil, ghee & masala', 'kg', _kSmall),
  Loose('Methi Dana', 'Oil, ghee & masala', 'kg', _kSmall),
  Loose('Peanuts', 'Dry fruits & cereals', 'kg', _k),
  Loose('Kaju', 'Dry fruits & cereals', 'kg', _kSmall),
  Loose('Badam', 'Dry fruits & cereals', 'kg', _kSmall),
  Loose('Kishmish', 'Dry fruits & cereals', 'kg', _kSmall),
  Loose('Makhana', 'Dry fruits & cereals', 'kg', _kSmall),
  Loose('Paneer', 'Dairy, bread & eggs', 'kg', [250, 500, 1000]),
  Loose('Curd (Dahi)', 'Dairy, bread & eggs', 'kg', _k),
  Loose('Milk (loose)', 'Dairy, bread & eggs', 'litre', [500, 1000, 2000]),
  Loose('Eggs', 'Dairy, bread & eggs', 'piece', [6, 12]),
  Loose('Potato', 'Vegetables', 'kg', [500, 1000, 2000, 5000]),
  Loose('Onion', 'Vegetables', 'kg', [500, 1000, 2000, 5000]),
  Loose('Tomato', 'Vegetables', 'kg', _veg),
  Loose('Ginger', 'Vegetables', 'kg', _kSmall),
  Loose('Garlic', 'Vegetables', 'kg', _kSmall),
  Loose('Green Chilli', 'Vegetables', 'kg', _kSmall),
  Loose('Lemon', 'Vegetables', 'piece', [2, 6, 12]),
  Loose('Coriander (bunch)', 'Vegetables', 'piece', [1, 2]),
  Loose('Spinach (bunch)', 'Vegetables', 'piece', [1, 2]),
  Loose('Cauliflower', 'Vegetables', 'piece', [1, 2]),
  Loose('Cabbage', 'Vegetables', 'piece', [1, 2]),
  Loose('Lauki', 'Vegetables', 'piece', [1, 2]),
  Loose('Brinjal', 'Vegetables', 'kg', _veg),
  Loose('Bhindi', 'Vegetables', 'kg', _veg),
  Loose('Carrot', 'Vegetables', 'kg', _veg),
  Loose('Capsicum', 'Vegetables', 'kg', _veg),
  Loose('Cucumber', 'Vegetables', 'kg', _veg),
  Loose('Matar (Peas)', 'Vegetables', 'kg', _veg),
  Loose('Banana', 'Fruits', 'piece', [6, 12]),
  Loose('Apple', 'Fruits', 'kg', _veg),
  Loose('Orange', 'Fruits', 'kg', [500, 1000, 2000]),
  Loose('Papaya', 'Fruits', 'piece', [1, 2]),
  Loose('Mango', 'Fruits', 'kg', _veg),
  Loose('Grapes', 'Fruits', 'kg', _veg),
  Loose('Pomegranate', 'Fruits', 'kg', _veg),
  Loose('Watermelon', 'Fruits', 'piece', [1]),
];
