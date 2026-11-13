import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../push.dart';
import '../rider_location.dart';
import '../session.dart';
import '../ui.dart';
import 'product_form.dart' show money;

/// Shop orders: New (rings, 5 min to answer) → Packing → On the way → Done.
/// Delivery-only staff see only "On the way" orders given to them.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String tab = 'new';
  List<Map<String, dynamic>> orders = [], staff = [];
  Map<String, dynamic> counts = {};
  int missedToday = 0, missedLimit = 5;
  bool _loading = true;
  Timer? _t;
  DateTime _at = DateTime.now();

  bool get deliveryOnly => session.staffInfo != null && session.staffInfo!['canOrders'] != true;

  @override
  void initState() {
    super.initState();
    if (deliveryOnly) tab = 'out';
    pushTick.addListener(_load);
    _load();
    _t = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    pushTick.removeListener(_load);
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await api.call('GET', '/v1/partner/orders?tab=$tab');
      if (!mounted) return;
      List<Map<String, dynamic>> l(Object? x) => ((x as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        orders = l(r['orders']);
        staff = l(r['staff']);
        counts = Map<String, dynamic>.from((r['counts'] as Map?) ?? {});
        missedToday = (r['missedToday'] as num?)?.toInt() ?? 0;
        missedLimit = (r['missedLimit'] as num?)?.toInt() ?? 5;
        _loading = false;
        _at = DateTime.now();
      });
      // Orders that are no longer new: stop their ringing.
      if (tab != 'new') {
        for (final o in orders) {
          stopOrderAlarm('${o['id']}');
        }
      }
      // This phone shares its location while it has a door order out (the customer sees the scooter).
      RiderLocation.instance.sync(outDoorOrders: (r['myDoorOut'] as num?)?.toInt());
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        toast(context, e.message);
      }
    }
  }

  void _tab(String v) {
    setState(() {
      tab = v;
      _loading = true;
      orders = [];
    });
    _load();
  }

  Widget _chip(String v, String label, String countKey) {
    final n = (counts[countKey] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(n > 0 && v != 'done' ? '$label · $n' : label),
        selected: tab == v,
        onSelected: (_) => _tab(v),
        selectedColor: v == 'new' && n > 0 ? kAmb.withAlpha(60) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(deliveryOnly ? t('My deliveries') : t('Orders')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
          if (!deliveryOnly)
            SizedBox(
              height: 42,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _chip('new', t('New'), 'placed'),
                _chip('packing', t('Packing'), 'accepted'),
                _chip('out', t('On the way'), 'out'),
                _chip('done', t('Done'), ''),
              ]),
            ),
          if (!deliveryOnly && missedToday > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Box(
                color: kRedBg,
                border: kRedLine,
                child: Text(tr('{0} missed orders today. At {1} your shop is paused for the day.', [missedToday, missedLimit]),
                    style: tx(12.5, color: kRed, weight: FontWeight.w700)),
              ),
            ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                  switch (tab) {
                    'new' => t('No new orders. They ring here for 5 minutes.'),
                    'packing' => t('Nothing to pack.'),
                    'out' => deliveryOnly ? t('No deliveries for you right now.') : t('Nothing on the way.'),
                    _ => t('No orders in the last 7 days.'),
                  },
                  textAlign: TextAlign.center,
                  style: tx(14, color: kMute)),
            )
          else
            for (final o in orders) _card(o),
        ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> o) {
    final lines = ((o['lines'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final items = lines.where((l) => l['na'] != true).fold<int>(0, (a, l) => a + (l['qty'] as num).toInt());
    final left = ((o['ringLeft'] as num?) ?? 0).toInt() - DateTime.now().difference(_at).inSeconds;
    final st = '${o['status']}';
    final who = staff.where((s) => s['id'] == o['staffId']).map((s) => '${s['name']}').firstOrNull;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o, staff: staff)));
        _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: st == 'placed' ? kAmb : kLine, width: st == 'placed' ? 2 : 1),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('#${o['id']} · ${money(o['total'] as num)}', style: tx(15, weight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${o['door'] == true ? t('Door') : t('Pickup')} · ${tr('{0} items', [items])}${who != null ? ' · $who' : ''}',
                  style: tx(12.5, color: kMute)),
              if (o['door'] == true) Text('${o['address']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(12, color: kMute)),
            ]),
          ),
          if (st == 'placed')
            Text(left > 0 ? '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}' : '0:00', style: tx(15, color: kAmb, weight: FontWeight.w800))
          else
            Text(_statusText(o), style: tx(12, color: st == 'delivered' ? kAct : kMute, weight: FontWeight.w700)),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }
}

String _statusText(Map<String, dynamic> o) => switch ('${o['status']}') {
      'placed' => t('New'),
      'accepted' => t('Packing'),
      'out' => o['door'] == true ? t('On the way') : t('Ready for pickup'),
      'delivered' => t('Delivered'),
      'rejected' => t('Rejected'),
      'missed' => t('Missed'),
      _ => t('Cancelled'),
    };

