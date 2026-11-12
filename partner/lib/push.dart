import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api.dart';

/// Firebase app id of the Partner app (com.nukadkart.partner), from its google-services.json
/// ("mobilesdk_app_id"). Empty = push notifications are off in this build.
const partnerFirebaseAppId = '1:173237735756:android:a7532a4a386387eb9fbfe9';
const _apiKey = 'AIzaSyBYy_HDbaZnlLttkPrU5HfjN5bri4BQNio';
const _senderId = '173237735756';
const _projectId = 'nukad-kart';

bool _ready = false;

/// Called after login. Asks for notification permission once, sends this phone's token to the server,
/// and calls [onUpdate] when a push arrives (approval, and new orders later) so the screen refreshes itself.
Future<void> setupPush(VoidCallback onUpdate) async {
  if (partnerFirebaseAppId.isEmpty) return;
  try {
    if (!_ready) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: _apiKey,
          appId: partnerFirebaseAppId,
          messagingSenderId: _senderId,
          projectId: _projectId,
        ),
      );
      FirebaseMessaging.onMessage.listen((_) => onUpdate());
      FirebaseMessaging.onMessageOpenedApp.listen((_) => onUpdate());
      FirebaseMessaging.instance.onTokenRefresh.listen(_send);
      _ready = true;
    }
    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _send(token);
  } catch (_) {
    // No push on this phone (no Google Play services, permission denied…): the app still works, pull to refresh.
  }
}

Future<void> _send(String token) async {
  try {
    await api.call('POST', '/v1/partner/push-token', {'token': token});
  } catch (_) {}
}
