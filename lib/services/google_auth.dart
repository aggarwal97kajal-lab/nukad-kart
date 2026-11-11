import 'package:google_sign_in/google_sign_in.dart';
import '../config/keys.dart';

class GoogleUser {
  final String email, name, idToken;
  const GoogleUser(this.email, this.name, this.idToken);
}

class GoogleAuthException implements Exception {
  final String message;
  const GoogleAuthException(this.message);
  @override
  String toString() => message;
}

/// Real Google sign-in (Android account chooser). Returns null when the user closes it.
class GoogleAuth {
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await GoogleSignIn.instance.initialize(serverClientId: googleWebClientId);
    _ready = true;
  }

  Future<GoogleUser?> signIn() async {
    try {
      await _init();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const GoogleAuthException('Google did not return a sign-in token. Try again.');
      return GoogleUser(account.email, account.displayName ?? '', idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw GoogleAuthException('Google sign-in failed (${e.code.name}). ${e.description ?? ''}'.trim());
    }
  }

  Future<void> signOut() async {
    try {
      await _init();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}

final googleAuth = GoogleAuth();
