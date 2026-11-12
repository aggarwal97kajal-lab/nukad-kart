import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter/foundation.dart';
import '../config/keys.dart';
import '../data/demo_data.dart';
import '../state/thela_tracker.dart';
import 'api.dart';

/// Real shops, thelas and prices around the customer's address, from the server.
/// Fills the shared lists in data/demo_data.dart so every screen reads the same data.
class LiveData extends ChangeNotifier {
  LiveData._();
  static final LiveData instance = LiveData._();

  bool loading = false;
  bool loaded = false;
  String? error; // 'offline' etc. when the last load failed
  double? _lat, _lng;
  DateTime _productsAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _poll;
  final Map<String, List<Map<String, dynamic>>> _productsOf = {};

  bool get hasAny => kStores.isNotEmpty || kThelas.isNotEmpty;

  /// Load for this address. Thela positions refresh every 20 s while [startPolling] is on.
  Future<void> loadFor(double lat, double lng, {bool force = false}) async {
    final moved = _lat != lat || _lng != lng;
    _lat = lat;
    _lng = lng;
    if (moved) {
      _productsOf.clear();
      loaded = false;
    }
    await _refresh(products: force || moved || DateTime.now().difference(_productsAt) > const Duration(minutes: 2));
  }

  int _fast = 0; // screens that show thelas (Moving sellers tab, a thela's page)
  DateTime _lastPoll = DateTime.now();
  bool _paused = false;
  AppLifecycleListener? _life;

  /// Thelas move and go offline any moment: while a thela screen is open, ask every 10 s;
  /// otherwise every 60 s; never while the app is in the background (saves requests).
  void fast(bool on) {
    _fast = math.max(0, _fast + (on ? 1 : -1));
    if (on && DateTime.now().difference(_lastPoll) > const Duration(seconds: 10)) _tick(force: true);
  }

  void startPolling() {
    _life ??= AppLifecycleListener(
      onPause: () => _paused = true,
      onHide: () => _paused = true,
      onResume: () {
        _paused = false;
        _tick(force: true);
      },
      onShow: () => _paused = false,
    );
    _poll ??= Timer.periodic(const Duration(seconds: 10), (_) => _tick());
  }

  void _tick({bool force = false}) {
    if (_lat == null || _paused) return;
    final every = _fast > 0 ? const Duration(seconds: 10) : const Duration(seconds: 60);
    if (!force && DateTime.now().difference(_lastPoll) < every - const Duration(seconds: 1)) return;
    _lastPoll = DateTime.now();
    _refresh(products: DateTime.now().difference(_productsAt) > const Duration(minutes: 2));
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
    _life?.dispose();
    _life = null;
  }

