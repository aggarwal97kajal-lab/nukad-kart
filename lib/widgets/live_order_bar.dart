import 'dart:async';
import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../screens/order_screen.dart';
import 'ui.dart';

/// Dark bar above the bottom menu while an order is live. Tap: open the order
/// (or, with 2 live orders, a list of both).
class LiveOrderBar extends StatefulWidget {
  const LiveOrderBar({super.key});
  @override
  State<LiveOrderBar> createState() => _LiveOrderBarState();
}

class _LiveOrderBarState extends State<LiveOrderBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Refresh the "time left to accept" countdown.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && AppScope.read(context).liveOrders.any((o) => o.status == OrderStatus.placed)) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static String _left(Order o) {
    final left = (300 - DateTime.now().difference(o.placedAt).inSeconds).clamp(0, 300);
    return '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
  }

  static (String, String) texts(Order o) {
    final st = storeById(o.storeId);
    return switch (o.status) {
      OrderStatus.placed => ('Waiting for the shop to accept', '${st.name} · ${_left(o)} left to accept'),
      OrderStatus.accepted => ('Order accepted', '${st.name} is getting it ready'),
      OrderStatus.packed => (o.door ? 'Packed · leaving soon' : 'Packed', '${st.name} · #${o.id}'),
      OrderStatus.outForDelivery => (o.door ? 'On the way' : 'Ready for pickup', '${st.name} · #${o.id} · track your order'),
      _ => (statusLabel(o.status), st.name),
    };
  }

  static Widget icon(Order o, {double size = 46}) {
    if (o.status == OrderStatus.outForDelivery && o.door) {
      return Container(
        width: size + 10,
        height: size,
        decoration: BoxDecoration(color: const Color(0xFF2F4527), borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(3),
        child: Image.asset('assets/images/markers/bike.png', fit: BoxFit.contain),
      );
    }
    final ic = switch (o.status) {
      OrderStatus.placed => Icons.hourglass_top_rounded,
      OrderStatus.accepted => Icons.storefront_outlined,
      OrderStatus.packed => Icons.inventory_2_outlined,
      _ => Icons.shopping_bag_outlined,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kBrand, width: 2.5)),
      child: Icon(ic, color: kBrand, size: size * .5),
    );
  }

  static Widget codeChip(Order o) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: kBrand, borderRadius: BorderRadius.circular(10)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('CODE', style: body(8.5, color: kOnBrand, weight: FontWeight.w800)),
          Text(o.otp ?? '', style: body(15, color: kOnBrand, weight: FontWeight.w800).copyWith(letterSpacing: 2)),
        ]),
      );

  void _open(BuildContext context, List<Order> live) {
    if (live.length == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => OrderScreen(orderId: live.first.id)));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(3)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your live orders', style: head(20)),
                Text('${live.length} separate orders from ${live.map((o) => o.storeId).toSet().length} shop(s)',
                    style: body(12.5, color: kMute)),
              ]),
            ),
            for (final o in live)
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => OrderScreen(orderId: o.id)));
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: kLine))),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: storeImage(storeById(o.storeId).photo, width: 48, height: 48),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(storeById(o.storeId).name, style: body(14.5, weight: FontWeight.w700)),
                        Text(texts(o).$1, style: body(12.5, color: kGText, weight: FontWeight.w700)),
                        Text('#${o.id} · ${o.itemCount} item${o.itemCount == 1 ? '' : 's'} · ${rupees(o.payable)}',
                            style: body(12, color: kMute)),
                      ]),
                    ),
                    if (o.otp != null) codeChip(o) else Icon(Icons.chevron_right, color: kMute),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final live = s.liveOrders;
    if (live.isEmpty) return const SizedBox.shrink();
    final one = live.length == 1 ? live.first : null;
    final names = live.map((o) => storeById(o.storeId).name.split(' ').first).join(', ');
    final (title, sub) = one != null
        ? texts(one)
        : ('${live.length} orders live · $names', live.map((o) => '${storeById(o.storeId).name.split(' ').first}: ${texts(o).$1.toLowerCase()}').join(' · '));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Material(
        color: const Color(0xFF21331B),
        borderRadius: BorderRadius.circular(18),
        elevation: 6,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _open(context, live),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(children: [
              Stack(clipBehavior: Clip.none, children: [
                icon(one ?? live.first),
                if (one == null)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: kBrand, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF21331B), width: 2)),
                      child: Text('${live.length}', style: body(11.5, color: kOnBrand, weight: FontWeight.w800)),
                    ),
                  ),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: body(15, color: Colors.white, weight: FontWeight.w800)),
                  Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: body(12, color: Colors.white.withAlpha(215))),
                ]),
              ),
              const SizedBox(width: 8),
              if (one != null && one.otp != null) ...[codeChip(one), const SizedBox(width: 8)],
              Text(one == null ? 'View' : 'Track', style: body(13, color: kBrand, weight: FontWeight.w800)),
              Icon(Icons.chevron_right, color: kBrand, size: 18),
            ]),
          ),
        ),
      ),
    );
  }
}
