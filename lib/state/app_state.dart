import 'dart:async';
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
  OrderStatus status = OrderStatus.placed;
  final Map<OrderStatus, DateTime> times = {};
  Order(this.id, this.storeId, this.lines, this.door, this.placedAt) {
    times[OrderStatus.placed] = placedAt;
  }
  int get total => lines.fold(0, (s, l) => s + l.price * l.qty);
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

class AppNotification {
  final String title;
  final String body;
  final DateTime at;
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

  // ----- saved things -----
  final Set<String> wishlist = {};
  final Set<String> bookmarks = {};
  final List<String> addresses = ['Flat 12, Block C, Sector 21', 'Shop 4, Block C Market, Sector 21'];
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

  void addAddress(String a) {
    addresses.add(a);
    notifyListeners();
  }

  void useAddress(String a) {
    address = a;
    notifyListeners();
  }

  void removeAddress(String a) {
    addresses.remove(a);
    notifyListeners();
  }

  void setNotif(String k, bool v) {
    notifPrefs[k] = v;
    notifyListeners();
  }

  // ----- user -----
  bool signedIn = false;
  String name = '';
  String email = 'demo.user@gmail.com';
  String phone = '';
  String address = 'Block C, Sector 21';
  int strikes = 0;
  bool acceptedTerms = false;

  void signIn() {
    signedIn = true;
    notifyListeners();
  }

  void saveProfile(String n, String p, String a) {
    name = n;
    phone = p;
    address = a;
    if (!addresses.contains(a)) addresses.insert(0, a);
    notifyListeners();
  }

  void signOut() {
    signedIn = false;
    phone = '';
    name = '';
    cart.clear();
    cartStoreId = null;
    notifyListeners();
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

  void cancelOrder(Order o) {
    if (o.status != OrderStatus.placed) return;
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
