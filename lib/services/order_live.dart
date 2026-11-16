import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

/// The order's live connection while its screen is open: the shop's status changes ("accepted", "packed",
/// "out for delivery"…) and new chat messages arrive the moment they happen, like Blinkit / Zepto, instead
/// of at the next 10-second check. Reconnects by itself when the network drops.
class OrderLive {
  final String base, orderId;
  final String Function() token;
  final void Function(Map<String, dynamic> event) onEvent;
  OrderLive({required this.base, required this.orderId, required this.token, required this.onEvent});

  WebSocketChannel? _ws;
  StreamSubscription? _sub;
  Timer? _ping, _retry;
  bool _gone = false;

  void start() {
    if (_gone || orderId.isEmpty || token().isEmpty) return;
    try {
      final ws = base.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
      _ws = IOWebSocketChannel.connect(Uri.parse('$ws/v1/orders/${Uri.encodeComponent(orderId)}/chat/socket'),
          headers: {'authorization': 'Bearer ${token()}'});
      _sub = _ws!.stream.listen((m) {
        if (m == 'pong') return;
        try {
          final d = jsonDecode('$m');
          if (d is Map) onEvent(Map<String, dynamic>.from(d));
        } catch (_) {}
      }, onDone: _lost, onError: (_) => _lost());
      _ws!.ready.catchError((_) => _lost());
      _ping?.cancel();
      _ping = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          _ws?.sink.add('ping');
        } catch (_) {}
      });
    } catch (_) {
      _lost();
    }
  }

  void _lost() {
    _ping?.cancel();
    _sub?.cancel();
    if (_gone) return;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 4), start);
  }

  void stop() {
    _gone = true;
    _ping?.cancel();
    _retry?.cancel();
    _sub?.cancel();
    try {
      _ws?.sink.close();
    } catch (_) {}
  }
}