  Future<void> _refresh({required bool products}) async {
    if (loading || _lat == null) return;
    _lastPoll = DateTime.now();
    loading = true;
    if (!loaded) notifyListeners();
    final lat = _lat!, lng = _lng!;
    try {
      final r = await api.nearbyStores(lat, lng);
      if (lat != _lat || lng != _lng) return; // address changed meanwhile
      final rows = ((r['stores'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      // New sellers always need their list; known ones only every 2 minutes.
      final need = rows.where((s) => products || !_productsOf.containsKey('${s['id']}')).map((s) => '${s['id']}').toList();
      await Future.wait(need.map((id) async {
        try {
          final pr = await api.storeProducts(id);
          _productsOf[id] = ((pr['products'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (_) {
          _productsOf.putIfAbsent(id, () => []);
        }
      }));
      if (products) _productsAt = DateTime.now();
      _apply(rows);
      error = null;
      loaded = true;
    } on ApiException catch (e) {
      error = e.code;
    } catch (_) {
      error = 'error';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _apply(List<Map<String, dynamic>> rows) {
    final stores = <Store>[], thelas = <Thela>[], products = <Product>[], listings = <Listing>[];
    for (final s in rows) {
      final id = '${s['id']}';
      final items = _productsOf[id] ?? const [];
      final photo = s['photo'] == null ? null : '$apiBase${s['photo']}';
      if (s['kind'] == 'thela') {
        thelas.add(Thela(
          id, '${s['name']}', _sells(items), (s['distanceM'] as num).toInt(), 0, s['door'] == true, s['pickup'] == true,
          '', (s['seenAgo'] as num?)?.toInt() ?? 0, items.map(_thelaItem).toList(),
          lat: (s['lat'] as num).toDouble(), lng: (s['lng'] as num).toDouble(), moving: s['moving'] == true, photoUrl: photo,
        ));
        continue;
      }
      stores.add(Store(id, '${s['name']}', (s['distanceM'] as num).toInt(), 0, 0, s['door'] == true, s['pickup'] == true,
          _time('${s['closesAt'] ?? ''}', '11:59 pm'), '${s['phone'] ?? ''}',
          opensAt: _time('${s['opensAt'] ?? ''}', '12 am'),
          address: '${s['address'] ?? ''}',
          gst: switch ('${s['gstType']}') { 'regular' => BillGst.regular, 'composition' => BillGst.composition, _ => BillGst.none },
          fssai: '${s['fssai'] ?? ''}',
          billPrefix: _prefix('${s['name']}'),
          photoUrl: photo,
          lat: (s['lat'] as num).toDouble(),
          lng: (s['lng'] as num).toDouble()));
      for (final p in items) {
        for (final (prod, price) in _shopProducts(p)) {
          products.add(prod);
          listings.add(Listing(id, prod.id, price, (p['stock'] as num?)?.toInt() ?? 99));
        }
      }
    }
    kStores
      ..clear()
      ..addAll(stores);
    kThelas
      ..clear()
      ..addAll(thelas);
    kProducts
      ..clear()
      ..addAll(products);
    kListings
      ..clear()
      ..addAll(listings);
    rememberStores(stores);
    rememberProducts(products);
    ThelaTracker.instance.update(_lat!, _lng!, thelas);
  }

  static String _time(String v, String fallback) => v.trim().isEmpty ? fallback : v.trim();

  static String _prefix(String name) {
    final w = name.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).map((x) => x[0].toUpperCase()).join();
    return w.isEmpty ? 'NK' : (w.length > 4 ? w.substring(0, 4) : w);
  }

  static String _sells(List<Map<String, dynamic>> items) {
    final cats = items.map((p) => '${p['category']}').toSet();
    if (cats.isEmpty) return 'Thela';
    if (cats.length == 1) return cats.first;
    return cats.join(' & ');
  }

  static String _photo(Map<String, dynamic> p) {
    final key = '${p['produceKey'] ?? ''}';
    if (key.isNotEmpty) return 'assets/produce/$key.webp';
    if (p['photo'] != null) return '$apiBase${p['photo']}';
    return switch ('${p['category']}') { 'Vegetables' => '🥦', 'Fruits' => '🍎', _ => '🛍️' };
  }

  static String _unitShort(String u) => switch (u) { 'piece' => 'pc', 'litre' => 'L', _ => u };

  static ThelaItem _thelaItem(Map<String, dynamic> p) {
    final name = '${p['name']}';
    // "Tamatar (Tomato)" → Tamatar / Tomato
    final m = RegExp(r'^(.*?)\s*\((.*)\)$').firstMatch(name);
    final price = p['price'] as num;
    return ThelaItem(m?.group(2) ?? '', m?.group(1) ?? name, price.round(), _unitShort('${p['unit'] ?? 'kg'}'), _photo(p),
        exactPrice: price);
  }

  static String _size(String unit, int n) => switch (unit) {
        'kg' => n >= 1000 ? '${n ~/ 1000} kg' : '$n g',
        'litre' => n >= 1000 ? '${n ~/ 1000} L' : '$n ml',
        'dozen' => '$n dozen',
        'bunch' => n == 1 ? '1 bunch' : '$n bunches',
        _ => n == 1 ? '1 pc' : '$n pcs',
      };

  /// A shop's product as the customer app's shapes. A loose item (sold by weight) becomes one
  /// product per size the shop allows, priced from its per-kg / per-litre / per-piece price.
  static List<(Product, int)> _shopProducts(Map<String, dynamic> p) {
    final id = '${p['id']}', name = '${p['name']}', cat = '${p['category']}', pic = _photo(p);
    final price = (p['price'] as num).toDouble();
    if (p['kind'] != 'loose') {
      final mrp = ((p['mrp'] as num?) ?? price).round();
      final brand = '${p['brand'] ?? ''}';
      return [(Product(id, brand.isNotEmpty && !name.toLowerCase().contains(brand.toLowerCase()) ? '$brand $name' : name, '${p['size']}', pic, cat, mrp), price.round())];
    }
    final unit = '${p['unit'] ?? 'kg'}';
    final opts = ((p['options'] as List?) ?? const [1]).map((e) => (e as num).toInt());
    return [
      for (final n in opts)
        () {
          final v = unit == 'kg' || unit == 'litre' ? price * n / 1000 : price * n;
          final pr = v.round();
          return (Product('${id}_$n', name, _size(unit, n), pic, cat, pr), pr);
        }(),
    ];
  }
}
