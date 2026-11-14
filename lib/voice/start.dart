import 'package:flutter/material.dart';
import '../config/keys.dart';
import '../l10n.dart';
import '../state/app_state.dart';
import 'voice_call.dart';

/// Opens the call screen and calls the delivery partner of an order (kind 'order', ref = order id; the shop while
/// nobody is assigned) or the thela coming to the street (kind 'thela', ref = call id). Numbers stay hidden.
Future<void> callInApp(BuildContext context, String kind, String ref, {String label = 'Delivery partner'}) {
  final s = AppScope.read(context);
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VoiceCallScreen(call: VoiceCall(base: apiBase, token: () => s.apiToken, other: label), lang: gLang, startKind: kind, startRef: ref),
    ),
  );
}
