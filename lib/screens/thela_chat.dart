import 'dart:async';
import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../services/api.dart';
import '../services/push.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';

/// Text chat with a thela. No phone numbers (the server refuses them); messages disappear after 24 hours.
class ThelaChatScreen extends StatefulWidget {
  final Thela thela;
  const ThelaChatScreen({super.key, required this.thela});
  @override
  State<ThelaChatScreen> createState() => _ThelaChatScreenState();
}

class _ThelaChatScreenState extends State<ThelaChatScreen> {
  List<Map<String, dynamic>> msgs = [];
  String? blocked;
  bool sending = false, first = true;
  final text = TextEditingController();
  final scroll = ScrollController();
  Timer? _t;
  late final void Function(Map<String, dynamic>) _onPush = (d) {
    if (d['type'] == 'chat') _load();
  };

  @override
  void initState() {
    super.initState();
    pushListeners.add(_onPush);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _t = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    pushListeners.remove(_onPush);
    _t?.cancel();
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _apply(Map<String, dynamic> r) {
    final n = ((r['messages'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final grew = n.length != msgs.length;
    setState(() {
      msgs = n;
      blocked = r['blocked'] as String?;
    });
    if (grew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
      });
    }
  }

  Future<void> _load() async {
    final s = AppScope.read(context);
    if (!s.signedIn) return;
    try {
      _apply(await api.chat(s.apiToken, widget.thela.id));
    } catch (_) {}
  }

  Future<void> _send() async {
    final s = AppScope.read(context);
    final v = text.text.trim();
    if (v.isEmpty) return;
    setState(() => sending = true);
    try {
      final a = s.current;
      _apply(await api.sendChat(s.apiToken, widget.thela.id, v, address: first ? a.short : null, lat: first ? a.lat : null, lng: first ? a.lng : null));
      first = false;
      text.clear();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
    if (mounted) setState(() => sending = false);
  }

  Future<void> _menu(String v) async {
    final s = AppScope.read(context);
    try {
      await api.chatAction(s.apiToken, widget.thela.id, v, reason: v == 'report' ? 'Reported by customer' : '');
      if (mounted) showToast(context, v == 'report' ? 'Reported. Thanks — the chat is closed.' : 'Blocked. They can’t message you.');
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kCard,
        title: Text(widget.thela.name, style: head(17)),
        actions: [
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => [
              PopupMenuItem(value: 'block', child: Text('Block')),
              PopupMenuItem(value: 'report', child: Text('Report', style: TextStyle(color: kRed))),
            ],
          ),
        ],
      ),
      body: !s.signedIn
          ? Center(child: Text('Log in to chat with this thela.', style: body(14, color: kMute)))
          : Column(children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Chat clears after 24 hours · Phone numbers are hidden', style: body(11.5, color: kMute)),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final mine = msgs[i]['from'] == 'customer';
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
                        decoration: BoxDecoration(color: mine ? kGBg : kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
                        child: Text('${msgs[i]['text']}', style: body(14)),
                      ),
                    );
                  },
                ),
              ),
              if (blocked != null)
                Padding(padding: EdgeInsets.all(14), child: Text('This chat is closed.', style: body(13, color: kMute)))
              else
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(10, 6, 10, 10),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: text,
                          maxLength: 300,
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'Ask about items or price',
                            filled: true,
                            fillColor: kCard,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton.filled(onPressed: sending ? null : _send, icon: Icon(Icons.send)),
                    ]),
                  ),
                ),
            ]),
    );
  }
}
