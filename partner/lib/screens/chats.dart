import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../push.dart';
import '../ui.dart';
import '../live_socket.dart';

/// One-tap answers (also inside a chat). Kept general: an item answer must be given per chat.
const kQuickReplies = ['Haan hai', 'Khatam ho gaya', '5 min mein aata hoon', 'Aaj nahi aaunga'];
/// "Reply to all": only general answers, never about one item (it would be wrong for some customers).
const kReplyAll = ['10 min mein aata hoon', 'Aaj ke bhav app mein dekhein', 'Abhi raste mein hoon', 'Aaj band hai'];

/// Thela Home: messages from customers. Waiting for an answer first, nearest first; one-tap answers in the list.
class ChatsCard extends StatefulWidget {
  final bool full; // the "See all" screen
  const ChatsCard({super.key, this.full = false});
  @override
  State<ChatsCard> createState() => _ChatsCardState();
}

class _ChatsCardState extends State<ChatsCard> {
  List<Map<String, dynamic>> chats = [];
  int waiting = 0;
  bool busy = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    pushTick.addListener(_load);
    _load();
    _t = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    pushTick.removeListener(_load);
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await api.call('GET', '/v1/partner/chats');
      if (!mounted) return;
      setState(() {
        chats = ((r['chats'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        waiting = (r['waiting'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _quick(Map<String, dynamic> c, String text) async {
    setState(() => busy = true);
    try {
      await api.call('POST', '/v1/partner/chats/${c['id']}', {'text': text});
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    await _load();
    if (mounted) setState(() => busy = false);
  }

  Future<void> _replyAll() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kCard,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Reply to {0} customers', [waiting]), style: tx(16, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(t('Each chat gets its own copy; customers can’t see each other. Answer item questions in each chat.'), style: tx(12, color: kMute)),
            const SizedBox(height: 12),
            for (final q in kReplyAll)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Btn(q, outline: true, onTap: () => Navigator.pop(ctx, q))),
          ]),
        ),
      ),
    );
    if (text == null) return;
    setState(() => busy = true);
    try {
      final r = await api.call('POST', '/v1/partner/chats/reply-all', {'text': text});
      if (mounted) toast(context, tr('Sent to {0} customers.', [r['sent']]));
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    await _load();
    if (mounted) setState(() => busy = false);
  }

  Future<void> _open(Map<String, dynamic> c) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(id: '${c['id']}', address: '${c['address']}')));
    _load();
  }

  Widget _row(Map<String, dynamic> c) {
    final w = c['waiting'] == true;
    final n = (c['unreadCount'] as num?)?.toInt() ?? 0;
    final where = '${c['address']}'.isEmpty ? t('Customer') : '${c['address']}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: kLine))),
      child: Opacity(
        opacity: w ? 1 : 0.6,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => _open(c),
            child: Row(children: [
              Expanded(
                child: Text('$where${c['distanceM'] == null ? '' : ' · ${c['distanceM']} m'}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(13.5, weight: FontWeight.w800)),
              ),
              if (n > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: kAmb, borderRadius: BorderRadius.circular(9)),
                  child: Text('$n', style: tx(11, color: Colors.white, weight: FontWeight.w800)),
                ),
            ]),
          ),
          Text(c['lastFrom'] == 'thela' ? '${t('You')}: "${c['lastText']}"' : '"${c['lastText']}"',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(12.5, color: kMute)),
          if (w)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final q in kQuickReplies.take(3))
                  ActionChip(label: Text(q, style: tx(12)), onPressed: busy ? null : () => _quick(c, q)),
                ActionChip(label: Text(t('Open'), style: tx(12, weight: FontWeight.w800)), onPressed: () => _open(c)),
              ]),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (chats.isEmpty && !widget.full) return const SizedBox.shrink();
    final shown = widget.full ? chats : chats.take(4).toList();
    final unread = chats.where((c) => c['unread'] == true).length;
    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(t('Messages'), style: tx(15, weight: FontWeight.w800)),
        if (unread > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: kAct, borderRadius: BorderRadius.circular(10)),
            child: Text(tr('{0} unread', [unread]), style: tx(11, color: kOnAct, weight: FontWeight.w800)),
          ),
        ],
        const Spacer(),
        if (waiting > 1) TextButton(onPressed: busy ? null : _replyAll, child: Text(t('Reply to all'))),
      ]),
      if (chats.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(t('No messages in the last 24 hours.'), style: tx(13, color: kMute))),
      for (final c in shown) _row(c),
      if (!widget.full && chats.length > shown.length)
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: bar(t('Messages')), body: ListView(padding: const EdgeInsets.all(16), children: const [ChatsCard(full: true)])))),
          child: Text(tr('See all {0} chats', [chats.length])),
        ),
    ]);
    return Padding(padding: EdgeInsets.only(top: widget.full ? 0 : 12), child: widget.full ? body : Box(child: body));
  }
}

