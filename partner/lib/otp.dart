import 'l10n.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';

/// MSG91 SMS code (same OTP widget as the customer app). The server re-checks the token with MSG91.
abstract class OtpService {
  int get codeLength;
  Future<String> send(String mobile10);
  Future<void> resend(String requestId);
  Future<bool> verify(String requestId, String code);
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
      if (!_ok(m)) throw OtpException(_msg(m, tr('Could not send the code. Try again.')));
      final id = '${m['reqId'] ?? m['request_id'] ?? m['message'] ?? ''}';
      if (id.isEmpty) throw OtpException(tr('Could not send the code. Try again.'));
      return id;
    } on OtpException {
      rethrow;
    } catch (e) {
      throw OtpException(tr('Could not send the code. Check your internet and try again.'));
    }
  }

  @override
  Future<void> resend(String requestId) async {
    _init();
    try {
      final m = _asMap(await OTPWidget.retryOTP({'reqId': requestId, 'retryChannel': 11}));
      if (!_ok(m)) throw OtpException(_msg(m, tr('Could not resend. Try again in a moment.')));
    } on OtpException {
      rethrow;
    } catch (e) {
      throw OtpException(tr('Could not resend. Check your internet and try again.'));
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
      throw OtpException(tr('Could not check the code. Check your internet and try again.'));
    }
  }
}

final OtpService otpService = Msg91OtpService();
