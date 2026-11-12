import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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
        'photo_location_required' => 'Take the shop photo at the shop with location (GPS) on.',
        'address_far' => 'The map pin is more than 50 m from where the shop photo was taken. Move the pin to your shop.',
        'agreement_needed' => 'Sign the partner agreement first.',
        'agreement_changed' => 'The agreement was updated. Open it again and sign the new version.',
        'agree_required' => 'Tick “I have read and agree” first.',
        'signer_name_required' => 'Type your full name.',
        'signature_required' => 'Sign in the box with your finger.',
        'register_first' => 'Register your shop first.',
        'email_used_by_customer' => 'This Google account is already used in the Nukad Kart customer app. Use a different Google account for your shop.',
        'phone_first' => 'Verify your mobile number first.',
        'bad_phone' => 'Enter a valid 10-digit mobile number.',
        'phone_in_use' => 'This number is already linked to another partner account.',
        'phone_not_verified' || 'phone_mismatch' => 'This number could not be confirmed. Send a new code and try again.',
        'bad_pan' => 'PAN is not valid (example: ABCDE1234F).',
        'bad_aadhaar' => 'Enter the last 4 digits of Aadhaar.',
        'gstin_pan_mismatch' => 'GSTIN does not match your PAN.',
        'shop_no_required' => 'Enter the shop number.',
        'pin_area_missing' => 'The map could not find the area or PIN here. Move the pin a little and try again.',
        'doc_too_big' => 'File is bigger than 2 MB. Take a smaller photo or compress the PDF.',
        'doc_must_be_jpg_or_pdf' => 'Only JPG photos or PDF files can be uploaded.',
        'docs_missing' => 'Upload all required documents first.',
        'docs_locked' => 'Documents can’t be changed while Nukad team is checking them.',
        'not_verified' => 'Nukad team is still verifying your shop.',
        'already_approved' => 'Your shop is already approved. Contact support to change details.',
        'reason_required' => 'Write a reason.',
        _ => 'Something went wrong ($code). Try again.',
      };
  @override
  String toString() => message;
}

class Api {
  String token = '';
  final http.Client _http = http.Client();

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

extension ApiBytes on Api {
  /// Upload raw bytes (document parts). No base64, so less to send.
  Future<Map<String, dynamic>> putBytes(String path, List<int> data) async {
    final req = http.Request('PUT', Uri.parse('$apiBase$path'))
      ..headers['content-type'] = 'application/octet-stream'
      ..headers['authorization'] = 'Bearer $token'
      ..bodyBytes = data;
    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 60)));
    } on TimeoutException {
      throw const ApiError(0, 'timeout');
    } catch (_) {
      throw const ApiError(0, 'offline');
    }
    Map<String, dynamic> out = {};
    try {
      out = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    } catch (_) {}
    if (res.statusCode >= 400) throw ApiError(res.statusCode, '${out['error'] ?? 'error'}');
    return out;
  }

  /// Raw file (admin document view).
  Future<(Uint8List, String)> bytes(String path) async {
    try {
      final res = await http.get(Uri.parse('$apiBase$path'), headers: {'authorization': 'Bearer $token'}).timeout(const Duration(seconds: 40));
      if (res.statusCode >= 400) throw ApiError(res.statusCode, 'error');
      return (res.bodyBytes, res.headers['content-type'] ?? '');
    } on TimeoutException {
      throw const ApiError(0, 'timeout');
    }
  }
}

final api = Api();
