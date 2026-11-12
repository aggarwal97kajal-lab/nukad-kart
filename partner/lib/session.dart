import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

/// Login state + the partner's shop, read from the server.
class Session extends ChangeNotifier {
  SharedPreferences? _p;
  String email = '';
  bool admin = false;
  Map<String, dynamic>? store; // null = not registered yet
  List<Map<String, dynamic>> payments = [];
  bool _googleReady = false;

  bool get signedIn => api.token.isNotEmpty;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    api.token = _p!.getString('token') ?? '';
    email = _p!.getString('email') ?? '';
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
    final r = await api.call('POST', '/v1/auth/google', {
      'idToken': idToken,
      'device': {'name': 'Partner app', 'platform': 'Android', 'id': 'partner-${_p!.getString('installId')}'},
    });
    api.token = '${r['token']}';
    email = account.email;
    await _p!.setString('token', api.token);
    await _p!.setString('email', email);
    await refresh();
    return true;
  }

  Future<void> refresh() async {
    final r = await api.call('GET', '/v1/partner/me');
    admin = r['admin'] == true;
    store = r['store'] == null ? null : Map<String, dynamic>.from(r['store'] as Map);
    payments = ((r['payments'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    notifyListeners();
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
    admin = false;
    payments = [];
    await _p?.remove('token');
    await _p?.remove('email');
    notifyListeners();
  }
}

final session = Session();