/// One order: accept / reject, pack (mark items not available, choose who delivers), delivery code + payment.
class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> staff;
  const OrderDetailScreen({super.key, required this.order, required this.staff});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Map<String, dynamic> o = widget.order;
  final Set<int> na = {};
  String? staffId;
  bool busy = false;
  final code = TextEditingController();

  bool get canOrders => session.staffInfo == null || session.staffInfo!['canOrders'] == true;

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get lines => ((o['lines'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<void> _do(String what, [Map<String, dynamic> extra = const {}]) async {
    setState(() => busy = true);
    try {
      final r = await api.call('POST', '/v1/partner/orders/${o['id']}/$what', extra);
      o = Map<String, dynamic>.from(r['order'] as Map);
      stopOrderAlarm('${o['id']}');
      if (mounted) {
        toast(context, switch (what) {
          'accept' => t('Accepted. Pack it now.'),
          'reject' => t('Rejected. The customer is told.'),
          'send' => o['status'] == 'cancelled' ? t('Nothing left to send: order cancelled.') : t('Sent. The customer has the delivery code.'),
          _ => tr('Delivered. Bill {0} is made.', [o['billNo']]),
        });
      }
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _reject() async {
    final reasons = [t('Items out of stock'), t('Shop closing'), t('Too far / can’t deliver now'), t('Other')];
    final r = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kCard,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(t('Why reject?'), style: tx(16, weight: FontWeight.w800))),
          for (final x in reasons) ListTile(title: Text(x), onTap: () => Navigator.pop(ctx, x)),
        ]),
      ),
    );
    if (r != null) await _do('reject', {'reason': r});
  }

  @override
  Widget build(BuildContext context) {
    final st = '${o['status']}';
    final ls = lines;
    final total = ls.asMap().entries.where((e) => !(st == 'accepted' ? na.contains(e.key) : e.value['na'] == true))
        .fold<int>(0, (a, e) => a + (e.value['price'] as num).toInt() * (e.value['qty'] as num).toInt());
    final fee = o['door'] == true && total < 199 && total > 0 ? 20 : 0;
    return Scaffold(
      appBar: bar('#${o['id']}'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Box(
          color: kSurf,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_statusText(o)} · ${o['door'] == true ? t('Door delivery') : t('Pickup')}', style: tx(14, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${o['toName']}${'${o['toPhone']}'.isNotEmpty ? ' · ${o['toPhone']}' : ''}', style: tx(13)),
            Text('${o['address']}', style: tx(13, color: kMute)),
            if ('${o['buyerGstin']}'.isNotEmpty) Text('GSTIN ${o['buyerGstin']} · ${o['buyerBusiness']}', style: tx(12, color: kMute)),
          ]),
        ),
        const SizedBox(height: 12),
        if (st == 'accepted') Text(t('Untick what you don’t have. The customer is told and the bill drops.'), style: tx(12.5, color: kMute)),
        for (var i = 0; i < ls.length; i++)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: st == 'accepted' ? !na.contains(i) : ls[i]['na'] != true,
            onChanged: st == 'accepted' && canOrders ? (v) => setState(() => v == true ? na.remove(i) : na.add(i)) : null,
            title: Text('${ls[i]['name']} ${ls[i]['size']} × ${ls[i]['qty']}',
                style: tx(14, weight: FontWeight.w700).copyWith(
                    decoration: (st == 'accepted' ? na.contains(i) : ls[i]['na'] == true) ? TextDecoration.lineThrough : null)),
            secondary: Text(money((ls[i]['price'] as num) * (ls[i]['qty'] as num)), style: tx(14, weight: FontWeight.w800)),
          ),
        const Divider(),
        if (fee > 0) Row(children: [Expanded(child: Text(t('Delivery fee'))), Text(money(fee))]),
        Row(children: [
          Expanded(child: Text(t('Collect from customer'), style: tx(15, weight: FontWeight.w800))),
          Text(money(total + fee), style: tx(18, weight: FontWeight.w800)),
        ]),
        const SizedBox(height: 16),
        if (st == 'placed' && canOrders) ...[
          Btn(busy ? '…' : t('Accept'), onTap: busy ? null : () => _do('accept')),
          const SizedBox(height: 8),
          Btn(t('Reject'), outline: true, onTap: busy ? null : _reject),
        ],
        if (st == 'accepted' && canOrders) ...[
          if (o['door'] == true && widget.staff.isNotEmpty) ...[
            Text(t('Who delivers?'), style: tx(13, color: kMute, weight: FontWeight.w700)),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: Text(t('Me')), selected: staffId == null, onSelected: (_) => setState(() => staffId = null)),
              for (final s in widget.staff)
                ChoiceChip(label: Text('${s['name']}'), selected: staffId == s['id'], onSelected: (_) => setState(() => staffId = '${s['id']}')),
            ]),
            const SizedBox(height: 10),
          ],
          Btn(busy ? '…' : (o['door'] == true ? t('Packed · send out') : t('Packed · ready for pickup')),
              onTap: busy ? null : () => _do('send', {'na': na.toList(), if (staffId != null) 'staffId': staffId})),
        ],
        if (st == 'out') ...[
          Text(t('Ask the customer for the 4-digit code (it is in their app).'), style: tx(13, color: kMute)),
          const SizedBox(height: 8),
          TextField(
            controller: code,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: tx(26, weight: FontWeight.w800).copyWith(letterSpacing: 10),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: field('••••').copyWith(counterText: ''),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Btn(t('Paid cash'), onTap: busy ? null : () => _deliver('cash'))),
            const SizedBox(width: 10),
            Expanded(child: Btn(t('Paid UPI'), outline: true, onTap: busy ? null : () => _deliver('upi'))),
          ]),
        ],
        if (st == 'delivered')
          Box(color: kOkBg, child: Text(tr('Delivered · {0} · bill {1}', ['${o['payMode']}'.toUpperCase(), o['billNo']]), style: tx(13.5, weight: FontWeight.w700))),
      ]),
    );
  }

  void _deliver(String pay) {
    if (code.text.length != 4) {
      toast(context, t('Enter all 4 digits.'));
      return;
    }
    _do('deliver', {'otp': code.text, 'pay': pay});
  }
}
