import 'package:flutter/material.dart';
import '../l10n.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import 'order_screen.dart';

class OrdersTab extends StatelessWidget {
  final bool header;
  const OrdersTab({super.key, this.header = true});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Column(children: [
      if (header) Container(
        color: kCard,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [Text(t('My orders'), style: head(21))]),
          ),
        ),
      ),
      if (header) Divider(height: 1, color: kLine),
      Expanded(
        child: s.orders.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('🧾', style: TextStyle(fontSize: 56)),
                  SizedBox(height: 8),
                  Text(t('No orders yet'), style: head(18)),
                  SizedBox(height: 4),
                  Text('Order from a shop near you to see it here.', style: body(13, color: kMute)),
                ]),
              )
            : ListView.separated(
                padding: EdgeInsets.all(16),
                itemCount: s.orders.length,
                separatorBuilder: (_, __) => SizedBox(height: 10),
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
                        SizedBox(height: 4),
                        Text(o.lines.map((l) => productById(l.productId).name).join(', '),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: kMute)),
                        SizedBox(height: 4),
                        Row(children: [
                          Text(o.door ? t('Door delivery') : t('Pickup'), style: body(13, color: kGText, weight: FontWeight.w600)),
                          Spacer(),
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
