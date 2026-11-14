import 'package:flutter/material.dart';
import '../api.dart';
import '../l10n.dart';
import 'voice_call.dart';

/// Opens the call screen and calls the customer of this order (kind 'order') or street call (kind 'thela').
/// The customer's phone shows "Delivery partner" (shop orders) or the thela's name, never a number.
Future<void> callCustomer(BuildContext context, String kind, String ref) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VoiceCallScreen(call: VoiceCall(base: apiBase, token: () => api.token, other: 'Customer'), lang: gLang, startKind: kind, startRef: ref),
    ),
  );
}
