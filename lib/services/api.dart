import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/keys.dart';
import '../state/app_state.dart';

class ApiException implements Exception {
  final int status;
  final String code;
  const ApiException(this.status, this.code);

  /// Readable message for the customer.
  String get message => switch (code) {
        'phone_in_use' => 'This number is already linked to another account.',
        'email_used_by_partner' => 'This Google account is used for a shop in the Nukad Partner app. Use a different Google account to shop.',
        'phone_not_verified' || 'phone_mismatch' => 'This number could not be confirmed. Send a new code and try again.',
        'not_signed_in' || 'unknown_user' => 'Your session ended. Log in again.',
        'offline' || 'timeout' => 'No internet connection. Try again.',
        _ => 'Something went wrong ($code). Try again.',
      };

  /// Server not reachable, or this part of the server is not switched on yet.
  bool get unavailable => status == 0 || status == 503 || status >= 500;
  @override
  String toString() => 'ApiException($status, $code)';
}

/// Talks to the Nukad Kart server. The session token comes from [AppState.apiToken].
class Api {
  Api({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;
  static const _timeout = Duration(seconds: 12);

  Future<Map<String, dynamic>> _call(String method, String path, {String? token, Object? body}) async {
    final uri = Uri.parse('$apiBase$path');
    final headers = {
      'content-type': 'application/json',
      if (token != null && token.isNotEmpty) 'authorization': 'Bearer $token',
    };
    http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(await _http.send(req).timeout(_timeout));
    } on TimeoutException {
      throw const ApiException(0, 'timeout');
    } catch (_) {
      throw const ApiException(0, 'offline');
    }
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    } catch (_) {
      data = {};
    }
    if (res.statusCode >= 400) throw ApiException(res.statusCode, '${data['error'] ?? 'error'}');
    return data;
  }

  /// Sends Google's ID token; returns {token, user, addresses, profileComplete}.
  Future<Map<String, dynamic>> googleLogin(String idToken, {Map<String, String>? device}) =>
      _call('POST', '/v1/auth/google', body: {'idToken': idToken, if (device != null) 'device': device});

  Future<Map<String, dynamic>> me(String token) => _call('GET', '/v1/me', token: token);

  /// Ends this phone's session on the server.
  Future<void> logout(String token) => _call('POST', '/v1/me/logout', token: token);

  /// Phones where this account is logged in.
  Future<List<Map<String, dynamic>>> sessions(String token) async {
    final d = await _call('GET', '/v1/me/sessions', token: token);
    return ((d['sessions'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> logoutSession(String token, String id) =>
      _call('POST', '/v1/me/sessions/logout', token: token, body: {'id': id});

  Future<void> logoutOtherSessions(String token) => _call('POST', '/v1/me/sessions/logout-others', token: token);

  /// Sends the MSG91 access token so the server can confirm the number itself.
  Future<Map<String, dynamic>> verifyPhone(String token, String accessToken, String phone) =>
      _call('POST', '/v1/me/phone', token: token, body: {'accessToken': accessToken, 'phone': phone});

  Future<Map<String, dynamic>> saveProfile(String token, String name, Address a) =>
      _call('PUT', '/v1/me', token: token, body: {'name': name, 'address': a.toJson()});

  Future<Map<String, dynamic>> saveName(String token, String name) =>
      _call('PUT', '/v1/me', token: token, body: {'name': name});

  /// Removes the profile and addresses on the server. The next Google login starts fresh.
  Future<Map<String, dynamic>> deleteAccount(String token, String reason, String feedback) =>
      _call('POST', '/v1/me/delete', token: token, body: {'reason': reason, 'feedback': feedback});

  Future<Map<String, dynamic>> nearbyStores(double lat, double lng) =>
      _call('GET', '/v1/stores/nearby?lat=$lat&lng=$lng');
}

final api = Api();
