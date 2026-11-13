import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api.dart';

/// Firebase app id of the customer app (com.nukadkart.nukad_kart).
const customerFirebaseAppId = '1:173237735756:android:be3b567fc8f89b7b9fbfe9';
const _apiKey = 'AIzaSyBYy_HDbaZnlLttkPrU5HfjN5bri4BQNio';
const _senderId = '173237735756';
const _projectId = 'nukad-kart';

final _local = FlutterLocalNotificationsPlugin();
const _channel = AndroidNotificationChannel('updates', 'Updates',
    description: 'Thela coming, order updates and messages', importance: Importance.high);

bool _ready = false;
String _sentFor = '';

/// Last thing that went wrong while setting up notifications on this phone (shown by "Test notification").
String pushProblem = '';

/// After login: ask for notification permission once and send this phone's token to the server.
/// [onPush] gets every push that arrives while the app is open (title, body, data).
Future<void> setupPush(String apiToken, void Function(String title, String body, Map<String, dynamic> data) onPush, {bool force = false}) async {
  if (apiToken.isEmpty || (_sentFor == apiToken && !force)) return;
  _sentFor = apiToken;
  try {
    if (!_ready) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(apiKey: _apiKey, appId: customerFirebaseAppId, messagingSenderId: _senderId, projectId: _projectId),
      );
      await FirebaseMessaging.instance.requestPermission();
      await _local.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/launcher_icon')));
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_channel);
      // Android shows nothing for a push while the app is open, so show it ourselves.
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) {
          _local.show(m.hashCode, n.title, n.body,
              NotificationDetails(android: AndroidNotificationDetails(_channel.id, _channel.name,
                  channelDescription: _channel.description, importance: Importance.high, priority: Priority.high)));
        }
        onPush(n?.title ?? '', n?.body ?? '', m.data);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((m) => onPush(m.notification?.title ?? '', m.notification?.body ?? '', m.data));
      FirebaseMessaging.instance.onTokenRefresh.listen((t) => api.pushToken(_sentFor, t).catchError((_) {}));
      _ready = true;
    }
    final perm = await FirebaseMessaging.instance.requestPermission();
    if (perm.authorizationStatus == AuthorizationStatus.denied) pushProblem = 'Notifications are turned off for Nukad Kart in phone settings.';
    final t = await FirebaseMessaging.instance.getToken();
    if (t == null) {
      pushProblem = 'This phone did not give a notification token (Google Play services?).';
    } else {
      await api.pushToken(apiToken, t);
      if (perm.authorizationStatus != AuthorizationStatus.denied) pushProblem = '';
    }
  } catch (e) {
    pushProblem = '$e';
    _sentFor = ''; // try again next time
  }
}

/// Listeners for push data (e.g. "thela_coming"), set by screens that care.
final List<void Function(Map<String, dynamic> data)> pushListeners = [];
