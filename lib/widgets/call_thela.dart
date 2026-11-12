import 'dart:async';
import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../services/api.dart';
import '../services/push.dart';
import '../state/app_state.dart';
import 'ui.dart';

/// "Call to my street": ask a LIVE thela to come to the customer's address. No cart, no numbers.
class CallThelaCard extends StatefulWidget {
  final Thela thela;
  final bool live;
  const CallThelaCard({super.key, required this.thela, required this.live});
  @override
  State<CallThelaCard> createState() => _CallThelaCardState();
}

class _CallThelaCardState extends State<CallThelaCard> {
  Map<String, dynamic>? call; // my latest call (any thela)
  bool busy = false;
  Timer? _t;
  late final void Function(Map<String, dynamic>) _onPush = (d) {
    if (d['type'] == 'call') _load();
  };

  @override
  void initState() {
    super.initState();
    pushListeners.add(_onPush);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    // While waiting for an answer, check every 5 s (the push may be late or off).
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      if (call?['status'] == 'waiting') _load();
      if (mounted) setState(() {}); // countdown
    });
  }

  @override
  void dispose() {
    pushListeners.remove(_onPush);
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final s = AppScope.read(context);
    if (!s.signedIn || s.apiToken.isEmpty) return;
    try {
      final r = await api.currentCall(s.apiToken);
      if (!mounted) return;
      setState(() => call = r['call'] == null ? null : Map<String, dynamic>.from(r['call'] as Map));
      _waitingSince = DateTime.now();
    } catch (_) {}
  }

  DateTime _waitingSince = DateTime.now();

  Future<void> _call() async {
    final s = AppScope.read(context);
    if (!s.signedIn || s.apiToken.isEmpty) {
      showToast(context, 'Log in to call a thela to your street.');
      return;
    }
    final a = s.current;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: kCard,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Call ${widget.thela.name} to your street?', style: head(17)),
          SizedBox(height: 8),
          Row(children: [Icon(Icons.location_on_outlined, color: kMute, size: 18), SizedBox(width: 6), Expanded(child: Text(a.short, style: body(14, weight: FontWeight.w700)))]),
          SizedBox(height: 8),
          Text('The thela sees this address, not your name or number. It has 3 minutes to answer. Pay the seller in person.',
              style: body(12.5, color: kMute)),
          SizedBox(height: 14),
          PrimaryButton('Call to my street', onTap: () => Navigator.pop(ctx, true)),
        ]),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    try {
      final r = await api.callThela(s.apiToken, widget.thela.id, a.lat, a.lng, a.short);
      if (mounted) setState(() => call = Map<String, dynamic>.from(r['call'] as Map));
      _waitingSince = DateTime.now();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _cancel() async {
    final s = AppScope.read(context);
    final id = '${call?['id']}';
    setState(() => busy = true);
    try {
      await api.cancelCall(s.apiToken, id);
      await _load();
    } catch (_) {}
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = call;
    final mine = c != null && c['thelaId'] == widget.thela.id;
    final first = widget.thela.name.split(' ').first;
    final status = mine ? '${c['status']}' : '';
    if (mine && status == 'waiting') {
      final left = ((c['waitLeft'] as num?) ?? 0).toInt() - DateTime.now().difference(_waitingSince).inSeconds;
      return _box(
        Icons.hourglass_top, 'Waiting for $first…',
        'Sent to ${c['address']}. ${left > 0 ? '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')} left to answer.' : 'Checking…'}',
        kAmb, kAmbBg,
        TextButton(onPressed: busy ? null : _cancel, child: Text('Cancel')),
      );
    }
    if (mine && status == 'coming') {
      final d = widget.thela.distanceM;
      final mins = (d / 60).ceil().clamp(1, 30);
      return _box(Icons.directions_walk, '$first is coming', 'About $mins min · watch the pin on the map. Pay the seller directly.', kGText, kPillBg,
          TextButton(onPressed: busy ? null : _cancel, child: Text('I don’t need it now')));
    }
    final failed = mine && (status == 'declined' || status == 'expired');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (failed)
        Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: NoteBox('$first can’t come right now. Try again later, or call another thela nearby.', icon: Icons.info_outline, color: kAmb, bg: kAmbBg),
        ),
      if (widget.live)
        PrimaryButton(busy ? 'Calling…' : 'Call to my street', onTap: busy ? null : _call)
      else
        NoteBox('You can call this thela when it is LIVE near you.', icon: Icons.info_outline),
    ]);
  }

  Widget _box(IconData icon, String title, String sub, Color fg, Color bg, Widget action) => Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icon, color: fg),
          SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: head(15, color: fg)),
              SizedBox(height: 2),
              Text(sub, style: body(12.5, color: fg)),
            ]),
          ),
          action,
        ]),
      );
}
