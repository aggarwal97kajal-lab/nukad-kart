import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api.dart';

/// Firebase app id of the Partner app (com.nukadkart.partner), from its google-services.json
/// ("mobilesdk_app_id"). Empty = push notifications are off in this build.
const partnerFirebaseAppId = '1:173237735756:android:a7532a4a386387eb9fbfe9';
const _apiKey = 'AIzaSyBYy_HDbaZnlLttkPrU5HfjN5bri4BQNio';
const _senderId = '173237735756';
const _projectId = 'nukad-kart';

bool _ready = false;
const _options = FirebaseOptions(apiKey: _apiKey, appId: partnerFirebaseAppId, messagingSenderId: _senderId, projectId: _projectId);

/// A new shop order while the app is closed or in the background: ring like an alarm.
@pragma('vm:entry-point')
Future<void> partnerBackgroundPush(RemoteMessage m) async {
  try {
    await Firebase.initializeApp(options: _options);
  } catch (_) {}
  await _initLocal();
  if (m.data['type'] == 'order_new') await showOrderAlarm(m.data);
  if (m.data['type'] == 'calls') await showCalls(m.data);
  if (m.data['type'] == 'chats') await showChats(m.data);
  if (m.data['type'] == 'deliver') await showDeliver(m.data);
}

/// Staff: "Deliver #NK-… · collect ₹…" with a Start delivery button (opens the app and starts sharing location).
Future<void> showDeliver(Map<String, dynamic> d) async {
  final id = '${d['id'] ?? ''}';
  try {
    await _local.show(orderNotifId(id) + 1, '${d['title'] ?? 'New delivery'}', '${d['body'] ?? ''}',
        NotificationDetails(android: AndroidNotificationDetails(_channel.id, _channel.name,
            channelDescription: _channel.description, importance: Importance.high, priority: Priority.high,
            actions: const [AndroidNotificationAction('start', 'Start delivery', showsUserInterface: true, cancelNotification: true)])),
        payload: 'deliver:$id');
  } catch (_) {}
}

/// Thela: ONE notification for all unread chat messages, replaced each time; count 0 removes it.
Future<void> showChats(Map<String, dynamic> d) async {
  try {
    final n = int.tryParse('${d['count'] ?? 0}') ?? 0;
    if (n <= 0) {
      await _local.cancel(7002);
      return;
    }
    await _local.show(7002, '${d['title'] ?? 'New message'}', '${d['body'] ?? ''}',
        NotificationDetails(android: AndroidNotificationDetails(_calls.id, _calls.name,
            channelDescription: _calls.description, importance: Importance.high, priority: Priority.high,
            styleInformation: BigTextStyleInformation('${d['body'] ?? ''}'))),
        payload: 'chats');
  } catch (_) {}
}

const _callsNotifId = 7001;

/// Thela: one "customers calling you" notification, updated as calls come and go; count 0 removes it.
Future<void> showCalls(Map<String, dynamic> d) async {
  try {
    final n = int.tryParse('${d['count'] ?? 0}') ?? 0;
    if (n <= 0) {
      await _local.cancel(_callsNotifId);
      return;
    }
    await _local.show(
      _callsNotifId,
      '${d['title'] ?? 'A customer is calling you'}',
      '${d['body'] ?? ''}',
      NotificationDetails(
        android: AndroidNotificationDetails(_calls.id, _calls.name,
            channelDescription: _calls.description, importance: Importance.high, priority: Priority.high, timeoutAfter: 180000, onlyAlertOnce: false),
      ),
      payload: 'calls',
    );
  } catch (_) {}
}

/// Called after login. Asks for notification permission once, sends this phone's token to the server,
/// and calls [onUpdate] when a push arrives (approval, and new orders later) so the screen refreshes itself.
Future<void> setupPush(VoidCallback onUpdate) async {
  if (partnerFirebaseAppId.isEmpty) return;
  try {
    if (!_ready) {
      await Firebase.initializeApp(options: _options);
      await _initLocal();
      FirebaseMessaging.onBackgroundMessage(partnerBackgroundPush);
      // Android shows nothing for a push while the app is open, so show it ourselves.
      FirebaseMessaging.onMessage.listen((m) {
        if (m.data['type'] == 'order_new') {
          showOrderAlarm(m.data);
        } else if (m.data['type'] == 'calls') {
          showCalls(m.data);
        } else if (m.data['type'] == 'chats') {
          showChats(m.data);
        } else if (m.data['type'] == 'deliver') {
          showDeliver(m.data);
        } else {
          _showLocal(m);
        }
        pushTick.value++;
        onUpdate();
      });
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        _opened(m.data);
        pushTick.value++;
      });
      // Opened from a notification while the app was closed.
      final first = await FirebaseMessaging.instance.getInitialMessage();
      if (first != null) _opened(first.data);
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true && launch!.notificationResponse != null) _tapped(launch.notificationResponse!);
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

