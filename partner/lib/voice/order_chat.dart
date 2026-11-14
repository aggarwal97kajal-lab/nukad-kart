// Chat on a shop order (same file in the customer and the Partner app). Numbers can't be sent; the other side
// gets a notification. The screen checks for new messages every 4 seconds while it is open.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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
  bool open = true, sending = false, loaded = false;
  Timer? _poll;

  String w(String k) => chatText(k, widget.lang);
  Map<String, String> get _h => {'content-type': 'application/json', 'authorization': 'Bearer ${widget.token()}'};

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('${widget.base}${widget.path}'), headers: _h).timeout(const Duration(seconds: 12));
      if (r.statusCode >= 400) return;
      final d = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
      final list = ((d['messages'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (!mounted) return;
      final grew = list.length != msgs.length;
      setState(() {
        msgs = list;
        open = d['open'] != false;
        loaded = true;
      });
      if (grew) _toEnd();
    } catch (_) {}
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });

  Future<void> _send() async {
    final t = text.text.trim();
    if (t.isEmpty || sending) return;
    HapticFeedback.lightImpact();
    setState(() => sending = true);
    try {
      final r = await http
          .post(Uri.parse('${widget.base}${widget.path}'), headers: _h, body: jsonEncode({'text': t}))
          .timeout(const Duration(seconds: 12));
      final d = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
      if (r.statusCode >= 400) {
        final code = '${d['error']}';
        if (code == 'chat_closed') setState(() => open = false);
        _toast(code == 'no_numbers' ? w('no_numbers') : (code == 'chat_closed' ? w('Chat is closed for this order.') : w('error')));
      } else {
        text.clear();
        await _load();
      }
    } catch (_) {
      _toast(w('error'));
    }
    if (mounted) setState(() => sending = false);
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
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
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
                              Text('${at.hour % 12 == 0 ? 12 : at.hour % 12}:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'am' : 'pm'}',
                                  style: TextStyle(fontSize: 10.5, color: (mine ? const Color(0xFF21331B) : scheme.onSurface).withAlpha(140))),
                            ]),
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
                    IconButton.filled(onPressed: sending ? null : _send, icon: const Icon(Icons.send)),
                  ]),
                )
              : Padding(padding: const EdgeInsets.all(14), child: Text(w('Chat is closed for this order.'))),
        ),
      ]),
    );
  }
}
