import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import '../widgets/live_map.dart';
import 'rating_sheet.dart';
import 'report_screen.dart';

class OrderScreen extends StatefulWidget {
  final String orderId;
  const OrderScreen({super.key, required this.orderId});
  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  Timer? _tick;
  bool _askedRating = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final o = s.orders.firstWhere((x) => x.id == widget.orderId);
    final st = storeById(o.storeId);

    if (o.status == OrderStatus.delivered && !_askedRating && s.shouldAskRating(st.id)) {
      _askedRating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showRatingSheet(context, vendorId: st.id, vendorName: st.name);
      });
    }

    return Scaffold(
      backgroundColor: kBg,
      appBar: simpleAppBar('Order #${o.id}', subtitle: st.name),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        if (o.status == OrderStatus.outForDelivery && o.door && o.times[OrderStatus.outForDelivery] != null)
          LiveDeliveryMap(
            key: ValueKey('map-${o.id}'),
            startedAt: o.times[OrderStatus.outForDelivery]!,
            eta: Duration(seconds: 6), // demo: the store marks it delivered 6 s later
            riderName: 'Raju',
            storeName: st.name,
            payable: o.payable,
            storePhone: st.phone,
          )
        else
          _hero(o),
        SizedBox(height: 12),
        CardBox(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Column(children: [
            _step(t('Order placed'), o, OrderStatus.placed),
            _step(t('Accepted by store'), o, OrderStatus.accepted),
            _step(t('Packed'), o, OrderStatus.packed),
            _step(o.door ? 'Out for delivery' : 'Ready for pickup', o, OrderStatus.outForDelivery),
            _step(t('Delivered'), o, OrderStatus.delivered),
          ]),
        ),
        SizedBox(height: 12),
        NoteBox(
          o.status == OrderStatus.delivered
              ? 'Paid ${rupees(o.payable)} to the store at delivery${o.fee > 0 ? ' (incl. ₹${o.fee} delivery fee)' : ''}.'
              : 'Keep ${rupees(o.payable)} ready — cash or scan the store’s UPI QR at your door'
                  '${o.fee > 0 ? ' (incl. ₹${o.fee} delivery fee)' : ''}.',
          icon: Icons.currency_rupee,
          color: kGD,
          bg: kGBg,
        ),
        SizedBox(height: 12),
        CardBox(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            for (final l in o.lines)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  EmojiTile(productById(l.productId).emoji, size: 40),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text('${productById(l.productId).name} · ${productById(l.productId).size}',
                          style: body(13.5, weight: FontWeight.w600))),
                  Text('×${l.qty}', style: body(13, color: kMute, weight: FontWeight.w700)),
                  SizedBox(
                      width: 60,
                      child: Text(rupees(l.price * l.qty),
                          textAlign: TextAlign.right, style: body(13.5, weight: FontWeight.w700))),
                ]),
              ),
          ]),
        ),
        SizedBox(height: 14),
        if (s.canCancel(o)) ...[
          PrimaryButton(t('Cancel order'), outline: true, color: kRed, onTap: () => _confirmCancel(context, s, o)),
          SizedBox(height: 6),
          Text('You can cancel until the store starts packing.',
              textAlign: TextAlign.center, style: body(12, color: kMute)),
        ] else if (o.status == OrderStatus.packed || o.status == OrderStatus.outForDelivery) ...[
          Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline, size: 18, color: kMute),
              SizedBox(width: 8),
              Text('Can’t cancel now', style: head(15, color: kMute)),
            ]),
          ),
          SizedBox(height: 8),
          NoteBox('The store has packed your order, so it can’t be cancelled. '
              'Need a change? Call the store: ${st.phone}.'),
        ],
        if (o.status == OrderStatus.delivered) ...[
          if (s.ratings.containsKey(st.id))
            CardBox(
              child: Row(children: [
                Text('Your rating for this store', style: body(12.5, color: kMute)),
                SizedBox(width: 8),
                StarRow(value: s.ratings[st.id]!, size: 16),
                Spacer(),
                GestureDetector(
                  onTap: () => showRatingSheet(context, vendorId: st.id, vendorName: st.name, editing: true),
                  child: Text(t('Edit'), style: body(13, color: kG, weight: FontWeight.w700)),
                ),
              ]),
            ),
          SizedBox(height: 10),
          PrimaryButton(t('Report a problem'), outline: true, color: kRed,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportScreen(order: o)))),
        ],
        SizedBox(height: 10),
        Text('Demo build: the store’s replies are simulated so you can see each step.',
            textAlign: TextAlign.center, style: body(11, color: kMute)),
      ]),
    );
  }

  Widget _hero(Order o) {
    if (o.status == OrderStatus.placed) {
      final left = 300 - DateTime.now().difference(o.placedAt).inSeconds;
      final mm = (left ~/ 60).clamp(0, 5);
      final ss = (left % 60).clamp(0, 59).toString().padLeft(2, '0');
      return CardBox(
        child: Column(children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                  width: 110, height: 110, child: CircularProgressIndicator(strokeWidth: 7, color: kG, backgroundColor: kGBg)),
              Text('$mm:$ss', style: head(24, color: kGText)),
            ]),
          ),
          SizedBox(height: 12),
          Text('Waiting for the store to accept', textAlign: TextAlign.center, style: head(18)),
          SizedBox(height: 4),
          Text('If the store doesn’t accept in 5 minutes, the order is cancelled automatically.',
              textAlign: TextAlign.center, style: body(12.5, color: kMute)),
        ]),
      );
    }
    final cancelled = o.status == OrderStatus.cancelled;
    final icon = switch (o.status) {
      OrderStatus.accepted => Icons.thumb_up_alt_outlined,
      OrderStatus.packed => Icons.shopping_bag_outlined,
      OrderStatus.outForDelivery => Icons.delivery_dining,
      OrderStatus.delivered => Icons.check_circle_outline,
      _ => Icons.cancel_outlined,
    };
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: cancelled ? kRed : kGD, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: cancelled ? kRedBg : kLime, shape: BoxShape.circle),
          child: Icon(icon, color: cancelled ? kRed : kGD),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(statusLabel(o.status), style: head(19, color: Colors.white)),
            Text(cancelled ? 'You haven’t paid anything.' : 'Total ${rupees(o.payable)} · pay at delivery',
                style: body(12.5, color: Color(0xFFE9E3C8))),
          ]),
        ),
      ]),
    );
  }

  Widget _step(String label, Order o, OrderStatus st) {
    final at = o.times[st];
    final done = at != null;
    final order = [
      OrderStatus.placed,
      OrderStatus.accepted,
      OrderStatus.packed,
      OrderStatus.outForDelivery,
      OrderStatus.delivered
    ];
    final cur = order.indexOf(o.status);
    final isNow = order.indexOf(st) == cur + 1 && o.isOpen;
    final time = at != null ? TimeOfDay.fromDateTime(at).format(context) : (isNow ? 'Next' : '');
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? kG : kCard,
            border: done ? null : Border.all(color: isNow ? kG : Color(0xFFC5CFC6), width: 3),
          ),
          child: done ? Icon(Icons.check, size: 14, color: kOnG) : null,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: body(14, color: done || isNow ? kInk : Color(0xFF8A948D), weight: isNow ? FontWeight.w800 : FontWeight.w600)),
        ),
        Text(time, style: body(12, color: kMute)),
      ]),
    );
  }

  Future<void> _confirmCancel(BuildContext context, AppState s, Order o) async {
    final strike = s.cancelCountsAsStrike(o);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        surfaceTintColor: kCard,
        title: Text('Cancel this order?', style: head(18)),
        content: Text(
          strike
              ? 'The store has already accepted it. Cancelling now counts as 1 of 3 “not taken” orders '
                  '(you have ${s.strikes} of 3). At 3, ordering is blocked.'
              : 'The store hasn’t accepted it yet, so this won’t count against you.',
          style: body(14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Keep order')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Cancel order', style: body(14, color: kRed, weight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) s.cancelOrder(o);
  }
}
