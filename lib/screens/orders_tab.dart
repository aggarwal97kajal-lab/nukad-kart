import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import 'order_screen.dart';

class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Column(children: [
      Container(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [Text('My orders', style: head(21))]),
          ),
        ),
      ),
      const Divider(height: 1, color: kLine),
      Expanded(
        child: s.orders.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🧾', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 8),
                  Text('No orders yet', style: head(18)),
                  const SizedBox(height: 4),
                  Text('Order from a shop near you to see it here.', style: body(13, color: kMute)),
                ]),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: s.orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final o = s.orders[i];
                  final st = storeById(o.storeId);
                  final (Color c, Color bg) = switch (o.status) {
                    OrderStatus.delivered => (kG, kGBg),
                    OrderStatus.cancelled || OrderStatus.rejected || OrderStatus.autoCancelled => (kRed, kRedBg),
                    OrderStatus.placed => (kAmb, kAmbBg),
                    _ => (kBlu, kBluBg),
                  };
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => OrderScreen(orderId: o.id))),
                    child: CardBox(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('#${o.id} · ${st.name}', style: body(14, weight: FontWeight.w800))),
                          Pill(statusLabel(o.status), color: c, bg: bg),
                        ]),
                        const SizedBox(height: 4),
                        Text(o.lines.map((l) => productById(l.productId).name).join(', '),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: kMute)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Text(o.door ? 'Door delivery' : 'Pickup', style: body(13, color: kGD, weight: FontWeight.w600)),
                          const Spacer(),
                          Text('${rupees(o.total)} at delivery', style: body(13.5, weight: FontWeight.w800)),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}
