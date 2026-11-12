import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../push.dart';
import '../ui.dart';

/// Thela Home: messages from customers (newest first). Tap to answer with one tap or by typing.
class ChatsCard extends StatefulWidget {
  const ChatsCard({super.key});
  @override
  State<ChatsCard> createState() => _ChatsCardState();
}

class _ChatsCardState extends State<ChatsCard> {
  List<Map<String, dynamic>> chats = [];
  Timer? _t;

  @override
  void initState() {
    super.initState();
    pushTick.addListener(_load);
    _load();
    _t = Timer.periodic(const Duration(seconds: 20), (_) => _load());
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
      if (mounted) setState(() => chats = ((r['chats'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (chats.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Messages'), style: tx(15, weight: FontWeight.w800)),
          for (final c in chats.take(5))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.chat_bubble_outline, color: c['unread'] == true ? kAmb : kMute),
              title: Text('${c['lastText']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: tx(14, weight: c['unread'] == true ? FontWeight.w800 : FontWeight.w500)),
              subtitle: Text('${c['address']}'.isEmpty ? t('Customer') : '${c['address']}', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(id: '${c['id']}', address: '${c['address']}')));
                _load();
              },
            ),
        ]),
      ),
    );
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
  Timer? _t;

  static const quick = ['Haan hai', 'Khatam ho gaya', '5 min mein aata hoon', 'Aaj nahi aaunga'];

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _t?.cancel();
    text.dispose();
    super.dispose();
  }

  void _apply(Map<String, dynamic> r) {
    if (!mounted) return;
    setState(() {
      msgs = ((r['messages'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      blocked = r['blocked'] as String?;
    });
  }

  Future<void> _load() async {
    try {
      _apply(await api.call('GET', '/v1/partner/chats/${widget.id}'));
    } catch (_) {}
  }

  Future<void> _send(String v) async {
    if (v.trim().isEmpty) return;
    setState(() => sending = true);
    try {
      _apply(await api.call('POST', '/v1/partner/chats/${widget.id}', {'text': v.trim()}));
      text.clear();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.code == 'no_numbers' ? t('Phone numbers can’t be sent in chat.') : e.message);
    }
    if (mounted) setState(() => sending = false);
  }

  Future<void> _action(String what) async {
    try {
      await api.call('POST', '/v1/partner/chats/${widget.id}/$what', {'reason': 'Reported by thela'});
      if (mounted) toast(context, what == 'report' ? t('Reported. The chat is closed.') : t('Blocked.'));
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
            PopupMenuItem(value: 'block', child: Text(t('Block'))),
            PopupMenuItem(value: 'report', child: Text(t('Report'), style: TextStyle(color: kRed))),
          ],
        ),
      ]),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(12), children: [
            for (final m in msgs)
              Align(
                alignment: m['from'] == 'thela' ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: m['from'] == 'thela' ? kOkBg : kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
                  child: Text('${m['text']}', style: tx(14.5)),
                ),
              ),
          ]),
        ),
        if (blocked != null)
          Padding(padding: const EdgeInsets.all(14), child: Text(t('This chat is closed.'), style: tx(13, color: kMute)))
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
