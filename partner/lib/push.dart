import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'voice/voice_call.dart';

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
  if (m.data['type'] == 'voice_call') await showVoiceRing(m.data);
  if (m.data['type'] == 'voice_end') await stopVoiceRing('${m.data['id'] ?? ''}');
}

// In-app call from a customer: rings with the phone's ringtone until answered, declined or 40 s pass.
final _voice = AndroidNotificationChannel('voice_calls2', 'Calls from customers',
    description: 'A customer calls you in the app (your number stays hidden)',
    importance: Importance.max,
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 1000, 800, 1000, 800, 1000]));

int voiceNotifId(String id) => 900000 + (id.hashCode & 0xffff);

/// The ring push also carries a system notification (tag call_<id>, id 0) so a closed app still rings.
/// The app's own full-screen ringing notification takes the same tag and id, so it replaces that one.
String _voiceTag(String id) => 'call_$id';

Future<void> showVoiceRing(Map<String, dynamic> d) async {
  final id = '${d['id'] ?? ''}';
  if (id.isEmpty) return;
  try {
    await _local.show(
      0,
      '📞 ${d['caller'] ?? d['from'] ?? 'Customer'}',
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

/// Stop the ringing only (answered / declined on the call screen).
Future<void> cancelVoiceRing(String id) async {
  try {
    await _local.cancel(0, tag: _voiceTag(id));
    await _local.cancel(voiceNotifId(id)); // older builds' ring
  } catch (_) {}
}

/// The app came back on screen: send this phone's notification token again, so the server never ends up
/// without one (a phone with no token can't be rung when the app is closed).
Future<void> refreshPushToken() async {
  if (!_ready || api.token.isEmpty) return;
  try {
    final t = await FirebaseMessaging.instance.getToken();
    if (t != null) await _send(t);
  } catch (_) {}
}

/// Ask once for what Android needs to ring over the lock screen (Android 14+: "full-screen notifications").
Future<void> _askFullScreenOnce() async {
  try {
    final p = await SharedPreferences.getInstance();
    if (p.getBool('fsi_asked') == true) return;
    await p.setBool('fsi_asked', true);
    await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestFullScreenIntentPermission();
  } catch (_) {}
}

/// The caller hung up before an answer: stop ringing and close the screen.
Future<void> stopVoiceRing(String id) async {
  await cancelVoiceRing(id);
  final c = currentVoiceCall.value;
  if (c != null && c.id == id) c.remoteEnded();
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
        } else if (m.data['type'] == 'voice_call') {
          // App open: go straight to the ringing call screen (the notification rings too).
          showVoiceRing(m.data);
          openedPush.value = 'voice|${m.data['id']}||${DateTime.now().millisecondsSinceEpoch}';
        } else if (m.data['type'] == 'voice_end') {
          stopVoiceRing('${m.data['id'] ?? ''}');
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
      await _askFullScreenOnce();
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

// Shop: new order ring. Plays as a normal notification sound (phone's notification volume, not the alarm),
// and repeats (FLAG_INSISTENT; the voice file is 10 s) until the order is accepted / rejected or the 5-minute
// window ends. Two sounds, chosen in Settings: the Hindi voice "नया ऑर्डर आया, अभी चेक करें", or the phone's bell.
// New channel ids: Android never changes the sound or audio usage of a channel that already exists on the phone.
final _ordersVoice = AndroidNotificationChannel('orders_voice3', 'New orders (Hindi voice)',
    description: 'Says “नया ऑर्डर आया, अभी चेक करें” every 10 seconds until you accept',
    importance: Importance.max,
    sound: const RawResourceAndroidNotificationSound('order_voice'),
    audioAttributesUsage: AudioAttributesUsage.notification,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]));
final _ordersBell = AndroidNotificationChannel('orders_bell', 'New orders (bell)',
    description: 'The phone\'s notification sound, repeating until you accept',
    importance: Importance.max,
    audioAttributesUsage: AudioAttributesUsage.notification,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]));

/// 'voice' (Hindi awaaz, default) or 'bell' (sirf ghanti). Saved on the phone; read fresh because a
/// background push runs in its own isolate.
Future<String> orderSound() async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    return p.getString('order_sound') ?? 'voice';
  } catch (_) {
    return 'voice';
  }
}

int orderNotifId(String orderId) => int.tryParse(orderId.replaceAll(RegExp(r'\D'), '')) ?? orderId.hashCode;

/// Title/body of each order that is ringing, so the in-app ringer can show it again.
final _ringing = <String, (String, String)>{};
Timer? _ringTimer;

/// True while the app is on screen (main.dart sets it from the app lifecycle).
bool partnerAppOpen = false;

Future<void> showOrderAlarm(Map<String, dynamic> d) async {
  final id = '${d['id'] ?? ''}';
  if (id.isEmpty) return;
  final title = '${d['title'] ?? 'New order'}';
  final body = '${d['body'] ?? 'Open Nukad Kart Partner to accept'}';
  _ringing[id] = (title, body);
  await _ring(id, title, body);
  _startRinger();
}

