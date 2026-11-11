import 'dart:async';
import 'dart:math' as math;

/// Sends and checks the SMS code for the customer's mobile number.
///
/// Demo build: [DemoOtpService] makes the code on the phone and shows it on screen.
/// Real build: swap in an MSG91 version (OTP Widget + `sendotp_flutter_sdk`), where
/// MSG91 sends the SMS, the app gets an access token after verify, and OUR SERVER
/// confirms that token with MSG91 before saving the number. Never trust the app alone.
abstract class OtpService {
  /// Returns a request id for this attempt.
  Future<String> send(String mobile10);

  /// True when [code] is right for [requestId].
  Future<bool> verify(String requestId, String code);

  /// Demo only: the code that was "sent", so the screen can show it.
  String? debugCode(String requestId) => null;
}

class DemoOtpService extends OtpService {
  final Map<String, String> _codes = {};
  final _rnd = math.Random();

  @override
  Future<String> send(String mobile10) async {
    await Future<void>.delayed(Duration(milliseconds: 700));
    final id = '${DateTime.now().millisecondsSinceEpoch}';
    _codes[id] = (100000 + _rnd.nextInt(900000)).toString(); // 6 digits, like MSG91's default
    return id;
  }

  @override
  Future<bool> verify(String requestId, String code) async {
    await Future<void>.delayed(Duration(milliseconds: 500));
    return _codes[requestId] == code.trim();
  }

  @override
  String? debugCode(String requestId) => _codes[requestId];
}

final OtpService otpService = DemoOtpService();
