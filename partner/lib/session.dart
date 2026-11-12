import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'push.dart';

/// Login state + the partner's shop, read from the server.
class Session extends ChangeNotifier {
  SharedPreferences? _p;
  String email = '';
  bool admin = false;
  Map<String, dynamic>? store; // null = not registered yet
  List<Map<String, dynamic>> payments = [];
  String phone = '';
  bool phoneVerified = false, trialAvailable = true;
  int selling = 0; // products switched on (thela: items selling today)
  Map<String, dynamic>? staffInfo;
  Map<String, dynamic>? change; // latest asked change of name / address / photo (pending or rejected) // logged in as shop staff (not owner): name, storeName, canOrders
  bool _googleReady = false;
  String? _hw;

  /// Android ID: the same after reinstalling the app on this phone (used for the one-trial-per-phone rule).
  Future<String> deviceId() async {
    if (_hw != null) return _hw!;
    try {
      _hw = await const MethodChannel('nukadpartner/device').invokeMethod<String>('id') ?? '';
    } catch (_) {
      _hw = '';
    }
    return _hw!;
  }

  bool get signedIn => api.token.isNotEmpty;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    api.token = _p!.getString('token') ?? '';
    email = _p!.getString('email') ?? '';
    // Last known shop details: the app opens instantly and refreshes in the background.
    final cached = _p!.getString('me_cache');
    if (api.token.isNotEmpty && cached != null) {
      try {
        _apply(Map<String, dynamic>.from(jsonDecode(cached) as Map));
        hasCache = true;
      } catch (_) {}
    }
    if ((_p!.getString('installId') ?? '').isEmpty) {
      final r = math.Random.secure();
      await _p!.setString('installId', List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join());
    }
  }

  Future<void> _initGoogle() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(serverClientId: googleWebClientId);
    _googleReady = true;
  }

  /// Staff login: the number the store owner added, verified by SMS code (no Google account).
  Future<void> staffLogin(String phone10, String accessToken) async {
    _p ??= await SharedPreferences.getInstance();
    final r = await api.call('POST', '/v1/staff/login', {
      'phone': phone10,
      'accessToken': accessToken,
      'device': {'name': 'Partner app (staff)', 'platform': 'Android', 'id': 'partner-${_p!.getString('installId')}'},
    });
    api.token = '${r['token']}';
    email = '';
    await _p!.setString('token', api.token);
    await _p!.setString('email', '');
    await refresh();
  }

  /// Google account chooser, then server login. Returns false when the person closes the chooser.
  Future<bool> signIn() async {
    await _initGoogle();
    GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      throw ApiError(0, 'google_${e.code.name}');
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const ApiError(0, 'google_no_token');
    final Map<String, dynamic> r;
    try {
      r = await api.call('POST', '/v1/auth/google', {
      'app': 'partner',
      'idToken': idToken,
      'device': {'name': 'Partner app', 'platform': 'Android', 'id': 'partner-${_p!.getString('installId')}'},
      });
    } on ApiError {
      // Let the person pick another Google account next time.
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
      rethrow;
    }
    api.token = '${r['token']}';
    email = account.email;
    await _p!.setString('token', api.token);
    await _p!.setString('email', email);
    await refresh();
    // One Google account = one business type. Chose Shop but this account is a Thela (or the other way)?
    final want = _p!.getString('kind') ?? '';
    if (store != null && want.isNotEmpty && store!['kind'] != want) {
      final was = '${store!['kind']}';
      await signOut();
      throw ApiError(409, was == 'thela' ? 'account_is_thela' : 'account_is_shop');
    }
    return true;
  }

  bool hasCache = false;
  bool _pushStarted = false;

  Future<void> refresh() async {
    final r = await api.call('GET', '/v1/partner/me');
    _apply(r);
    _p?.setString('me_cache', jsonEncode(r));
    notifyListeners();
    if (!_pushStarted) {
      _pushStarted = true;
      setupPush(() => refresh().catchError((_) {}));
    }
  }

  void _apply(Map<String, dynamic> r) {
    change = r['change'] == null ? null : Map<String, dynamic>.from(r['change'] as Map);
    staffInfo = r['staff'] == null ? null : Map<String, dynamic>.from(r['staff'] as Map);
    admin = r['admin'] == true;
    selling = (r['selling'] as num?)?.toInt() ?? 0;
    final u = Map<String, dynamic>.from((r['user'] as Map?) ?? {});
    phone = '${u['phone'] ?? ''}';
    phoneVerified = u['phoneVerified'] == true;
    trialAvailable = u['trialAvailable'] != false;
    store = r['store'] == null ? null : Map<String, dynamic>.from(r['store'] as Map);
    payments = ((r['payments'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void setStore(Map<String, dynamic>? s) {
    store = s;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await api.call('POST', '/v1/me/logout');
    } catch (_) {}
    try {
      await _initGoogle();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    api.token = '';
    email = '';
    store = null;
    staffInfo = null;
    admin = false;
    payments = [];
    phone = '';
    phoneVerified = false;
    hasCache = false;
    _pushStarted = false;
    await _p?.remove('me_cache');
    await _p?.remove('token');
    await _p?.remove('email');
    notifyListeners();
  }
}

final session = Session();
