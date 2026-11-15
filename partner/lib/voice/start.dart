import 'package:flutter/material.dart';
import '../api.dart';
import '../l10n.dart';
import 'voice_call.dart';
import 'order_chat.dart';

/// Opens the call screen and calls the customer of this order (kind 'order') or street call (kind 'thela').
/// The customer's phone shows "Delivery partner" (shop orders) or the thela's name, never a number.
Future<void> callCustomer(BuildContext context, String kind, String ref) {
  // One call object, made once (not inside the builder, which runs again each time the screen is redrawn).
  final call = VoiceCall(base: apiBase, token: () => api.token, other: 'Customer');
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VoiceCallScreen(call: call, lang: gLang, startKind: kind, startRef: ref),
    ),
  );
}

/// Chat with the customer on this order (numbers can't be sent).
Future<void> openOrderChat(BuildContext context, String orderId) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => OrderChatScreen(base: apiBase, path: '/v1/partner/orders/$orderId/chat', token: () => api.token, title: '#$orderId', lang: gLang),
    ),
  );
}