final _local = FlutterLocalNotificationsPlugin();
const _channel = AndroidNotificationChannel('updates', 'Updates',
    description: 'Approval, location and order updates', importance: Importance.high);
// Thela: customers calling you to their street. Normal sound + vibration (not the shop's order siren).
const _calls = AndroidNotificationChannel('calls', 'Customers calling you',
    description: 'A customer asks your thela to come to their street', importance: Importance.high);

// Shop: new order alarm. A Hindi voice — "नया ऑर्डर आया, अभी चेक करें" — at alarm volume, every 10 seconds
// (the 10 s sound loops), until the order is opened / answered, stopped, or 3 minutes pass.
// New channel id: Android never changes the sound of a channel that already exists on the phone.
final _orders = AndroidNotificationChannel('orders_voice', 'New orders (Hindi voice)',
    description: 'Says “नया ऑर्डर आया, अभी चेक करें” every 10 seconds for up to 3 minutes',
    importance: Importance.max,
    sound: const RawResourceAndroidNotificationSound('order_voice'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]));

int orderNotifId(String orderId) => int.tryParse(orderId.replaceAll(RegExp(r'\D'), '')) ?? orderId.hashCode;

Future<void> showOrderAlarm(Map<String, dynamic> d) async {
  final id = '${d['id'] ?? ''}';
  try {
    await _local.show(
      orderNotifId(id),
      '${d['title'] ?? 'New order'}',
      '${d['body'] ?? 'Open Nukad Kart Partner to accept'}',
      NotificationDetails(
        android: AndroidNotificationDetails(_orders.id, _orders.name,
            channelDescription: _orders.description,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            sound: _orders.sound,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT: the sound repeats until it is dismissed
            timeoutAfter: 180000,
            autoCancel: true,
            actions: const [AndroidNotificationAction('stop', 'Stop ringing', cancelNotification: true)]),
      ),
      payload: id,
    );
  } catch (_) {}
}

/// Accepted / rejected / missed: stop the ringing for that order.
Future<void> stopOrderAlarm(String orderId) async {
  try {
    await _local.cancel(orderNotifId(orderId));
  } catch (_) {}
}

/// "type|id|extra|time" of the last notification the person tapped; the shell opens the matching screen.
final openedPush = ValueNotifier<String>('');

void _opened(Map<String, dynamic> d) =>
    openedPush.value = '${d['type'] ?? ''}|${d['id'] ?? d['chatId'] ?? ''}||${DateTime.now().millisecondsSinceEpoch}';

void _tapped(NotificationResponse r) {
  final p = r.payload ?? '';
  final t = DateTime.now().millisecondsSinceEpoch;
  if (p.startsWith('deliver:')) {
    openedPush.value = 'deliver|${p.substring(8)}|${r.actionId == 'start' ? 'start' : ''}|$t';
  } else if (p.startsWith('NK-')) {
    openedPush.value = 'order_new|$p||$t';
  } else if (p.isNotEmpty) {
    openedPush.value = '$p|||$t';
  }
}

/// Goes up on every push that arrives while the app is open, so screens can reload.
final pushTick = ValueNotifier<int>(0);

Future<void> _initLocal() async {
  try {
    await _local.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/launcher_icon')),
        onDidReceiveNotificationResponse: _tapped);
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_calls);
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_orders);
    // The old siren channel (before the Hindi voice).
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.deleteNotificationChannel('orders_alarm');
  } catch (_) {}
}

void _showLocal(RemoteMessage m) {
  final n = m.notification;
  if (n == null) return;
  try {
    _local.show(
      m.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: m.notification?.android?.channelId == 'calls'
            ? AndroidNotificationDetails(_calls.id, _calls.name, channelDescription: _calls.description, importance: Importance.high, priority: Priority.high)
            : AndroidNotificationDetails(_channel.id, _channel.name,
                channelDescription: _channel.description, importance: Importance.high, priority: Priority.high),
      ),
      payload: '${m.data['type'] ?? ''}',
    );
  } catch (_) {}
}
