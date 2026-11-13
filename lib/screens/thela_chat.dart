import 'dart:async';
import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../services/api.dart';
import '../services/push.dart';
import '../services/live_socket.dart';
import '../services/live_data.dart';
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
  int busy = 0; // other customers waiting for this thela's reply
  bool sending = false, first = true;
  final text = TextEditingController();
  final scroll = ScrollController();
  Timer? _t;
  LiveSocket? _live;
  String? chatId;
  AppLifecycleListener? _life;
  late final void Function(Map<String, dynamic>) _onPush = (d) {
    if (d['type'] == 'chat') _load();
  };

  @override
  void initState() {
    super.initState();
    pushListeners.add(_onPush);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _t = Timer.periodic(const Duration(seconds: 5), (_) => _load());
    _life = AppLifecycleListener(onResume: () {
      _load();
      _live?.reconnect();
    });
  }

  @override
  void dispose() {
    pushListeners.remove(_onPush);
    _t?.cancel();
    _live?.close();
    _life?.dispose();
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
      busy = (r['busy'] as num?)?.toInt() ?? busy;
    });
    // Once the chat exists, open the live connection: new messages arrive at once.
    final id = r['chatId'] as String?;
    if (id != null && _live == null) {
      chatId = id;
      _live = LiveSocket(id, AppScope.read(context).apiToken, _load);
    }
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
    // Show it at once; the server's copy replaces it a moment later.
    setState(() {
      sending = true;
      msgs = [...msgs, {'from': 'customer', 'text': v, 'pending': true}];
    });
    text.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
    try {
      final a = s.current;
      _apply(await api.sendChat(s.apiToken, widget.thela.id, v, address: first ? a.short : null, lat: first ? a.lat : null, lng: first ? a.lng : null));
      first = false;
    } on ApiException catch (e) {
      setState(() => msgs = msgs.where((m) => m['pending'] != true).toList());
      if (mounted) showToast(context, e.message);
    }
    if (mounted) setState(() => sending = false);
  }

  Future<void> _menu(String v) async {
    final s = AppScope.read(context);
    try {
      await api.chatAction(s.apiToken, widget.thela.id, v, reason: v == 'report' ? 'Reported by customer' : '');
      if (mounted) {
        showToast(context, switch (v) {
          'report' => 'Reported. Thanks — the chat is closed.',
          'unblock' => 'Unblocked.',
          _ => 'Blocked. They can’t message you.',
        });
      }
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
              if (blocked == 'customer') PopupMenuItem(value: 'unblock', child: Text('Unblock')) else PopupMenuItem(value: 'block', child: Text('Block')),
              PopupMenuItem(value: 'report', child: Text('Report', style: TextStyle(color: kRed))),
            ],
          ),
        ],
      ),
      body: !s.signedIn
          ? Center(child: Text('Log in to chat with this thela.', style: body(14, color: kMute)))
          : Column(children: [
              // Today's prices first: most questions ("matar hai?", "kitne ka?") are answered here.
              _Prices(thelaId: widget.thela.id),
              if (busy >= 2)
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: NoteBox('${widget.thela.name.split(' ').first} is answering $busy people. Replies may take a few minutes — or tap “Call to my street”.',
                      icon: Icons.schedule, color: kAmb, bg: kAmbBg),
                ),
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
                        child: Text('${msgs[i]['text']}${msgs[i]['pending'] == true ? '  ·' : ''}', style: body(14, color: msgs[i]['pending'] == true ? kMute : null)),
                      ),
                    );
                  },
                ),
              ),
              if (blocked != null)
                Padding(
                  padding: EdgeInsets.all(14),
                  child: blocked == 'customer'
                      ? Row(children: [
                          Expanded(child: Text('You blocked this chat.', style: body(13, color: kMute))),
                          OutlinedButton(onPressed: () => _menu('unblock'), child: Text('Unblock')),
                        ])
                      : Text('This chat is closed.', style: body(13, color: kMute)),
                )
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

/// Strip of the thela's items with today's prices, above the chat.
class _Prices extends StatelessWidget {
  final String thelaId;
  const _Prices({required this.thelaId});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LiveData.instance,
      builder: (context, _) {
        final th = kThelas.where((x) => x.id == thelaId).firstOrNull;
        final items = th?.items ?? const <ThelaItem>[];
        if (items.isEmpty) return SizedBox.shrink();
        return Container(
          color: kCard,
          padding: EdgeInsets.fromLTRB(12, 8, 0, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Today’s prices · check before you ask', style: body(12, color: kMute, weight: FontWeight.w700)),
            SizedBox(height: 6),
            SizedBox(
              height: 74,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final it = items[i];
                  final p = it.exactPrice == 0 ? it.price : it.exactPrice;
                  return Container(
                    width: 74,
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
                    child: Column(children: [
                      Expanded(child: ProductPic(it.emoji, size: 34)),
                      Text(it.hindi, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(10.5, weight: FontWeight.w700)),
                      Text('₹${p == p.roundToDouble() ? p.toInt() : p}/${it.unit}', style: body(10, color: kGText, weight: FontWeight.w800)),
                    ]),
                  );
                },
              ),
            ),
          ]),
        );
      },
    );
  }
}
