import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';
import '../data/demo_data.dart';
import '../l10n.dart';

enum OrderStatus { placed, accepted, packed, outForDelivery, delivered, rejected, autoCancelled, cancelled }

String statusLabel(OrderStatus s) => t(switch (s) {
      OrderStatus.placed => 'Waiting for store',
      OrderStatus.accepted => 'Accepted by store',
      OrderStatus.packed => 'Packed',
      OrderStatus.outForDelivery => 'Out for delivery',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.rejected => 'Rejected by store',
      OrderStatus.autoCancelled => 'Auto-cancelled',
      OrderStatus.cancelled => 'Cancelled',
    });

class OrderLine {
  final String productId;
  final int qty;
  final int price;
  const OrderLine(this.productId, this.qty, this.price);
}

class Order {
  final String id;
  final String storeId;
  final List<OrderLine> lines;
  final bool door;
  final DateTime placedAt;
  int fee = 0;
  OrderStatus status = OrderStatus.placed;
  final Map<OrderStatus, DateTime> times = {};
  Order(this.id, this.storeId, this.lines, this.door, this.placedAt) {
    times[OrderStatus.placed] = placedAt;
  }
  int get total => lines.fold(0, (s, l) => s + l.price * l.qty);
  int get payable => total + fee;
  int get itemCount => lines.fold(0, (s, l) => s + l.qty);
  bool get isOpen =>
      status == OrderStatus.placed ||
      status == OrderStatus.accepted ||
      status == OrderStatus.packed ||
      status == OrderStatus.outForDelivery;
}

class ThelaRequest {
  final String thelaId;
  final String slot;
  final List<String> items;
  bool accepted = false;
  ThelaRequest(this.thelaId, this.slot, this.items);
}

/// Delivery fee rule: ₹20 below ₹199, free from ₹199. The fee goes to the store.
const int kFreeDeliveryMin = 199;
const int kDeliveryFee = 20;

/// Demo: pin codes where the demo shops are. Any other pin shows "No stores available".
const Set<String> kServiceablePins = {'110085', '110086', '110089'};

class Address {
  final String flat, floor, area, city, state, country, pin, name, phone;
  final String label; // Home, Work, Hotel or the customer's own name
  final double px, py; // pin position on the demo map, 0..1
  const Address({
    this.flat = '',
    this.floor = '',
    required this.area,
    this.city = 'New Delhi',
    this.state = 'Delhi',
    this.country = 'India',
    required this.pin,
    this.name = '',
    this.phone = '',
    this.label = 'Home',
    this.px = 0.5,
    this.py = 0.5,
  });

  String get short => [flat, floor, area].where((x) => x.trim().isNotEmpty).join(', ');
  String get full => '$short, $city, $state $pin';

  Map<String, dynamic> toJson() => {
        'flat': flat, 'floor': floor, 'area': area, 'city': city, 'state': state,
        'country': country, 'pin': pin, 'name': name, 'phone': phone, 'label': label, 'px': px, 'py': py,
      };

  factory Address.fromJson(Map<String, dynamic> j) => Address(
        flat: '${j['flat'] ?? ''}',
        floor: '${j['floor'] ?? ''}',
        area: '${j['area'] ?? ''}',
        city: '${j['city'] ?? 'New Delhi'}',
        state: '${j['state'] ?? 'Delhi'}',
        country: '${j['country'] ?? 'India'}',
        pin: '${j['pin'] ?? ''}',
        name: '${j['name'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        label: '${j['label'] ?? 'Home'}',
        px: (j['px'] as num?)?.toDouble() ?? 0.5,
        py: (j['py'] as num?)?.toDouble() ?? 0.5,
      );
}

/// Where a guest browses from until they set an address.
const Address kGuestLocation = Address(area: 'Sector 21, Rohini', pin: '110086');

class AppNotification {
  final String title;
  final String body;
  final DateTime at;
  bool read = false;
  AppNotification(this.title, this.body) : at = DateTime.now();
}

enum AppTheme { light, dark, system }

class AppState extends ChangeNotifier {
  // ----- appearance & language -----
  AppTheme theme = AppTheme.light;
  String lang = 'en'; // en | hi | hg (Hinglish)

  void setTheme(AppTheme v) {
    theme = v;
    notifyListeners();
  }

