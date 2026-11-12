import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

const apiBase = 'https://nukad-kart-api.aggarwal97kajal.workers.dev';
const googleWebClientId = '173237735756-8p39j4pk1ekmtuvepo32enp4beqtst9g.apps.googleusercontent.com';

class ApiError implements Exception {
  final int status;
  final String code;
  const ApiError(this.status, this.code);

  String get message => switch (code) {
        'offline' || 'timeout' => 'No internet connection. Try again.',
        'not_signed_in' => 'Your session ended. Log in again.',
        'photo_required' => 'Take a photo of the shop front.',
        'photo_too_big' => 'Photo is too big. Take it again.',
        'location_required' => 'Set the shop location.',
        'timings_required' => 'Enter opening and closing time, like 8 am and 10 pm.',
        'bad_gstin' => 'GSTIN is not valid.',
        'bad_fssai' => 'FSSAI number must be 14 digits.',
        'no_pass' => 'Buy a pass to go live.',
        'blocked' => 'This account is blocked. Contact support.',
        'upi_not_set' => 'Payments are not open yet. Try again later.',
        'payments_paused' => 'Too many failed payments today. Try again tomorrow.',
        'not_admin' => 'Only admins can do this.',
        'bad_upi_id' => 'UPI ID is not valid (example: name@okaxis).',
        _ => 'Something went wrong ($code). Try again.',
      };
  @override
  String toString() => message;
}

class Api {
  String token = '';
  final _http = http.Client();

  Future<Map<String, dynamic>> call(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$apiBase$path'))
      ..headers['content-type'] = 'application/json'
      ..headers['authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);
    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 25)));
    } on TimeoutException {
      throw const ApiError(0, 'timeout');
    } catch (_) {
      throw const ApiError(0, 'offline');
    }
    Map<String, dynamic> data = {};
    try {
      data = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    } catch (_) {}
    if (res.statusCode >= 400) throw ApiError(res.statusCode, '${data['error'] ?? 'error'}');
    return data;
  }
}

final api = Api();
