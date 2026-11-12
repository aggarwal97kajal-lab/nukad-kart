import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../push.dart';
import '../ui.dart';

/// Thela Home: customers calling you to their street, grouped by street (~100 m).
/// "Coming" / "Can't come" answers everyone on that street at once. 3 minutes to answer.
class CallsCard extends StatefulWidget {
  const CallsCard({super.key});
  @override
  State<CallsCard> createState() => _CallsCardState();
}

class _CallsCardState extends State<CallsCard> {
  List<Map<String, dynamic>> waiting = [], coming = [];
  Timer? _t;
  DateTime _at = DateTime.now();
  bool busy = false;

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
      final r = await api.call('GET', '/v1/partner/calls');
      if (!mounted) return;
      List<Map<String, dynamic>> l(Object? x) => ((x as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        waiting = l(r['groups']);
        coming = l(r['coming']);
        _at = DateTime.now();
      });
    } catch (_) {}
  }

  Future<void> _post(String path, Map<String, dynamic> g, [Map<String, dynamic> extra = const {}]) async {
    setState(() => busy = true);
    try {
      await api.call('POST', path, {'ids': g['ids'], ...extra});
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    await _load();
    if (mounted) setState(() => busy = false);
  }

  String _who(Map<String, dynamic> g) => (g['count'] as num) > 1 ? tr('{0} people', [g['count']]) : t('1 customer');

  @override
  Widget build(BuildContext context) {
    if (waiting.isEmpty && coming.isEmpty) return const SizedBox.shrink();
    final since = DateTime.now().difference(_at).inSeconds;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final g in waiting)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kSurf, borderRadius: BorderRadius.circular(16), border: Border.all(color: kAmb, width: 2)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.campaign_outlined, color: kAmb),
              const SizedBox(width: 6),
              Expanded(child: Text(tr('{0} calling you', [_who(g)]), style: tx(15, weight: FontWeight.w800))),
              Text(() {
                final left = ((g['waitLeft'] as num?) ?? 0).toInt() - since;
                return left > 0 ? '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}' : '0:00';
              }(), style: tx(13, color: kAmb, weight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            Text('${g['address']}${g['distanceM'] == null ? '' : ' · ${g['distanceM']} m'}', style: tx(14, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Btn(t('Coming'), onTap: busy ? null : () => _post('/v1/partner/calls/answer', g, {'coming': true}))),
              const SizedBox(width: 10),
              Expanded(child: Btn(t('Can’t come'), outline: true, onTap: busy ? null : () => _post('/v1/partner/calls/answer', g, {'coming': false}))),
            ]),
          ]),
        ),
      for (final g in coming)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kOkBg, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Going to {0} · {1}', [g['address'], _who(g)]), style: tx(14, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Btn(t('Reached, sold'), onTap: busy ? null : () => _post('/v1/partner/calls/done', g))),
              const SizedBox(width: 10),
              Expanded(child: Btn(t('Nobody there'), outline: true, onTap: busy ? null : () => _post('/v1/partner/calls/no-show', g))),
            ]),
          ]),
        ),
    ]);
  }
}