  void setLang(String v) {
    lang = v;
    notifyListeners();
  }

  // ----- out of stock: notify me -----
  final Set<String> notifyMe = {}; // "storeId|productId"
  final Set<String> restocked = {};
  void Function(String storeId, String productId)? onBackInStock;

  String _k(String storeId, String productId) => '$storeId|$productId';
  int stockOf(Listing l) => restocked.contains(_k(l.storeId, l.productId)) ? 12 : l.stock;
  bool isNotifyOn(String storeId, String productId) => notifyMe.contains(_k(storeId, productId));

  /// Demo: the store "restocks" 15 s after the customer taps Notify.
  void toggleNotify(String storeId, String productId) {
    final k = _k(storeId, productId);
    if (notifyMe.remove(k)) {
      notifyListeners();
      return;
    }
    notifyMe.add(k);
    notifyListeners();
    _timers.add(Timer(Duration(seconds: 15), () {
      if (!notifyMe.contains(k)) return;
      notifyMe.remove(k);
      restocked.add(k);
      final p = productById(productId);
      final st = storeById(storeId);
      notifications.insert(0, AppNotification('${p.name} ${p.size} is back!', 'Now in stock at ${st.name}'));
      notifyListeners();
      onBackInStock?.call(storeId, productId);
    }));
  }

  // ----- saved things -----
  final Set<String> wishlist = {};
  final Set<String> bookmarks = {};
  final List<Address> addresses = [];
  int currentIdx = -1;
  Address get current => (currentIdx >= 0 && currentIdx < addresses.length) ? addresses[currentIdx] : kGuestLocation;
  String get address => current.short;
  bool get serviceable => kServiceablePins.contains(current.pin);
  final Map<String, bool> notifPrefs = {
    'Order updates': true,
    'Thela replies': true,
    'Offers from nearby shops': false,
    'Festival specials': true,
  };

  void toggleWishlist(String productId) {
    wishlist.contains(productId) ? wishlist.remove(productId) : wishlist.add(productId);
    notifyListeners();
  }

  void toggleBookmark(String storeId) {
    bookmarks.contains(storeId) ? bookmarks.remove(storeId) : bookmarks.add(storeId);
    notifyListeners();
  }

  void saveAddress(Address a, {Address? replacing}) {
    final i = replacing == null ? -1 : addresses.indexOf(replacing);
    if (i >= 0) {
      addresses[i] = a;
      currentIdx = i;
    } else {
      addresses.add(a);
      currentIdx = addresses.length - 1;
    }
    if (name.isEmpty && a.name.isNotEmpty) name = a.name;
    if (phone.isEmpty && a.phone.isNotEmpty) phone = a.phone;
    notifyListeners();
  }

  void useAddress(Address a) {
    currentIdx = addresses.indexOf(a);
    notifyListeners();
  }

  void removeAddress(Address a) {
    final cur = current;
    addresses.remove(a);
    currentIdx = addresses.indexOf(cur);
    if (currentIdx < 0 && addresses.isNotEmpty) currentIdx = 0;
    notifyListeners();
  }

  void setNotif(String k, bool v) {
    notifPrefs[k] = v;
    notifyListeners();
  }

  // ----- user -----
  bool signedIn = false;
  bool guest = false; // tapped Skip on the login screen
  String name = '';
  String email = '';
  String phone = '';
  int strikes = 0;
  bool acceptedTerms = false;

  /// Saved profiles by Google account, so logging in again skips the details.
  /// (Demo: kept on this phone. The real app keeps them on the server.)
  final Map<String, Map<String, dynamic>> _profiles = {};

  bool get profileComplete => name.trim().length >= 2 && phone.length == 10 && addresses.isNotEmpty;

  void continueAsGuest() {
    guest = true;
    notifyListeners();
  }

  /// Returns true when this Google account already has name, number and address saved.
  bool signIn(String googleEmail) {
    email = googleEmail;
    signedIn = true;
    final p = _profiles[googleEmail];
    if (p != null) {
      _readProfile(p);
      notifyListeners();
      return profileComplete;
    }
    notifyListeners();
    return profileComplete; // a guest who already saved an address with name and number

  }

