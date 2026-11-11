import 'package:flutter/material.dart';
import '../l10n.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import 'order_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool? door;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (s.cartStoreId == null || s.cart.isEmpty) {
      return Scaffold(
        backgroundColor: kBg,
        appBar: simpleAppBar(t('Your cart')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('🛒', style: TextStyle(fontSize: 60)),
            SizedBox(height: 8),
            Text('Your cart is empty', style: head(18)),
          ]),
        ),
      );
    }
    final st = storeById(s.cartStoreId!);
    door ??= st.door;
    final entries = s.cart.entries.toList();
    return Scaffold(
      backgroundColor: kBg,
      appBar: simpleAppBar(t('Your cart'), subtitle: '${st.name} · ${st.distanceM} m'),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 12, 16, 20), children: [
        CardBox(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < entries.length; i++) _line(s, st.id, entries[i].key, entries[i].value, i == entries.length - 1),
          ]),
        ),
        SizedBox(height: 16),
        Text(t('How do you want it?'), style: head(15)),
        SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: _opt(t('Deliver to home'), s.address, true, st.door)),
          SizedBox(width: 10),
          Expanded(child: _opt(t('I’ll pick up'), 'At the shop counter', false, st.pickup)),
        ]),
        SizedBox(height: 16),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Bill details'), style: head(15)),
            SizedBox(height: 10),
            _billRow(t('Items total (incl. GST)'), rupees(s.cartTotal)),
            SizedBox(height: 6),
            _billRow(t('Delivery'), 'Free', color: kG),
            Divider(height: 22, color: kLine),
            _billRow(t('Pay at delivery'), rupees(s.cartTotal), bold: true, color: kGD),
          ]),
        ),
        SizedBox(height: 12),
        NoteBox(
          'Pay the store when your order arrives — cash or the store’s UPI QR. No online payment in the app.',
          icon: Icons.currency_rupee,
          color: kGD,
          bg: kGBg,
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(color: kCard, border: Border(top: BorderSide(color: kLine))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PrimaryButton('Place order · ${rupees(s.cartTotal)}', onTap: () => _place(context, s)),
            SizedBox(height: 6),
            Text(t('The store has 5 minutes to accept'), style: body(11, color: kMute)),
          ]),
        ),
      ),
    );
  }

  Future<void> _place(BuildContext context, AppState s) async {
    if (!s.acceptedTerms) {
      final ok = await _termsSheet(context);
      if (ok != true) return;
      s.acceptTerms();
    }
    final o = s.placeOrder(door: door ?? true);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OrderScreen(orderId: o.id)));
  }

  Future<bool?> _termsSheet(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: kCard,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        Widget point(String t, {bool warn = false}) => Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(warn ? Icons.close : Icons.check, size: 18, color: warn ? kRed : kG),
                SizedBox(width: 10),
                Expanded(child: Text(t, style: body(13.5))),
              ]),
            );
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
                child: Container(
                    width: 44, height: 5, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(3)))),
            SizedBox(height: 14),
            Text('Before your first order', style: head(20)),
            SizedBox(height: 14),
            point('You pay the store at delivery — cash or the store’s UPI. No online payment in the app.'),
            point('The store has 5 minutes to accept, or the order is cancelled automatically.'),
            point('Any refund comes from the store. Nukad Kart does not give refunds.'),
            point('Problems? Report in the app. We pass it to the store, keep a record, and can suspend stores at fault.'),
            point('3 orders not taken = account blocked (Google account, phone and number).', warn: true),
            SizedBox(height: 8),
            PrimaryButton('Agree & place order', onTap: () => Navigator.pop(ctx, true)),
          ]),
        );
      },
    );
  }

  Widget _opt(String title, String sub, bool isDoor, bool available) {
    final sel = available && door == isDoor;
    return Opacity(
      opacity: available ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: available ? () => setState(() => door = isDoor) : null,
        child: Container(
          height: 104,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: sel ? kGBg : kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? kG : kLine, width: sel ? 2 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? kG : Color(0xFFC5CFC6)),
            Spacer(),
            Text(title, style: body(14, weight: FontWeight.w700)),
            Text(available ? sub : 'Not offered by this store',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: kMute)),
          ]),
        ),
      ),
    );
  }

  Widget _billRow(String a, String b, {bool bold = false, Color? color}) => Row(children: [
        Expanded(child: Text(a, style: body(bold ? 15 : 13.5, color: bold ? kInk : kMute, weight: bold ? FontWeight.w700 : FontWeight.w400))),
        Text(b, style: body(bold ? 16 : 13.5, color: color ?? kInk, weight: bold ? FontWeight.w800 : FontWeight.w600)),
      ]);

  Widget _line(AppState s, String storeId, String pid, int qty, bool last) {
    final p = productById(pid);
    final l = listingFor(storeId, pid)!;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: kLine))),
      child: Row(children: [
        EmojiTile(p.emoji, size: 46),
        SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: body(14, weight: FontWeight.w600)),
            Text(p.size, style: body(12, color: kMute)),
          ]),
        ),
        QtyStepper(qty: qty, onAdd: () => s.add(storeId, pid), onRemove: () => s.remove(pid)),
        SizedBox(
            width: 58,
            child: Text(rupees(l.price * qty), textAlign: TextAlign.right, style: body(14, weight: FontWeight.w700))),
      ]),
    );
  }
}
