import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import '../voice/voice_call.dart';

/// Firebase app id of the customer app (com.nukadkart.nukad_kart).
const customerFirebaseAppId = '1:173237735756:android:be3b567fc8f89b7b9fbfe9';
const _apiKey = 'AIzaSyBYy_HDbaZnlLttkPrU5HfjN5bri4BQNio';
const _senderId = '173237735756';
const _projectId = 'nukad-kart';

final _local = FlutterLocalNotificationsPlugin();
const _channel = AndroidNotificationChannel('updates', 'Updates',
    description: 'Thela coming, order updates and messages', importance: Importance.high);

// A shop's delivery partner or a thela calls in the app: rings with the phone's ringtone (40 s).
final _voice = AndroidNotificationChannel('voice_calls2', 'Calls from shops and thelas',
    description: 'Your delivery partner or a thela calls you in the app (numbers stay hidden)',
    importance: Importance.max,
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 1000, 800, 1000, 800, 1000]));

int _voiceId(String id) => 900000 + (id.hashCode & 0xffff);

/// The ring push also carries a system notification (tag call_<id>, id 0) so a closed app still rings.
/// The app's own full-screen ringing notification takes the same tag and id, so it replaces that one.
String _voiceTag(String id) => 'call_$id';

Future<void> _initLocal() async {
  await _local.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/launcher_icon')),
      onDidReceiveNotificationResponse: _tapResponse);
  final a = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await a?.createNotificationChannel(_channel);
  // A phone that refuses the call channel must still get every other notification.
  try {
    await a?.createNotificationChannel(_voice);
  } catch (_) {}
}

Future<void> showVoiceRing(Map<String, dynamic> d) async {
  final id = '${d['id'] ?? ''}';
  if (id.isEmpty) return;
  try {
    await _local.show(
      0,
      '📞 ${d['from'] ?? 'Nukad Kart'}',
      '${d['title'] ?? ''} · Nukad Kart call',
      NotificationDetails(
        android: AndroidNotificationDetails(_voice.id, _voice.name,
            channelDescription: _voice.description,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.call,
            tag: _voiceTag(id),
            visibility: NotificationVisibility.public,
            fullScreenIntent: true,
            audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
            additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT
            timeoutAfter: 40000,
            ongoing: true,
            autoCancel: false,
            actions: const [
              AndroidNotificationAction('decline', 'Decline', showsUserInterface: true, cancelNotification: true),
              AndroidNotificationAction('answer', 'Answer', showsUserInterface: true, cancelNotification: true),
            ]),
      ),
      payload: 'voice:$id',
    );
  } catch (_) {}
}

Future<void> cancelVoiceRing(String id) async {
  try {
    await _local.cancel(0, tag: _voiceTag(id));
    await _local.cancel(_voiceId(id)); // older builds' ring
  } catch (_) {}
}

/// Ask once for what Android needs to ring over the lock screen (Android 14+: "full-screen notifications").
Future<void> _askFullScreenOnce() async {
  try {
    final p = await SharedPreferences.getInstance();
    if (p.getBool('fsi_asked') == true) return;
    final a = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await p.setBool('fsi_asked', true);
    await a?.requestFullScreenIntentPermission();
  } catch (_) {}
}

/// The app came back on screen: send this phone's notification token again, so the server never ends up
/// without one (a phone with no token can't be rung when the app is closed).
Future<void> refreshPushToken(String apiToken) async {
  if (!_ready || apiToken.isEmpty) return;
  try {
    final t = await FirebaseMessaging.instance.getToken();
    if (t != null) await api.pushToken(apiToken, t);
  } catch (_) {}
}

/// A tapped push about a call opens the ringing screen.
Map<String, dynamic> _openData(Map<String, dynamic> d) =>
    d['type'] == 'voice_call' ? {'type': 'voice', 'id': '${d['id']}', '_t': DateTime.now().millisecondsSinceEpoch} : {...d, '_t': DateTime.now().millisecondsSinceEpoch};

Future<void> _voiceEnded(String id) async {
  await cancelVoiceRing(id);
  final c = currentVoiceCall.value;
  if (c != null && c.id == id) c.remoteEnded();
}

/// A call push while the app is closed or in the background.
@pragma('vm:entry-point')
Future<void> customerBackgroundPush(RemoteMessage m) async {
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(apiKey: _apiKey, appId: customerFirebaseAppId, messagingSenderId: _senderId, projectId: _projectId),
    );
  } catch (_) {}
  try {
    await _initLocal();
  } catch (_) {}
  if (m.data['type'] == 'voice_call') await showVoiceRing(m.data);
  if (m.data['type'] == 'voice_end') await cancelVoiceRing('${m.data['id'] ?? ''}');
}

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
      try {
        await _initLocal();
      } catch (_) {}
      FirebaseMessaging.onBackgroundMessage(customerBackgroundPush);
      // Android shows nothing for a push while the app is open, so show it ourselves.
      FirebaseMessaging.onMessage.listen((m) {
        if (m.data['type'] == 'voice_call') {
          showVoiceRing(m.data);
          openedPush.value = {'type': 'voice', 'id': '${m.data['id']}', '_t': DateTime.now().millisecondsSinceEpoch};
          return;
        }
        if (m.data['type'] == 'voice_end') {
          _voiceEnded('${m.data['id'] ?? ''}');
          return;
        }
        final n = m.notification;
        if (n != null) {
          _local.show(m.hashCode, n.title, n.body,
              NotificationDetails(android: AndroidNotificationDetails(_channel.id, _channel.name,
                  channelDescription: _channel.description, importance: Importance.high, priority: Priority.high)),
              payload: jsonEncode(m.data));
        }
        onPush(n?.title ?? '', n?.body ?? '', m.data);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        onPush('', '', m.data);
        openedPush.value = _openData(m.data);
      });
      // Opened from a notification while the app was closed.
      final first = await FirebaseMessaging.instance.getInitialMessage();
      if (first != null) openedPush.value = _openData(first.data);
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true && launch!.notificationResponse != null) _tapResponse(launch.notificationResponse!);
      FirebaseMessaging.instance.onTokenRefresh.listen((t) => api.pushToken(_sentFor, t).catchError((_) {}));
      _ready = true;
      await _askFullScreenOnce();
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

/// The notification the person tapped (its data); the app opens the matching screen.
final openedPush = ValueNotifier<Map<String, dynamic>?>(null);

void _tapResponse(NotificationResponse r) {
  final p = r.payload ?? '';
  if (p.startsWith('voice:')) {
    openedPush.value = {'type': 'voice', 'id': p.substring(6), 'action': r.actionId ?? '', '_t': DateTime.now().millisecondsSinceEpoch};
    return;
  }
  _tap(p);
}

void _tap(String? payload) {
  if (payload == null || payload.isEmpty) return;
  try {
    openedPush.value = {...Map<String, dynamic>.from(jsonDecode(payload) as Map), '_t': DateTime.now().millisecondsSinceEpoch};
  } catch (_) {}
}

/// Listeners for push data (e.g. "thela_coming"), set by screens that care.
final List<void Function(Map<String, dynamic> data)> pushListeners = [];