class ChatScreen extends StatefulWidget {
  final String id, address;
  const ChatScreen({super.key, required this.id, required this.address});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> msgs = [];
  String? blocked;
  bool sending = false, typing = false;
  final text = TextEditingController();
  final scroll = ScrollController();
  Timer? _t;
  LiveSocket? _live;
  AppLifecycleListener? _life;

  static const quick = kQuickReplies;

  @override
  void initState() {
    super.initState();
    _load();
    _live = LiveSocket(widget.id, _load); // new messages arrive at once
    _t = Timer.periodic(const Duration(seconds: 5), (_) => _load());
    _life = AppLifecycleListener(onResume: () {
      _load();
      _live?.reconnect();
    });
  }

  @override
  void dispose() {
    _live?.close();
    _life?.dispose();
    _t?.cancel();
    scroll.dispose();
    text.dispose();
    super.dispose();
  }

  void _apply(Map<String, dynamic> r) {
    if (!mounted) return;
    final n = ((r['messages'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final grew = n.length != msgs.length;
    setState(() {
      msgs = n;
      if (r.containsKey('blocked')) blocked = r['blocked'] as String?;
    });
    if (grew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
      });
    }
  }

  Future<void> _load() async {
    try {
      _apply(await api.call('GET', '/v1/partner/chats/${widget.id}'));
    } catch (_) {}
  }

  Future<void> _send(String v) async {
    if (v.trim().isEmpty) return;
    // Show it at once; the server's copy replaces it a moment later.
    setState(() {
      sending = true;
      msgs = [...msgs, {'from': 'thela', 'text': v.trim(), 'pending': true}];
    });
    text.clear();
    try {
      _apply(await api.call('POST', '/v1/partner/chats/${widget.id}', {'text': v.trim()}));
    } on ApiError catch (e) {
      setState(() => msgs = msgs.where((m) => m['pending'] != true).toList());
      if (mounted) toast(context, e.code == 'no_numbers' ? t('Phone numbers can’t be sent in chat.') : e.message);
    }
    if (mounted) setState(() => sending = false);
  }

  Future<void> _action(String what) async {
    try {
      await api.call('POST', '/v1/partner/chats/${widget.id}/$what', {'reason': 'Reported by thela'});
      if (mounted) toast(context, what == 'report' ? t('Reported. The chat is closed.') : what == 'unblock' ? t('Unblocked.') : t('Blocked.'));
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(widget.address.isEmpty ? t('Customer') : widget.address, actions: [
        PopupMenuButton<String>(
          onSelected: _action,
          itemBuilder: (_) => [
            if (blocked == 'thela') PopupMenuItem(value: 'unblock', child: Text(t('Unblock'))) else PopupMenuItem(value: 'block', child: Text(t('Block'))),
            PopupMenuItem(value: 'report', child: Text(t('Report'), style: TextStyle(color: kRed))),
          ],
        ),
      ]),
      body: Column(children: [
        Expanded(
          child: ListView(controller: scroll, padding: const EdgeInsets.all(12), children: [
            for (final m in msgs)
              Align(
                alignment: m['from'] == 'thela' ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: m['from'] == 'thela' ? kOkBg : kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
                  child: Text('${m['text']}${m['pending'] == true ? '  ·' : ''}', style: tx(14.5, color: m['pending'] == true ? kMute : null)),
                ),
              ),
          ]),
        ),
        if (blocked != null)
          Padding(
            padding: const EdgeInsets.all(14),
            child: blocked == 'thela'
                ? Row(children: [
                    Expanded(child: Text(t('You blocked this chat.'), style: tx(13, color: kMute))),
                    OutlinedButton(onPressed: () => _action('unblock'), child: Text(t('Unblock'))),
                  ])
                : Text(t('This chat is closed.'), style: tx(13, color: kMute)),
          )
        else
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: Column(children: [
                // One tap answers: no typing while pushing the thela.
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 4.2,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  children: [for (final q in quick) OutlinedButton(onPressed: sending ? null : () => _send(q), child: Text(q, maxLines: 1))],
                ),
                const SizedBox(height: 6),
                if (!typing)
                  TextButton.icon(onPressed: () => setState(() => typing = true), icon: const Icon(Icons.keyboard), label: Text(t('Type')))
                else
                  Row(children: [
                    Expanded(child: TextField(controller: text, maxLength: 300, decoration: field(t('Type a reply')).copyWith(counterText: ''))),
                    const SizedBox(width: 8),
                    IconButton.filled(onPressed: sending ? null : () => _send(text.text), icon: const Icon(Icons.send)),
                  ]),
              ]),
            ),
          ),
      ]),
    );
  }
}
