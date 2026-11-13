import 'package:flutter/material.dart';
import 'api.dart';
import 'push.dart';
import 'rider_location.dart';
import 'screens/chats.dart';
import 'screens/orders.dart';
import 'screens/pass.dart';
import 'screens/report.dart';
import 'screens/shell.dart';
import 'session.dart';
import 'ui.dart';

/// Tapped a notification: open the screen it is about.
Future<void> openFromPush(BuildContext context) async {
  final parts = openedPush.value.split('|');
  // Use a tapped notification once only (it must not open again after logging in as another account).
  openedPush.value = '';
  if (parts.length < 2 || parts[0].isEmpty) return;
  final type = parts[0], id = parts[1], extra = parts.length > 2 ? parts[2] : '';
  final shop = session.store?['kind'] != 'thela' && session.staffInfo == null;
  switch (type) {
    case 'order_new' || 'order' || 'deliver':
      if (shop) shellTab.value = 2;
      if (id.isEmpty || session.store?['kind'] == 'thela') return; // thelas have no shop orders
      try {
        final r = await api.call('GET', '/v1/partner/orders/$id');
        var o = Map<String, dynamic>.from(r['order'] as Map);
        final staff = ((r['staff'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        // "Start delivery" on the notification: out for delivery at once, location starts.
        if (extra == 'start' && o['status'] == 'packed') {
          final x = await api.call('POST', '/v1/partner/orders/$id/out');
          o = Map<String, dynamic>.from(x['order'] as Map);
          if (o['door'] == true) RiderLocation.instance.sync(outDoorOrders: 1);
          if (context.mounted) toast(context, t('Out for delivery. The customer sees you on the map.'));
        }
        if (context.mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o, staff: staff)));
      } on ApiError catch (e) {
        // An old notification for an order this account can't see (or that is gone): just stay on Orders.
        if (context.mounted && e.code != 'not_found') toast(context, e.message);
      }
    case 'chat':
      shellTab.value = 0;
      if (id.isNotEmpty && context.mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(id: id, address: '')));
      }
    case 'pass':
      shellTab.value = 0;
      if (context.mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => const PassScreen()));
    case 'report':
      shellTab.value = 0;
      if (context.mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => const WeekReportScreen()));
    case 'chats' || 'calls' || 'calls_out' || 'call' || 'change' || 'location_stale' || 'test':
      shellTab.value = 0;
  }
}
