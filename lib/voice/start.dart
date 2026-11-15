import 'package:flutter/material.dart';
import '../config/keys.dart';
import '../l10n.dart';
import '../state/app_state.dart';
import 'voice_call.dart';
import 'order_chat.dart';

/// Opens the call screen and calls, on an order (kind 'order', ref = order id), the shop ([to] 'store') or the
/// delivery partner ([to] 'rider'), or the thela coming to the street (kind 'thela', ref = call id). Numbers stay hidden.
Future<void> callInApp(BuildContext context, String kind, String ref, {String label = 'Delivery partner', String to = ''}) {
  final s = AppScope.read(context);
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VoiceCallScreen(call: VoiceCall(base: apiBase, token: () => s.apiToken, other: label), lang: gLang, startKind: kind, startRef: ref, startTo: to),
    ),
  );
}

/// Chat with the delivery partner / shop on this order (numbers can't be sent).
Future<void> openOrderChat(BuildContext context, String orderId) {
  final s = AppScope.read(context);
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => OrderChatScreen(base: apiBase, path: '/v1/me/orders/$orderId/chat', token: () => s.apiToken, title: '#$orderId', lang: gLang),
    ),
  );
}
