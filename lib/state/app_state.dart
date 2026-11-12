import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';
import '../data/demo_data.dart';
import '../services/bill.dart';
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

  /// 4-digit delivery code, made when the store packs the order.
  /// The delivery person must enter it in the store app to mark the order delivered.
  String? otp;
  int wrongOtpTries = 0;
  OrderStatus status = OrderStatus.placed;
  final Map<OrderStatus, DateTime> times = {};

  /// Bill number from the shop's own series, given when the order is delivered.
  String billNo = '';

  /// Who and where, as it was when the order was placed (for the bill).
  String toName = '', toPhone = '', toAddress = '', toState = '';

  Order(this.id, this.storeId, this.lines, this.door, this.placedAt) {
    times[OrderStatus.placed] = placedAt;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'storeId': storeId,
        'door': door,
        'placedAt': placedAt.toIso8601String(),
        'fee': fee,
        'otp': otp,
        'status': status.name,
        'times': times.map((k, v) => MapEntry(k.name, v.toIso8601String())),
        'billNo': billNo,
        'to': [toName, toPhone, toAddress, toState],
        'lines': lines.map((l) => [l.productId, l.qty, l.price]).toList(),
      };

  static Order fromJson(Map<String, dynamic> j) {
    final o = Order(
      '${j['id']}',
      '${j['storeId']}',
      ((j['lines'] as List?) ?? [])
          .map((e) => OrderLine('${(e as List)[0]}', (e[1] as num).toInt(), (e[2] as num).toInt()))
          .toList(),
      j['door'] == true,
      DateTime.parse('${j['placedAt']}'),
    );
    o.fee = (j['fee'] as num?)?.toInt() ?? 0;
    o.otp = j['otp'] as String?;
    o.status = OrderStatus.values.firstWhere((v) => v.name == j['status'], orElse: () => OrderStatus.placed);
    ((j['times'] as Map?) ?? {}).forEach((k, v) {
      final st = OrderStatus.values.where((x) => x.name == k);
      if (st.isNotEmpty) o.times[st.first] = DateTime.parse('$v');
    });
    o.billNo = '${j['billNo'] ?? ''}';
    final to = (j['to'] as List?) ?? const [];
    if (to.length == 4) {
      o.toName = '${to[0]}';
      o.toPhone = '${to[1]}';
      o.toAddress = '${to[2]}';
      o.toState = '${to[3]}';
    }
    return o;
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
  final double px, py; // old demo map position (kept for saved data)
  final double lat, lng; // map pin (Ola Maps)
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
    this.lat = 28.7158,
    this.lng = 77.1135,
  });

  String get short => [flat, floor, area].where((x) => x.trim().isNotEmpty).join(', ');
  String get full => '$short, $city, $state $pin';

  Map<String, dynamic> toJson() => {
        'flat': flat, 'floor': floor, 'area': area, 'city': city, 'state': state,
        'country': country, 'pin': pin, 'name': name, 'phone': phone, 'label': label, 'px': px, 'py': py, 'lat': lat, 'lng': lng,
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
        lat: (j['lat'] as num?)?.toDouble() ?? 28.7158,
        lng: (j['lng'] as num?)?.toDouble() ?? 77.1135,
      );
}

/// Where a guest browses from until they set an address.
const Address kGuestLocation = Address(area: 'Sector 21, Rohini', pin: '110086');

class AppNotification {
  final String title;
  final String body;
  final DateTime at;
  bool read = false;
  AppNotification(this.title, this.body, {DateTime? at}) : at = at ?? DateTime.now();

  Map<String, dynamic> toJson() => {'t': title, 'b': body, 'at': at.toIso8601String(), 'r': read};
  static AppNotification fromJson(Map<String, dynamic> j) =>
      AppNotification('${j['t']}', '${j['b']}', at: DateTime.tryParse('${j['at']}'))..read = j['r'] == true;
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

  bool phoneVerified = false;

  /// Session token from the Nukad Kart server ('' when signed in offline).
  String apiToken = '';

  /// Fills name, number and addresses from the server (e.g. after reinstalling the app).
  void applyServerProfile(Map<String, dynamic> data) {
    final u = Map<String, dynamic>.from((data['user'] as Map?) ?? {});
    if ('${u['name'] ?? ''}'.trim().isNotEmpty) name = '${u['name']}';
    if ('${u['phone'] ?? ''}'.length == 10) phone = '${u['phone']}';
    if (u['phoneVerified'] == true) phoneVerified = true;
    final list = ((data['addresses'] as List?) ?? []).map((e) => Address.fromJson(Map<String, dynamic>.from(e as Map)));
    if (addresses.isEmpty && list.isNotEmpty) {
      addresses.addAll(list);
      currentIdx = 0;
    }
    notifyListeners();
  }

  bool get profileComplete =>
      name.trim().length >= 2 && phone.length == 10 && phoneVerified && addresses.isNotEmpty;

