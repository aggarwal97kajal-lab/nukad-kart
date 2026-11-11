import 'dart:async';
import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
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
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
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
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        _hero(o),
        const SizedBox(height: 12),
        CardBox(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Column(children: [
            _step('Order placed', o, OrderStatus.placed),
            _step('Accepted by store', o, OrderStatus.accepted),
            _step('Packed', o, OrderStatus.packed),
            _step(o.door ? 'Out for delivery' : 'Ready for pickup', o, OrderStatus.outForDelivery),
            _step('Delivered', o, OrderStatus.delivered),
          ]),
        ),
        const SizedBox(height: 12),
        NoteBox(
          o.status == OrderStatus.delivered
              ? 'Paid ${rupees(o.total)} to the store at delivery.'
              : 'Keep ${rupees(o.total)} ready — cash or scan the store’s UPI QR at your door.',
          icon: Icons.currency_rupee,
          color: kGD,
          bg: kGBg,
        ),
        const SizedBox(height: 12),
        CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            for (final l in o.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  EmojiTile(productById(l.productId).emoji, size: 40),
                  const SizedBox(width: 10),
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
        const SizedBox(height: 14),
        if (o.status == OrderStatus.placed)
          PrimaryButton('Cancel order', outline: true, color: kRed, onTap: () => s.cancelOrder(o)),
        if (o.status == OrderStatus.delivered) ...[
          if (s.ratings.containsKey(st.id))
            CardBox(
              child: Row(children: [
                Text('Your rating for this store', style: body(12.5, color: kMute)),
                const SizedBox(width: 8),
                StarRow(value: s.ratings[st.id]!, size: 16),
                const Spacer(),
                GestureDetector(
                  onTap: () => showRatingSheet(context, vendorId: st.id, vendorName: st.name, editing: true),
                  child: Text('Edit', style: body(13, color: kG, weight: FontWeight.w700)),
                ),
              ]),
            ),
          const SizedBox(height: 10),
          PrimaryButton('Report a problem', outline: true, color: kRed,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportScreen(order: o)))),
        ],
        const SizedBox(height: 10),
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
              const SizedBox(
                  width: 110, height: 110, child: CircularProgressIndicator(strokeWidth: 7, color: kG, backgroundColor: kGBg)),
              Text('$mm:$ss', style: head(24, color: kGD)),
            ]),
          ),
          const SizedBox(height: 12),
          Text('Waiting for the store to accept', textAlign: TextAlign.center, style: head(18)),
          const SizedBox(height: 4),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cancelled ? kRed : kGD, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: cancelled ? kRedBg : kLime, shape: BoxShape.circle),
          child: Icon(icon, color: cancelled ? kRed : kGD),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(statusLabel(o.status), style: head(19, color: Colors.white)),
            Text(cancelled ? 'You haven’t paid anything.' : 'Total ${rupees(o.total)} · pay at delivery',
                style: body(12.5, color: const Color(0xFFD7EED0))),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? kG : Colors.white,
            border: done ? null : Border.all(color: isNow ? kG : const Color(0xFFC5CFC6), width: 3),
          ),
          child: done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: body(14, color: done || isNow ? kInk : const Color(0xFF8A948D), weight: isNow ? FontWeight.w800 : FontWeight.w600)),
        ),
        Text(time, style: body(12, color: kMute)),
      ]),
    );
  }
}
