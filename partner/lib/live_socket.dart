import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api.dart';

/// Live chat connection: the server pushes each new message at once. Reconnects on drop;
/// screens still refresh slowly in the background in case the connection is down.
class LiveSocket {
  final String chatId;
  final void Function() onMessage;
  WebSocketChannel? _ch;
  Timer? _ping, _retry;
  bool _closed = false;
  /// For a small "live" dot: true while the live connection is open.
  final connected = ValueNotifier<bool>(false);

  LiveSocket(this.chatId, this.onMessage) {
    _connect();
  }

  void _connect() {
    if (_closed) return;
    try {
      final base = apiBase.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
      _ch = WebSocketChannel.connect(Uri.parse('$base/v1/chat/socket?chat=${Uri.encodeQueryComponent(chatId)}&token=${Uri.encodeQueryComponent(api.token)}'));
      _ch!.stream.listen((m) {
        if (m != 'pong') onMessage();
      }, onDone: _again, onError: (_) => _again(), cancelOnError: true);
      _ch!.ready.then((_) => connected.value = true).catchError((_) => connected.value = false);
      _ping?.cancel();
      _ping = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          _ch?.sink.add('ping');
        } catch (_) {}
      });
    } catch (_) {
      _again();
    }
  }

  void _again() {
    connected.value = false;
    _ping?.cancel();
    if (_closed) return;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 3), _connect);
  }

  /// App came back to the screen: the old connection may be silently dead, so open a fresh one.
  void reconnect() {
    if (_closed) return;
    _ping?.cancel();
    _retry?.cancel();
    try {
      _ch?.sink.close();
    } catch (_) {}
    _connect();
  }

  void close() {
    _closed = true;
    _ping?.cancel();
    _retry?.cancel();
    try {
      _ch?.sink.close();
    } catch (_) {}
  }
}
