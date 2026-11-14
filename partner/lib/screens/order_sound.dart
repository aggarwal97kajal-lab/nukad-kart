import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../push.dart';
import '../ui.dart';

/// Settings → New order sound: Hindi voice ("नया ऑर्डर आया, अभी चेक करें") or only the phone's bell.
/// Both repeat every 10 seconds until the order is accepted or rejected.
Future<void> showOrderSoundSheet(BuildContext context) async {
  var cur = await orderSound();
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    backgroundColor: kCard,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        Future<void> pick(String v) async {
          final p = await SharedPreferences.getInstance();
          await p.setString('order_sound', v);
          set(() => cur = v);
        }

        Widget tile(String v, String title, String sub, IconData icon) => ListTile(
              leading: Icon(icon, color: kAct),
              title: Text(title, style: tx(15.5, weight: FontWeight.w800)),
              subtitle: Text(sub, style: tx(12.5, color: kMute)),
              trailing: Icon(cur == v ? Icons.radio_button_checked : Icons.radio_button_off, color: cur == v ? kAct : kMute),
              onTap: () => pick(v),
            );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(tr('New order sound'), style: tx(17, weight: FontWeight.w800)),
              ),
              tile('voice', tr('Hindi voice'), '“नया ऑर्डर आया, अभी चेक करें”', Icons.record_voice_over_outlined),
              tile('bell', tr('Bell only'), tr('The phone’s notification sound'), Icons.notifications_active_outlined),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Text(tr('It rings every 10 seconds until you accept or reject, also with the app open. It uses the phone’s notification volume.'),
                    style: tx(12.5, color: kMute)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Btn(tr('Test the sound'), outline: true, onTap: testOrderSound),
              ),
            ]),
          ),
        );
      },
    ),
  );
}
