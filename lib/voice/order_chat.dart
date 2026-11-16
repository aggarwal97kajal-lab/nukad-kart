// Chat on a shop order (same file in the customer and the Partner app). Numbers can't be sent; the other side
// gets a notification. New messages and "read" arrive at once over the order's live socket; a sent message shows
// at once (clock → ✓ sent → blue ✓✓ read). If the socket is down, the screen asks every 4 seconds instead.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

String chatText(String key, String lang) {
  const hi = {
    'Chat': 'चैट',
    'Write a message…': 'मैसेज लिखें…',
    'No messages yet. Say where to come, which gate, what is missing…': 'अभी कोई मैसेज नहीं। कहाँ आना है, कौन सा गेट, क्या कम है… लिखें।',
    'Chat is closed for this order.': 'इस ऑर्डर की चैट बंद हो गई है।',
    'no_numbers': 'चैट में फ़ोन नंबर नहीं भेज सकते। ऐप से कॉल करें।',
    'error': 'मैसेज नहीं गया। फिर कोशिश करें।',
  };
  const hg = {
    'Chat': 'Chat',
    'Write a message…': 'Message likho…',
    'No messages yet. Say where to come, which gate, what is missing…': 'Abhi koi message nahi. Kahan aana hai, kaunsa gate, kya kam hai… likho.',
    'Chat is closed for this order.': 'Is order ki chat band ho gayi hai.',
    'no_numbers': 'Chat mein phone number nahi bhej sakte. App se call karo.',
    'error': 'Message nahi gaya. Phir try karo.',
  };
  const en = {
    'No messages yet. Say where to come, which gate, what is missing…': 'No messages yet. Say where to come, which gate, what is missing…',
    'no_numbers': 'Phone numbers can’t be sent in chat. Call in the app instead.',
    'error': 'Message not sent. Try again.',
  };
  final m = lang == 'hi' ? hi : (lang == 'hg' ? hg : en);
  return m[key] ?? en[key] ?? key;
}

class OrderChatScreen extends StatefulWidget {
  final String base, path, title, lang; // path: /v1/me/orders/<id>/chat or /v1/partner/orders/<id>/chat
  final String Function() token;
  const OrderChatScreen({super.key, required this.base, required this.path, required this.token, required this.title, required this.lang});
  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  final text = TextEditingController();
  final scroll = ScrollController();
  List<Map<String, dynamic>> msgs = [];
  bool open = true, loaded = false;
  int otherReadAt = 0;
  Timer? _poll, _ping, _retry;
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  bool _live = false, _gone = false;
  int _tmp = 0;

  String w(String k) => chatText(k, widget.lang);
  Map<String, String> get _h => {'content-type': 'application/json', 'authorization': 'Bearer ${widget.token()}'};
  String get _me => widget.path.contains('/me/') ? 'c' : 's';
  String get _orderId => RegExp(r'/orders/([^/]+)/chat').firstMatch(widget.path)?.group(1) ?? '';

  @override
  void initState() {
    super.initState();
    _load();
    _connect();
    // Backup when the live socket is down: ask every 4 s (every 15 s while it is up, in case one was missed).
    _poll = Timer.periodic(const Duration(seconds: 4), (t) {
      if (!_live || t.tick % 4 == 0) _load();
    });
  }

