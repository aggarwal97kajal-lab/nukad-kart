import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n.dart';
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
  int strikes = 0, strikesMax = 3, blockedUntil = 0;
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
    // While waiting for an answer or for the thela to come, check every 5 s (the push may be late or off).
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      if (call?['status'] == 'waiting' || call?['status'] == 'coming') _load();
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
      setState(() {
        call = r['call'] == null ? null : Map<String, dynamic>.from(r['call'] as Map);
        strikes = (r['strikes'] as num?)?.toInt() ?? 0;
        strikesMax = (r['strikesMax'] as num?)?.toInt() ?? 3;
        blockedUntil = (r['blockedUntil'] as num?)?.toInt() ?? 0;
      });
      _waitingSince = DateTime.now();
    } catch (_) {}
  }

  DateTime _waitingSince = DateTime.now();

  Future<void> _call() async {
    final s = AppScope.read(context);
    if (!s.signedIn || s.apiToken.isEmpty) {
      showToast(context, t('Log in to call a thela to your street.'));
      return;
    }
    final a = s.current;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: kCard,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Call {0} to your street?', [widget.thela.name]), style: head(17)),
          SizedBox(height: 8),
          Row(children: [Icon(Icons.location_on_outlined, color: kMute, size: 18), SizedBox(width: 6), Expanded(child: Text(a.short, style: body(14, weight: FontWeight.w700)))]),
          SizedBox(height: 8),
          Text(t('The thela sees this address, not your name or number. It has 3 minutes to answer. Pay the seller in person.'),
              style: body(12.5, color: kMute)),
          SizedBox(height: 14),
          PrimaryButton(t('Call to my street'), onTap: () => Navigator.pop(ctx, true)),
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
        Icons.hourglass_top, tr('Waiting for {0}…', [first]),
        '${tr('Sent to {0}.', [c['address']])} ${left > 0 ? tr('{0} left to answer.', ['${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}']) : t('Checking…')}',
        kAmb, kAmbBg,
        TextButton(onPressed: busy ? null : _cancel, child: Text(t('Cancel'))),
      );
    }
    if (mine && status == 'coming') {
      final d = widget.thela.distanceM;
      final mins = (d / 60).ceil().clamp(1, 30);
      return _box(Icons.directions_walk, tr('{0} is coming', [first]), tr('About {0} min · watch the pin on the map. Pay the seller directly.', [mins]), kGText, kPillBg,
          TextButton(onPressed: busy ? null : _cancel, child: Text(t('I don’t need it now'))));
    }
    final failed = mine && (status == 'declined' || status == 'expired');
    final paused = blockedUntil * 1000 > DateTime.now().millisecondsSinceEpoch;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (mine && status == 'no_show')
        Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: NoteBox(
              paused
                  ? tr('{0} came but couldn’t find you. This happened {1} times, so calling thelas is paused for 7 days.', [first, strikes])
                  : tr('{0} came but couldn’t find you. This is {1} of {2} — at {2}, calling thelas is paused for 7 days.', [first, strikes, strikesMax]),
              icon: Icons.report_gmailerrorred,
              color: kRed,
              bg: kRedBg),
        ),
      if (failed)
        Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: NoteBox(tr('{0} can’t come right now. Try again later, or call another thela nearby.', [first]), icon: Icons.info_outline, color: kAmb, bg: kAmbBg),
        ),
      if (paused)
        NoteBox(tr('Calling thelas is paused until {0} because thelas came and found nobody {1} times.', [_date(blockedUntil), strikesMax]), icon: Icons.block)
      else if (widget.live)
        PrimaryButton(busy ? t('Calling…') : t('Call to my street'), onTap: busy ? null : _call)
      else
        NoteBox(t('You can call this thela when it is LIVE near you.'), icon: Icons.info_outline),
    ]);
  }

  static String _date(int sec) {
    final d = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]}';
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