  /// Backed out of the details screen: go back to guest.
  void cancelSignIn() {
    signedIn = false;
    email = '';
    guest = true;
    notifyListeners();
  }

  void saveProfile(String n, String p) {
    name = n;
    phone = p;
    notifyListeners();
  }

  void signOut() {
    _storeProfile();
    signedIn = false;
    guest = false;
    email = '';
    phone = '';
    name = '';
    addresses.clear();
    currentIdx = -1;
    strikes = 0;
    cart.clear();
    cartStoreId = null;
    notifyListeners();
  }

  /// Request to delete account. Demo: wipes this account's data from this phone.
  /// (Real app: sent to the server; order and complaint records are kept as the law requires.)
  String? lastDeleteReason;
  void requestDeleteAccount(String reason, String feedback) {
    lastDeleteReason = reason;
    _profiles.remove(email);
    wishlist.clear();
    bookmarks.clear();
    ratings.clear();
    ratingPromptShown.clear();
    notifications.clear();
    orders.clear();
    requests.clear();
    notifyMe.clear();
    acceptedTerms = false;
    signedIn = false; // so signOut() below does not save the profile again
    signOut();
  }

  Map<String, dynamic> _profileJson() => {
        'name': name,
        'phone': phone,
        'addresses': addresses.map((a) => a.toJson()).toList(),
        'currentIdx': currentIdx,
        'strikes': strikes,
      };

  void _readProfile(Map<String, dynamic> p) {
    name = '${p['name'] ?? ''}';
    phone = '${p['phone'] ?? ''}';
    addresses
      ..clear()
      ..addAll(((p['addresses'] as List?) ?? []).map((e) => Address.fromJson(Map<String, dynamic>.from(e as Map))));
    currentIdx = (p['currentIdx'] as num?)?.toInt() ?? (addresses.isEmpty ? -1 : 0);
    strikes = (p['strikes'] as num?)?.toInt() ?? 0;
  }

  void _storeProfile() {
    if (signedIn && email.isNotEmpty && profileComplete) _profiles[email] = _profileJson();
  }

