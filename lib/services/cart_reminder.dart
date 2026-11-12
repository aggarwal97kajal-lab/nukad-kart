import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Phone notification for a cart left behind. Scheduled on the phone itself, so it works offline.
class CartReminder {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false, _asked = false;
  static const _id = 7001;

  static Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    _ready = true;
  }

  static Future<void> schedule(String title, String body, DateTime at) async {
    try {
      await _init();
      if (!_asked) {
        _asked = true;
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      await _plugin.zonedSchedule(
        _id,
        title,
        body,
        tz.TZDateTime.from(at.toUtc(), tz.UTC),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'cart_reminders',
            'Cart reminders',
            channelDescription: 'One reminder when items are left in your cart',
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

  static Future<void> cancel() async {
    try {
      await _init();
      await _plugin.cancel(_id);
    } catch (_) {}
  }
}
