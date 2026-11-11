import 'dart:async';
import 'dart:math' as math;
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';

/// Sends and checks the SMS code for the customer's mobile number.
///
/// Live build uses MSG91's OTP Widget (default template, no DLT needed for testing).
/// IMPORTANT before launch: after verify, MSG91 returns an access token. Our server must
/// confirm it with MSG91 (`/api/v5/widget/verifyAccessToken`, using the AuthKey kept only on
/// the server) before trusting the number. Until the backend exists, the app trusts MSG91's
/// verify response directly — fine for testing, not for launch.
abstract class OtpService {
  int get codeLength;

  /// Sends the code. Returns a request id. Throws [OtpException] with a readable message.
  Future<String> send(String mobile10);

  /// Sends again by SMS.
  Future<void> resend(String requestId);

  /// True when [code] is right.
  Future<bool> verify(String requestId, String code);

  /// Demo only: the code that was "sent", so the screen can show it.
  String? debugCode(String requestId) => null;

  /// Token from the last successful verify; the server confirms it with MSG91.
  String? get lastAccessToken => null;
}

class OtpException implements Exception {
  final String message;
  OtpException(this.message);
  @override
  String toString() => message;
}

/// MSG91 OTP Widget. Widget id and token are meant for apps (not the account AuthKey).
class Msg91OtpService extends OtpService {
  static const widgetId = '366b6b714576353438393333';
  static const tokenAuth = '589166T1ZMl90d86af4a701P1';
  bool _ready = false;

  /// The verified token from the last successful verify — sent to our server, which checks it with MSG91.
  @override
  String? lastAccessToken;

  @override
  int get codeLength => 4; // matches the widget's "OTP Length: 4 digits"

  void _init() {
    if (_ready) return;
    OTPWidget.initializeWidget(widgetId, tokenAuth);
    _ready = true;
  }

  Map<String, dynamic> _asMap(dynamic r) {
    if (r is Map) return Map<String, dynamic>.from(r);
    return {'type': 'error', 'message': '$r'};
  }

  bool _ok(Map<String, dynamic> m) => '${m['type'] ?? m['status'] ?? ''}'.toLowerCase() == 'success';

  String _msg(Map<String, dynamic> m, String fallback) {
    final v = m['message'] ?? m['msg'] ?? m['error'];
    final s = v == null ? '' : '$v';
    return s.isEmpty ? fallback : s;
  }

  @override
  Future<String> send(String mobile10) async {
    _init();
    try {
      final m = _asMap(await OTPWidget.sendOTP({'identifier': '91$mobile10'}));
      if (!_ok(m)) throw OtpException(_msg(m, 'Could not send the code. Try again.'));
      final id = '${m['reqId'] ?? m['request_id'] ?? m['message'] ?? ''}';
      if (id.isEmpty) throw OtpException('Could not send the code. Try again.');
      return id;
    } on OtpException {
      rethrow;
    } catch (e) {
      throw OtpException('Could not send the code. Check your internet and try again.');
    }
  }

  @override
  Future<void> resend(String requestId) async {
    _init();
    try {
      final m = _asMap(await OTPWidget.retryOTP({'reqId': requestId, 'retryChannel': 11}));
      if (!_ok(m)) throw OtpException(_msg(m, 'Could not resend. Try again in a moment.'));
    } on OtpException {
      rethrow;
    } catch (e) {
      throw OtpException('Could not resend. Check your internet and try again.');
    }
  }

  @override
  Future<bool> verify(String requestId, String code) async {
    _init();
    try {
      final m = _asMap(await OTPWidget.verifyOTP({'reqId': requestId, 'otp': code.trim()}));
      if (_ok(m)) {
        lastAccessToken = '${m['message'] ?? ''}';
        return true;
      }
      return false;
    } catch (_) {
      throw OtpException('Could not check the code. Check your internet and try again.');
    }
  }
}

/// Offline stand-in (used in tests): makes the code on the phone.
class DemoOtpService extends OtpService {
  final Map<String, String> _codes = {};
  final _rnd = math.Random();

  @override
  int get codeLength => 4;

  @override
  Future<String> send(String mobile10) async {
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    _codes[id] = (1000 + _rnd.nextInt(9000)).toString();
    return id;
  }

  @override
  Future<void> resend(String requestId) async {}

  @override
  Future<bool> verify(String requestId, String code) async => _codes[requestId] == code.trim();

  @override
  String? debugCode(String requestId) => _codes[requestId];
}

final OtpService otpService = Msg91OtpService();