  // ----- saved on the phone -----
  SharedPreferences? _prefs;
  static const _key = 'nk_state_v1';

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_key);
      if (raw == null) return;
      final j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      theme = AppTheme.values.firstWhere((v) => v.name == j['theme'], orElse: () => AppTheme.light);
      lang = '${j['lang'] ?? 'en'}';
      guest = j['guest'] == true;
      signedIn = j['signedIn'] == true;
      email = '${j['email'] ?? ''}';
      acceptedTerms = j['acceptedTerms'] == true;
      final prof = Map<String, dynamic>.from((j['profiles'] as Map?) ?? {});
      prof.forEach((k, v) => _profiles[k] = Map<String, dynamic>.from(v as Map));
      _readProfile(Map<String, dynamic>.from((j['session'] as Map?) ?? {}));
      if (signedIn && !profileComplete) {
        signedIn = false;
        guest = true;
      }
    } catch (_) {
      // Bad or old data: start fresh.
    }
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;
    _storeProfile();
    p.setString(
        _key,
        jsonEncode({
          'theme': theme.name,
          'lang': lang,
          'guest': guest,
          'signedIn': signedIn,
          'email': email,
          'acceptedTerms': acceptedTerms,
          'profiles': _profiles,
          'session': _profileJson(),
        }));
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    _save();
  }

  // ----- cart: one store at a time -----
  String? cartStoreId;
  final Map<String, int> cart = {};

  int qtyOf(String storeId, String productId) =>
      cartStoreId == storeId ? (cart[productId] ?? 0) : 0;

  /// Returns false when the cart holds another store's items (caller must ask first).
  bool canAddFrom(String storeId) => cartStoreId == null || cartStoreId == storeId || cart.isEmpty;

  void add(String storeId, String productId) {
    if (!canAddFrom(storeId)) return;
    cartStoreId = storeId;
    cart[productId] = (cart[productId] ?? 0) + 1;
    notifyListeners();
  }

  void remove(String productId) {
    final q = (cart[productId] ?? 0) - 1;
    if (q <= 0) {
      cart.remove(productId);
    } else {
      cart[productId] = q;
    }
    if (cart.isEmpty) cartStoreId = null;
    notifyListeners();
  }

  void startNewCart(String storeId, String productId) {
    cart.clear();
    cartStoreId = storeId;
    cart[productId] = 1;
    notifyListeners();
  }

  int get cartCount => cart.values.fold(0, (s, q) => s + q);
  int get cartTotal {
    if (cartStoreId == null) return 0;
    var t = 0;
    cart.forEach((pid, q) {
      final l = listingFor(cartStoreId!, pid);
      if (l != null) t += l.price * q;
    });
    return t;
  }

  int deliveryFeeFor(int itemsTotal, bool door) => door && itemsTotal < kFreeDeliveryMin ? kDeliveryFee : 0;

  // ----- orders (status is simulated in this demo) -----
  final List<Order> orders = [];
  int _orderSeq = 20480;
  final List<Timer> _timers = [];

  Order placeOrder({required bool door}) {
    final sid = cartStoreId!;
    final lines = <OrderLine>[];
    cart.forEach((pid, q) {
      final l = listingFor(sid, pid)!;
      lines.add(OrderLine(pid, q, l.price));
    });
    _orderSeq++;
    final o = Order('NK-$_orderSeq', sid, lines, door, DateTime.now());
    o.fee = deliveryFeeFor(o.total, door);
    orders.insert(0, o);
    cart.clear();
    cartStoreId = null;
    notifyListeners();
    _simulate(o);
    return o;
  }

  void _simulate(Order o) {
    void step(int sec, OrderStatus s) {
      _timers.add(Timer(Duration(seconds: sec), () {
        if (o.status == OrderStatus.cancelled) return;
        o.status = s;
        o.times[s] = DateTime.now();
        if (s == OrderStatus.accepted) {
          notifications.insert(
              0, AppNotification('Order accepted', '${storeById(o.storeId).name} accepted #${o.id}'));
        }
        if (s == OrderStatus.delivered) {
          notifications.insert(0, AppNotification('Delivered', 'Order #${o.id} was delivered'));
        }
        notifyListeners();
      }));
    }

    step(4, OrderStatus.accepted);
    step(9, OrderStatus.packed);
    step(14, OrderStatus.outForDelivery);
    step(20, OrderStatus.delivered);
  }

  /// Customer can cancel only while the order is Placed or Accepted.
  bool canCancel(Order o) => o.status == OrderStatus.placed || o.status == OrderStatus.accepted;

  /// Cancelling after the store accepted counts as 1 of the 3 "not taken" strikes.
  bool cancelCountsAsStrike(Order o) => o.status == OrderStatus.accepted;

  void cancelOrder(Order o) {
    if (!canCancel(o)) return;
    if (cancelCountsAsStrike(o)) strikes++;
    o.status = OrderStatus.cancelled;
    o.times[OrderStatus.cancelled] = DateTime.now();
    notifyListeners();
  }

  // ----- ratings: one per customer per store / thela, editable later -----
  final Map<String, int> ratings = {};
  final Set<String> ratingPromptShown = {};

  bool shouldAskRating(String vendorId) =>
      !ratings.containsKey(vendorId) && !ratingPromptShown.contains(vendorId);

  void markPromptShown(String vendorId) => ratingPromptShown.add(vendorId);

  void rate(String vendorId, int stars) {
    ratings[vendorId] = stars;
    notifyListeners();
  }

  // ----- thela requests for tomorrow -----
  final List<ThelaRequest> requests = [];
  final List<AppNotification> notifications = [];
  int get unreadCount => notifications.where((n) => !n.read).length;

  void addNotification(String title, String body) {
    notifications.insert(0, AppNotification(title, body));
    notifyListeners();
  }

  void markAllRead() {
    if (unreadCount == 0) return;
    for (final n in notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  void sendRequest(String thelaId, String slot, List<String> items) {
    final r = ThelaRequest(thelaId, slot, items);
    requests.insert(0, r);
    notifyListeners();
    _timers.add(Timer(Duration(seconds: 6), () {
      r.accepted = true;
      notifications.insert(
          0,
          AppNotification('${thelaById(thelaId).name} accepted your request',
              'Coming to $address tomorrow ${slot.toLowerCase()}. Pay in person.'));
      notifyListeners();
    }));
  }

  void acceptTerms() {
    acceptedTerms = true;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