Future<void> _ring(String id, String title, String body) async {
  final ch = await orderSound() == 'bell' ? _ordersBell : _ordersVoice;
  try {
    await _local.show(
      orderNotifId(id),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(ch.id, ch.name,
            channelDescription: ch.description,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.call,
            sound: ch.sound,
            playSound: true,
            audioAttributesUsage: AudioAttributesUsage.notification,
            additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT: the sound repeats until it is removed
            timeoutAfter: 300000, // the shop's 5-minute window
            ongoing: true, // a swipe does not silence an order; accept / reject / Stop does
            autoCancel: false,
            actions: const [AndroidNotificationAction('stop', 'Stop ringing', cancelNotification: true)]),
      ),
      payload: id,
    );
  } catch (_) {}
}

/// While the app is open, check every 10 seconds: an order that is still new but whose notification is gone
/// (opened from the notification, or the shade was pulled) rings again. Orders that are no longer new stop.
void _startRinger() {
  _ringTimer ??= Timer.periodic(const Duration(seconds: 10), (_) => _tick());
}

bool _ticking = false;
Future<void> _tick() async {
  if (_ringing.isEmpty) {
    _ringTimer?.cancel();
    _ringTimer = null;
    return;
  }
  if (!partnerAppOpen || _ticking) return;
  _ticking = true;
  try {
    final r = await api.call('GET', '/v1/partner/orders?tab=new');
    final still = <String>{for (final o in (r['orders'] as List? ?? [])) '${(o as Map)['id']}'};
    for (final id in _ringing.keys.toList()) {
      if (!still.contains(id)) await stopOrderAlarm(id);
    }
    final active = await _local
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.getActiveNotifications() ??
        const <ActiveNotification>[];
    final shown = {for (final a in active) a.id};
    for (final e in _ringing.entries.toList()) {
      if (!shown.contains(orderNotifId(e.key))) await _ring(e.key, e.value.$1, e.value.$2);
    }
  } catch (_) {
  } finally {
    _ticking = false;
  }
}

/// The New tab loaded: every order there keeps ringing until it is answered (also after the app was
/// opened from a closed state, when the background ring did not reach this isolate).
void ringNewOrders(List<Map<String, dynamic>> orders) {
  for (final o in orders) {
    final id = '${o['id']}';
    if (o['status'] == 'placed' && !_ringing.containsKey(id)) {
      _ringing[id] = ('New order ${o['id']}', 'Open Nukad Kart Partner to accept');
    }
  }
  if (_ringing.isNotEmpty) _startRinger();
}

/// Accepted / rejected / missed / Stop pressed: stop the ringing for that order.
Future<void> stopOrderAlarm(String orderId) async {
  _ringing.remove(orderId);
  try {
    await _local.cancel(orderNotifId(orderId));
  } catch (_) {}
}

/// Play the chosen order sound once, from Settings ("Test").
Future<void> testOrderSound() async {
  await _ring('TEST', 'Test: new order', 'This is how a new order sounds');
  Timer(const Duration(seconds: 12), () => _local.cancel(orderNotifId('TEST')));
}

/// "type|id|extra|time" of the last notification the person tapped; the shell opens the matching screen.
final openedPush = ValueNotifier<String>('');

void _opened(Map<String, dynamic> d) => openedPush.value =
    '${d['type'] == 'voice_call' ? 'voice' : (d['type'] ?? '')}|${d['id'] ?? d['chatId'] ?? ''}||${DateTime.now().millisecondsSinceEpoch}';

void _tapped(NotificationResponse r) {
  final p = r.payload ?? '';
  if (p == 'TEST') return;
  if (p.startsWith('voice:')) {
    openedPush.value = 'voice|${p.substring(6)}|${r.actionId ?? ''}|${DateTime.now().millisecondsSinceEpoch}';
    return;
  }
  if (r.actionId == 'stop') {
    _ringing.remove(p);
    return;
  }
  final t = DateTime.now().millisecondsSinceEpoch;
  if (p.startsWith('deliver:')) {
    openedPush.value = 'deliver|${p.substring(8)}|${r.actionId == 'start' ? 'start' : ''}|$t';
  } else if (p.startsWith('NK-')) {
    openedPush.value = 'order_new|$p||$t';
  } else if (p.startsWith('order_chat|')) {
    openedPush.value = '$p||$t';
  } else if (p.isNotEmpty) {
    openedPush.value = '$p|||$t';
  }
}

/// Goes up on every push that arrives while the app is open, so screens can reload.
final pushTick = ValueNotifier<int>(0);

Future<void> _initLocal() async {
  try {
    await _local.initialize(const InitializationSettings(android: AndroidInitializationSettings('ic_stat_nukad')),
        onDidReceiveNotificationResponse: _tapped);
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_calls);
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_ordersVoice);
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_ordersBell);
    try {
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_voice);
    } catch (_) {}
    // Old order channels (siren, then the voice at alarm volume).
    for (final old in ['orders_alarm', 'orders_voice', 'orders_voice2']) {
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.deleteNotificationChannel(old);
    }
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
      payload: m.data['type'] == 'order_chat' ? 'order_chat|${m.data['id'] ?? ''}' : '${m.data['type'] ?? ''}',
    );
  } catch (_) {}
}
