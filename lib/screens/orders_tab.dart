import 'package:flutter/material.dart';
import '../l10n.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../services/bill_pdf.dart';
import '../widgets/ui.dart';
import '../widgets/cart_widgets.dart';
import 'cart_screen.dart';
import 'order_screen.dart';
import 'rating_sheet.dart';

class OrdersTab extends StatelessWidget {
  final bool header;
  const OrdersTab({super.key, this.header = true});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Column(children: [
      if (header)
        Container(
          color: kCard,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [Text(t('Your orders'), style: head(21))]),
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
                separatorBuilder: (_, __) => SizedBox(height: 12),
                itemBuilder: (_, i) => OrderHistoryCard(order: s.orders[i]),
              ),
      ),
    ]);
  }
}

class OrderHistoryCard extends StatelessWidget {
  final Order order;
  const OrderHistoryCard({super.key, required this.order});

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _when(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
  }

  Future<void> _reorder(BuildContext context) async {
    final s = AppScope.read(context);
    final st = storeById(order.storeId);
    if (!st.isOpen) {
      await showShopClosed(context, st);
      return;
    }
    if (s.cartCount > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kCard,
          surfaceTintColor: kCard,
          title: Text('Replace your cart?', style: head(19)),
          content: Text('Your current cart will be cleared and filled with this order’s items.', style: body(14, color: kMute)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Cancel'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Replace')),
          ],
        ),
      );
      if (ok != true) return;
    }
    final n = s.reorder(order);
    if (!context.mounted) return;
    if (n == 0) {
      showToast(context, 'These items are out of stock at ${st.name} right now.');
      return;
    }
    if (n < order.lines.length) showToast(context, '${order.lines.length - n} item(s) are out of stock and were left out.');
    Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final o = order;
    final st = storeById(o.storeId);
    final delivered = o.status == OrderStatus.delivered;
    final rated = s.ratings[st.id];
    final mins = delivered && o.times[OrderStatus.delivered] != null
        ? o.times[OrderStatus.delivered]!.difference(o.placedAt).inMinutes.clamp(1, 999)
        : null;
    final (Color c, Color bg) = switch (o.status) {
      OrderStatus.delivered => (kG, kGBg),
      OrderStatus.cancelled || OrderStatus.rejected || OrderStatus.autoCancelled => (kRed, kRedBg),
      OrderStatus.placed => (kAmb, kAmbBg),
      _ => (kBlu, kBluBg),
    };
    final icon = switch (o.status) {
      OrderStatus.delivered => Icons.check_rounded,
      OrderStatus.cancelled || OrderStatus.rejected || OrderStatus.autoCancelled => Icons.close_rounded,
      _ => Icons.schedule_rounded,
    };
    Widget action(String label, IconData ic, VoidCallback onTap, {bool left = false}) => Expanded(
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(border: left ? Border(left: BorderSide(color: kLine)) : null),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(ic, size: 18, color: kGText),
                SizedBox(width: 6),
                Text(label, style: body(14, color: kGText, weight: FontWeight.w800)),
              ]),
            ),
          ),
        );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
      child: Column(children: [
        InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderScreen(orderId: o.id))),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 10, 10),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: c, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(mins != null ? 'Delivered in $mins min' : statusLabel(o.status), style: body(15.5, weight: FontWeight.w800)),
                    Text('${st.name} · ${rupees(o.payable)} · ${_when(o.placedAt)}',
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: body(12.5, color: kMute)),
                  ]),
                ),
                if (delivered)
                  IconButton(
                    tooltip: 'Download bill',
                    onPressed: () async {
                      try {
                        await downloadBill(o);
                      } catch (_) {
                        if (context.mounted) showToast(context, 'Could not open the bill. Try again.');
                      }
                    },
                    icon: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.download_rounded, color: kGText, size: 22),
                      Text('Bill', style: body(10.5, color: kGText, weight: FontWeight.w800)),
                    ]),
                  ),
              ]),
              SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final l in o.lines.take(5)) EmojiTile(productById(l.productId).emoji, size: 54),
                  if (o.lines.length > 5)
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: kSurf, borderRadius: BorderRadius.circular(13)),
                      child: Text('+${o.lines.length - 5}', style: body(14, weight: FontWeight.w800)),
                    ),
                ]),
              ),
            ]),
          ),
        ),
        if (delivered && rated != null)
          Container(
            margin: EdgeInsets.fromLTRB(14, 0, 14, 12),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: kSurf, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              StarRow(value: rated, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('You rated $rated', style: body(13, weight: FontWeight.w700))),
              GestureDetector(
                onTap: () => showRatingSheet(context, vendorId: st.id, vendorName: st.name, editing: true),
                child: Text('Edit', style: body(13, color: kGText, weight: FontWeight.w800)),
              ),
            ]),
          ),
        Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: kLine))),
          child: Row(children: [
            action(t('Reorder'), Icons.replay_rounded, () => _reorder(context)),
            if (delivered && rated == null)
              action(t('Rate order'), Icons.star_border_rounded,
                  () => showRatingSheet(context, vendorId: st.id, vendorName: st.name),
                  left: true),
          ]),
        ),
      ]),
    );
  }
}