  @override
  void dispose() {
    _gone = true;
    _poll?.cancel();
    _ping?.cancel();
    _retry?.cancel();
    _wsSub?.cancel();
    try {
      _ws?.sink.close();
    } catch (_) {}
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _connect() {
    if (_gone || _orderId.isEmpty) return;
    try {
      final ws = widget.base.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
      _ws = IOWebSocketChannel.connect(Uri.parse('$ws/v1/orders/${Uri.encodeComponent(_orderId)}/chat/socket'),
          headers: {'authorization': 'Bearer ${widget.token()}'});
      _wsSub = _ws!.stream.listen((m) {
        _live = true;
        _onLive('$m');
      }, onDone: _lost, onError: (_) => _lost());
      _ping?.cancel();
      _ping = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          _ws?.sink.add('ping');
        } catch (_) {}
      });
      _ws!.ready.then((_) {
        _live = true;
        _load(); // anything sent while connecting
      }).catchError((_) => _lost());
    } catch (_) {
      _lost();
    }
  }

  void _lost() {
    _live = false;
    _ping?.cancel();
    _wsSub?.cancel();
    if (_gone) return;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 3), _connect);
  }

  void _onLive(String raw) {
    if (raw == 'pong' || !mounted) return;
    Map<String, dynamic> m;
    try {
      m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return;
    }
    if (m['type'] == 'message') {
      final id = '${m['id']}';
      if (msgs.any((x) => x['id'] == id)) return;
      // My own message comes back here too; the send answer already put it in place.
      if (m['sender'] == _me && msgs.any((x) => x['pending'] == true && x['text'] == m['text'])) return;
      setState(() => msgs = [...msgs, {'id': id, 'mine': m['sender'] == _me, 'text': '${m['text']}', 'at': m['at']}]);
      _toEnd();
      if (m['sender'] != _me) _load(); // marks it read, so their ticks turn blue
    } else if (m['type'] == 'read' && m['by'] != _me) {
      setState(() => otherReadAt = ((m['at'] as num?) ?? 0).toInt());
    }
  }

  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('${widget.base}${widget.path}'), headers: _h).timeout(const Duration(seconds: 12));
      if (r.statusCode >= 400) return;
      final d = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
      final list = ((d['messages'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (!mounted) return;
      // Keep messages still on their way (not in the server's list yet).
      final ids = list.map((x) => x['id']).toSet();
      final pending = msgs.where((x) => (x['pending'] == true || x['failed'] == true) && !ids.contains(x['id'])).toList();
      final grew = list.length + pending.length != msgs.length;
      setState(() {
        msgs = [...list, ...pending];
        open = d['open'] != false;
        otherReadAt = ((d['otherReadAt'] as num?) ?? otherReadAt).toInt();
        loaded = true;
      });
      if (grew) _toEnd();
    } catch (_) {}
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });

  Future<void> _send([Map<String, dynamic>? again]) async {
    final t = again?['text'] as String? ?? text.text.trim();
    if (t.isEmpty) return;
    HapticFeedback.lightImpact();
    // Shows at once with a clock; the server's answer turns it into ✓.
    final tmpId = again?['id'] as String? ?? 'tmp${_tmp++}';
    final mine = <String, dynamic>{'id': tmpId, 'mine': true, 'text': t, 'at': DateTime.now().millisecondsSinceEpoch ~/ 1000, 'pending': true};
    setState(() {
      msgs = [...msgs.where((x) => x['id'] != tmpId), mine];
      loaded = true;
    });
    if (again == null) text.clear();
    _toEnd();
    void fail(String msg) {
      if (!mounted) return;
      setState(() => msgs = [for (final x in msgs) x['id'] == tmpId ? {...x, 'pending': false, 'failed': true} : x]);
      _toast(msg);
    }

    try {
      final r = await http
          .post(Uri.parse('${widget.base}${widget.path}'), headers: _h, body: jsonEncode({'text': t}))
          .timeout(const Duration(seconds: 15));
      final d = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
      if (r.statusCode >= 400) {
        final code = '${d['error']}';
        if (code == 'chat_closed') setState(() => open = false);
        if (code == 'no_numbers' || code == 'chat_closed') {
          setState(() => msgs = msgs.where((x) => x['id'] != tmpId).toList());
          if (again == null && text.text.isEmpty) text.text = t;
          _toast(code == 'no_numbers' ? w('no_numbers') : w('Chat is closed for this order.'));
        } else {
          fail(w('error'));
        }
        return;
      }
      final m = Map<String, dynamic>.from(d['message'] as Map);
      if (!mounted) return;
      setState(() {
        msgs = [for (final x in msgs) if (x['id'] == tmpId) m else if (x['id'] != m['id']) x];
        otherReadAt = ((d['otherReadAt'] as num?) ?? otherReadAt).toInt();
      });
    } catch (_) {
      fail(w('error'));
    }
  }

  /// ✓✓ blue = read, ✓ = sent, clock = on its way, ! = not sent (tap to try again).
  Widget _tick(Map<String, dynamic> m, Color c) {
    if (m['failed'] == true) return const Icon(Icons.error_outline, size: 14, color: Color(0xFFD93025));
    if (m['pending'] == true) return Icon(Icons.schedule, size: 13, color: c);
    final at = ((m['at'] as num?) ?? 0).toInt();
    if (otherReadAt > 0 && at <= otherReadAt) return const Icon(Icons.done_all, size: 15, color: Color(0xFF1E88E5));
    return Icon(Icons.done, size: 14, color: c);
  }

  void _toast(String m) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('${w('Chat')} · ${widget.title}')),
      body: Column(children: [
        Expanded(
          child: !loaded
              ? const Center(child: CircularProgressIndicator())
              : msgs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(w('No messages yet. Say where to come, which gate, what is missing…'),
                            textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurface.withAlpha(150))),
                      ),
                    )
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[i];
                        final mine = m['mine'] == true;
                        final at = DateTime.fromMillisecondsSinceEpoch(((m['at'] as num?) ?? 0).toInt() * 1000);
                        final ink = (mine ? const Color(0xFF21331B) : scheme.onSurface).withAlpha(140);
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: m['failed'] == true ? () => _send(m) : null,
                            child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: mine ? const Color(0xFFF8CB46) : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('${m['text']}', style: TextStyle(fontSize: 15, color: mine ? const Color(0xFF21331B) : scheme.onSurface)),
                              const SizedBox(height: 2),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Text('${at.hour % 12 == 0 ? 12 : at.hour % 12}:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'am' : 'pm'}',
                                    style: TextStyle(fontSize: 10.5, color: ink)),
                                if (mine) ...[const SizedBox(width: 4), _tick(m, ink)],
                              ]),
                            ]),
                          ),
                          ),
                        );
                      },
                    ),
        ),
        SafeArea(
          top: false,
          child: open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: text,
                        maxLength: 300,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                            hintText: w('Write a message…'), counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(22)), isDense: true),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(onPressed: () => _send(), icon: const Icon(Icons.send)),
                  ]),
                )
              : Padding(padding: const EdgeInsets.all(14), child: Text(w('Chat is closed for this order.'))),
        ),
      ]),
    );
  }
}