  void markPhoneVerified() {
    phoneVerified = true;
    notifyListeners();
  }

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
    apiToken = '';
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
    apiToken = '';
    phone = '';
    name = '';
    addresses.clear();
    currentIdx = -1;
    strikes = 0;
    phoneVerified = false;
    cart.clear();
    cartStoreId = null;
    orders.clear();
    notifications.clear();
    ratings.clear();
    billSeq.clear();
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
        'phoneVerified': phoneVerified,
        'orders': orders.take(50).map((o) => o.toJson()).toList(),
        'notifications': notifications.take(60).map((n) => n.toJson()).toList(),
        'ratings': ratings,
        'billSeq': billSeq,
      };

  void _readProfile(Map<String, dynamic> p) {
    name = '${p['name'] ?? ''}';
    phone = '${p['phone'] ?? ''}';
    addresses
      ..clear()
      ..addAll(((p['addresses'] as List?) ?? []).map((e) => Address.fromJson(Map<String, dynamic>.from(e as Map))));
    currentIdx = (p['currentIdx'] as num?)?.toInt() ?? (addresses.isEmpty ? -1 : 0);
    strikes = (p['strikes'] as num?)?.toInt() ?? 0;
    phoneVerified = p['phoneVerified'] == true;
    orders
      ..clear()
      ..addAll(((p['orders'] as List?) ?? []).map((e) {
        try {
          return Order.fromJson(Map<String, dynamic>.from(e as Map));
        } catch (_) {
          return null;
        }
      }).whereType<Order>());
    for (final o in orders) {
      final n = int.tryParse(o.id.replaceFirst('NK-', '')) ?? 0;
      if (n > _orderSeq) _orderSeq = n;
    }
    notifications
      ..clear()
      ..addAll(((p['notifications'] as List?) ?? []).map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map))));
    ratings
      ..clear()
      ..addAll(Map<String, dynamic>.from((p['ratings'] as Map?) ?? {}).map((k, v) => MapEntry(k, (v as num).toInt())));
    billSeq
      ..clear()
      ..addAll(Map<String, dynamic>.from((p['billSeq'] as Map?) ?? {}).map((k, v) => MapEntry(k, (v as num).toInt())));
  }

  /// Last bill number used per shop and financial year, e.g. {"s1|26-27": 231}.
  final Map<String, int> billSeq = {};

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
      apiToken = '${j['apiToken'] ?? ''}';
      acceptedTerms = j['acceptedTerms'] == true;
      final prof = Map<String, dynamic>.from((j['profiles'] as Map?) ?? {});
      prof.forEach((k, v) => _profiles[k] = Map<String, dynamic>.from(v as Map));
      _readProfile(Map<String, dynamic>.from((j['session'] as Map?) ?? {}));
      final c = Map<String, dynamic>.from((j['cart'] as Map?) ?? {});
      final items = Map<String, dynamic>.from((c['items'] as Map?) ?? {});
      if (c['store'] != null && items.isNotEmpty) {
        cartStoreId = '${c['store']}';
        items.forEach((k, v) => cart[k] = (v as num).toInt());
      }
      cartReminderTimes.addAll(((j['cartReminderTimes'] as List?) ?? []).map((e) => DateTime.tryParse('$e')).whereType<DateTime>());
      _cartRemindersLogged.addAll(((j['cartRemindersLogged'] as List?) ?? []).map((e) => '$e'));
      _cartSig = _sig;
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
          'apiToken': apiToken,
          'acceptedTerms': acceptedTerms,
          'profiles': _profiles,
          'session': _profileJson(),
          'cart': {'store': cartStoreId, 'items': cart},
          'cartReminderTimes': cartReminderTimes.map((t) => t.toIso8601String()).toList(),
          'cartRemindersLogged': _cartRemindersLogged.toList(),
        }));
  }

  @override
  void notifyListeners() {
    _cartWatch();
    super.notifyListeners();
    _save();
  }

  // ----- cart reminder: always on, at most 2 a day while items wait in the cart -----
  /// Planned (future) and already sent (past) reminder times for the current cart.
  final List<DateTime> cartReminderTimes = [];
  final Set<String> _cartRemindersLogged = {};
  String _cartSig = '';

  /// Set by main(): schedules / cancels the phone notifications.
  void Function(List<(String, String, DateTime)> plan)? scheduleCartReminders;
  void Function()? cancelCartReminders;

  String get _sig => cartStoreId == null || cart.isEmpty
      ? ''
      : '$cartStoreId:${(cart.keys.toList()..sort()).map((k) => '$k*${cart[k]}').join(',')}';

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Reminders for the cart as it is now: about 30 min after leaving it, again ~4 h later,
  /// then 11 am and 6:30 pm for the next 2 days. Never more than 2 on one day (counting ones
  /// already sent today), and only at times the shop is open. Empty cart: none.
  List<(String, String, DateTime)> cartReminderPlan(DateTime now) {
    if (cartStoreId == null || cart.isEmpty) return const [];
    final st = storeById(cartStoreId!);
    final names = cart.keys.map((id) => productById(id).name).toList();
    final items = '${names.take(2).join(', ')}${names.length > 2 ? ' and ${names.length - 2} more' : ''}';
    final candidates = <DateTime>[now.add(const Duration(minutes: 30)), now.add(const Duration(hours: 4))];
    for (var d = 1; d <= 2; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      candidates
        ..add(day.add(const Duration(hours: 11)))
        ..add(day.add(const Duration(hours: 18, minutes: 30)));
    }
    String key(DateTime t) => '${t.year}-${t.month}-${t.day}';
    final perDay = <String, int>{
      key(now): cartReminderTimes.where((t) => t.isBefore(now) && _sameDay(t, now)).length,
    };
    final out = <(String, String, DateTime)>[];
    for (final at in candidates) {
      if (!st.isOpenAt(at)) continue;
      final k = key(at);
      if ((perDay[k] ?? 0) >= 2) continue;
      perDay[k] = (perDay[k] ?? 0) + 1;
      out.add((
        out.isEmpty ? 'Your cart at ${st.name} is waiting 🛒' : 'Still want these from ${st.name}? 🛒',
        '$items · ₹$cartTotal. The shop is open till ${st.openTill}.',
        at,
      ));
    }
    return out;
  }

  void _cartWatch() {
    final sig = _sig;
    if (sig == _cartSig) return;
    _cartSig = sig;
    final now = DateTime.now();
    // Keep only today's sent ones (they count towards today's 2).
    cartReminderTimes.removeWhere((t) => !(t.isBefore(now) && _sameDay(t, now)));
    cancelCartReminders?.call();
    final plan = cartReminderPlan(now);
    if (plan.isEmpty) return;
    cartReminderTimes.addAll(plan.map((p) => p.$3));
    scheduleCartReminders?.call(plan);
  }

  /// After the app opens: put reminders that already went out into the notification list.
  void logSentCartReminder() {
    if (cart.isEmpty || cartStoreId == null) return;
    final now = DateTime.now();
    final st = storeById(cartStoreId!);
    var added = false;
    for (final at in cartReminderTimes.where((t) => t.isBefore(now))) {
      final k = at.toIso8601String();
      if (_cartRemindersLogged.contains(k)) continue;
      _cartRemindersLogged.add(k);
      notifications.insert(0, AppNotification('Your cart is waiting', '${st.name} · $cartCount item(s) · ₹$cartTotal', at: at));
      added = true;
    }
    if (added) notifyListeners();
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
    final a = current;
    o.toName = name.isNotEmpty ? name : a.name;
    o.toPhone = phone.isNotEmpty ? phone : a.phone;
    o.toAddress = door ? a.full : 'Pickup from the shop';
    o.toState = a.state;
    orders.insert(0, o);
    cart.clear();
    cartStoreId = null;
    notifyListeners();
    _simulate(o);
    return o;
  }

  /// Puts an old order's items back in the cart (replaces the cart). Returns how many items could be added.
  int reorder(Order o) {
    cart.clear();
    cartStoreId = o.storeId;
    for (final l in o.lines) {
      final li = listingFor(o.storeId, l.productId);
      if (li == null || li.stock <= 0) continue;
      cart[l.productId] = l.qty;
    }
    if (cart.isEmpty) cartStoreId = null;
    notifyListeners();
    return cart.length;
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
        if (s == OrderStatus.packed) {
          o.otp = (1000 + math.Random().nextInt(9000)).toString();
          notifications.insert(
              0,
              AppNotification('Delivery code for #${o.id}: ${o.otp}',
                  'Give this code to the delivery person only after you get your items.'));
          onOtp?.call(o);
        }
        notifyListeners();
      }));
    }

    step(4, OrderStatus.accepted);
    step(9, OrderStatus.packed);
    step(14, OrderStatus.outForDelivery); // out for delivery, or ready for pickup
    // Delivered only when the delivery person enters the right code (verifyOtp).
  }

  /// Shows the code to the customer as a pop-up message too.
  void Function(Order o)? onOtp;

  /// Store app side (simulated in this demo): the delivery person types the customer's code.
  bool verifyOtp(Order o, String code) {
    if (o.otp == null || !o.isOpen) return false;
    if (code.trim() != o.otp) {
      o.wrongOtpTries++;
      notifyListeners();
      return false;
    }
    o.status = OrderStatus.delivered;
    final now = DateTime.now();
    o.times[OrderStatus.delivered] = now;
    final key = '${o.storeId}|${financialYear(now)}';
    billSeq[key] = (billSeq[key] ?? 0) + 1;
    o.billNo = billNumber(storeById(o.storeId), now, billSeq[key]!);
    notifications.insert(0, AppNotification('Order delivered', '#${o.id} from ${storeById(o.storeId).name}. Your bill is ready.'));
    notifyListeners();
    return true;
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
