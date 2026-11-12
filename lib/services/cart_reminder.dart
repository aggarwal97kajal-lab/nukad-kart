import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Phone notifications for a cart left behind (at most 2 a day). Scheduled on the phone itself, so it works offline.
class CartReminder {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false, _asked = false;
  static const _firstId = 7001, _maxCount = 10;

  static Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    _ready = true;
  }

  /// Replaces any planned reminders with [plan] (title, body, time).
  static Future<void> scheduleAll(List<(String, String, DateTime)> plan) async {
    await cancelAll();
    for (var i = 0; i < plan.length && i < _maxCount; i++) {
      await _schedule(_firstId + i, plan[i].$1, plan[i].$2, plan[i].$3);
    }
  }

  static Future<void> _schedule(int id, String title, String body, DateTime at) async {
    try {
      await _init();
      if (!_asked) {
        _asked = true;
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(at.toUtc(), tz.UTC),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'cart_reminders',
            'Cart reminders',
            channelDescription: 'Reminders when items are left in your cart (at most 2 a day)',
            importance: Importance.defaultImportance,
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // Notifications blocked or not supported: nothing else to do.
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _init();
      for (var i = 0; i < _maxCount; i++) {
        await _plugin.cancel(_firstId + i);
      }
    } catch (_) {}
  }
}
