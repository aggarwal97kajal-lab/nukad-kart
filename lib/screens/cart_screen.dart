import 'package:flutter/material.dart';
import '../services/gstin.dart';
import '../l10n.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../services/api.dart';
import '../widgets/ui.dart';
import 'order_screen.dart';
import 'store_screen.dart';
import 'login_screen.dart';
import 'address_screen.dart';
import '../widgets/cart_widgets.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool? door;

  // Optional GST bill for a business buyer.
  bool _b2b = false;
  bool _b2bInit = false;
  final _gstin = TextEditingController();
  final _biz = TextEditingController();
  bool _gstinTouched = false;

  @override
  void dispose() {
    _gstin.dispose();
    _biz.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint, {String? error}) => InputDecoration(
        hintText: hint,
        hintStyle: body(13.5, color: kMute),
        errorText: error,
        isDense: true,
        filled: true,
        fillColor: kCard,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kLine)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kG, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kRed)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kRed, width: 2)),
      );

  Widget _b2bCard(Store st) {
    if (st.gst != BillGst.regular) {
      return Text('${st.name} is not GST-registered, so its bill has no GST to claim.',
          style: body(12, color: kMute));
    }
    final g = normalizeGstin(_gstin.text);
    final bad = _gstinTouched && g.isNotEmpty && !isValidGstin(g);
    return CardBox(
      padding: EdgeInsets.fromLTRB(14, 8, 8, _b2b ? 14 : 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.business_center_outlined, color: kGText, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Buying for a business?', style: body(14, weight: FontWeight.w700)),
              Text('Add your GSTIN to get a GST bill for input tax credit', style: body(11.5, color: kMute)),
            ]),
          ),
          Switch(value: _b2b, activeThumbColor: kG, onChanged: (v) => setState(() => _b2b = v)),
        ]),
        if (_b2b) ...[
          SizedBox(height: 10),
          TextField(
            controller: _gstin,
            textCapitalization: TextCapitalization.characters,
            maxLength: 15,
            onChanged: (_) => setState(() => _gstinTouched = normalizeGstin(_gstin.text).length >= 15),
            style: body(15, weight: FontWeight.w700).copyWith(letterSpacing: 1.2),
            decoration: _dec('GSTIN, e.g. 07ABCDE1234F1Z5', error: bad ? 'This GSTIN is not valid. Check it.' : null)
                .copyWith(counterText: ''),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _biz,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            style: body(14.5, weight: FontWeight.w600),
            decoration: _dec('Business name, as registered under GST'),
          ),
          SizedBox(height: 6),
          Text('Printed under “Bill to”. The shop reports it as a business sale so you can claim the credit.',
              style: body(11.5, color: kMute)),
        ],
      ]),
    );
  }

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
    if (!_b2bInit) {
      _b2bInit = true;
      _gstin.text = s.savedGstin;
      _biz.text = s.savedBusiness;
    }
    final entries = s.cart.entries.toList();
    final items = s.cartTotal;
    final isDoor = door ?? true;
    final fee = s.deliveryFeeFor(items, isDoor);
    final pay = items + fee;
    final short = kFreeDeliveryMin - items;
    return Scaffold(
      backgroundColor: kBg,
      appBar: simpleAppBar(t('Your cart'), subtitle: '${st.name} · ${st.distanceM} m'),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 12, 16, 20), children: [
        if (!s.canPlaceAnotherOrder) ...[
          NoteBox('You have ${AppState.maxLiveOrders} orders on the way. You can place this one after one of them is delivered.',
              icon: Icons.info_outline, color: kAmb, bg: kAmbBg),
          SizedBox(height: 12),
        ],
        if (isDoor) ...[
          _addressCard(context, s),
          if (!s.serviceable) ...[
            SizedBox(height: 8),
            NoteBox('${st.name} doesn’t deliver to ${s.current.label} (${s.current.pin}). '
                'Pick another address or choose pickup.', icon: Icons.error_outline, color: kRed, bg: kRedBg),
            if (s.here != null) ...[
              // Ordering in a new area: add the address here first (or pick a saved one near this shop).
              SizedBox(height: 8),
              PrimaryButton(t('Add an address here'), onTap: () => showAddressPicker(context, title: t('Delivery address in this area'))),
            ],
          ],
          SizedBox(height: 12),
        ],
        if (isDoor && short > 0) ...[
          _freeDeliveryNudge(context, st, items, short),
          SizedBox(height: 12),
        ],
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
              child: _opt(t('Deliver'), 'To ${s.current.label}', true, st.door)),
          SizedBox(width: 10),
          Expanded(child: _opt(t('I’ll pick up'), 'At the shop counter', false, st.pickup)),
        ]),
        SizedBox(height: 12),
        _b2bCard(st),
        SizedBox(height: 16),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Bill details'), style: head(15)),
            SizedBox(height: 10),
            _billRow(t('Items total (incl. GST)'), rupees(items)),
            SizedBox(height: 6),
            _billRow(t('Delivery fee'), !isDoor ? 'Pickup' : (fee == 0 ? 'Free' : rupees(fee)),
                color: fee == 0 ? kG : kAmb),
            if (isDoor)
              Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text('Free on orders of ₹$kFreeDeliveryMin or more',
                    style: body(11.5, color: kMute)),
              ),
            Divider(height: 22, color: kLine),
            _billRow(isDoor ? t('Pay at delivery') : 'Pay at pickup', rupees(pay), bold: true, color: kGText),
          ]),
        ),
        SizedBox(height: 12),
        NoteBox(
          'Pay the store when your order arrives — cash or the store’s UPI QR. No online payment in the app.',
          icon: Icons.currency_rupee,
          color: kGText,
          bg: kGBg,
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(color: kCard, border: Border(top: BorderSide(color: kLine))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PrimaryButton('Place order · ${rupees(pay)}', onTap: () => _place(context, s)),
            SizedBox(height: 6),
            Text(t('The store has 5 minutes to accept'), style: body(11, color: kMute)),
          ]),
        ),
      ),
    );
  }

  Future<void> _place(BuildContext context, AppState s) async {
    if (!s.signedIn) {
      final ok = await requireLogin(context);
      if (!ok || !context.mounted) return;
    }
    final shop = storeById(s.cartStoreId!);
    if (!shop.isOpen) {
      await showShopClosed(context, shop);
      return;
    }
    if ((door ?? true) && !s.serviceable) {
      showToast(context, '${shop.name} doesn’t deliver to ${s.current.short}. Change the address or choose pickup.');
      return;
    }
    if (!s.canPlaceAnotherOrder) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kCard,
          surfaceTintColor: kCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('You already have ${AppState.maxLiveOrders} live orders', style: head(19)),
          content: Text(
            'You can have up to ${AppState.maxLiveOrders} orders on the way at a time. '
            'Your cart is saved: place this order as soon as one of them is delivered.',
            style: body(14, color: kMute),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK', style: body(14, color: kGText, weight: FontWeight.w800))),
          ],
        ),
      );
      return;
    }
    if (!s.acceptedTerms) {
      final ok = await _termsSheet(context);
      if (ok != true) return;
      s.acceptTerms();
    }
    var gstin = '', business = '';
    if (_b2b && shop.gst == BillGst.regular) {
      gstin = normalizeGstin(_gstin.text);
      business = _biz.text.trim();
      if (!isValidGstin(gstin)) {
        setState(() => _gstinTouched = true);
        showToast(context, 'Enter a valid GSTIN, or turn off “Buying for a business”.');
        return;
      }
      if (business.length < 2) {
        showToast(context, 'Enter the business name as registered under GST.');
        return;
      }
    }
    final Order o;
    try {
      o = await s.placeOrderOnline(door: door ?? true, gstin: gstin, business: business);
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message);
      return;
    }
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

  /// Blinkit-style: where it's going, with a Change button.
  Widget _addressCard(BuildContext context, AppState s) {
    final a = s.current;
    return CardBox(
      padding: EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: kSurf, borderRadius: BorderRadius.circular(12)),
          child: Icon(labelIcon(a.label), color: kGText),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(deliverToLabel(a.label), style: body(11.5, color: kGText, weight: FontWeight.w800)),
            Text(a.short, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w600)),
            if (a.name.isNotEmpty)
              Text('${a.name} · +91 ${a.phone}', style: body(12, color: kMute))
            else
              Text('${a.city} ${a.pin}', style: body(12, color: kMute)),
          ]),
        ),
        SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => showAddressPicker(context, title: 'Select delivery address'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kG,
            side: BorderSide(color: kG, width: 1.5),
            minimumSize: Size(0, 36),
            padding: EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Change', style: body(13, color: kG, weight: FontWeight.w800)),
        ),
      ]),
    );
  }

  /// G06: "Add items worth ₹X more for free delivery".
  Widget _freeDeliveryNudge(BuildContext context, Store st, int items, int short) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
          color: kAmbBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Color(0x66E89B1C), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('🛵', style: TextStyle(fontSize: 20)),
          SizedBox(width: 10),
          Expanded(
              child: Text('Add items worth ${rupees(short)} more for free delivery',
                  style: body(13.5, color: kAmb, weight: FontWeight.w700))),
        ]),
        SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (items / kFreeDeliveryMin).clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            color: kAmb,
            backgroundColor: Color(0x33E89B1C),
          ),
        ),
        SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('${rupees(items)} of ₹$kFreeDeliveryMin', style: body(12, color: kMute))),
          OutlinedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen(store: st))),
            style: OutlinedButton.styleFrom(
                foregroundColor: kAmb,
                backgroundColor: kCard,
                side: BorderSide(color: kAmb, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                padding: EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size(0, 36)),
            child: Text('+ Add more items', style: body(12.5, color: kAmb, weight: FontWeight.w800)),
          ),
        ]),
      ]),
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
    final l0 = listingFor(storeId, pid);
    if (l0 == null) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: kLine))),
        child: Row(children: [
          EmojiTile(p.emoji, size: 46),
          SizedBox(width: 12),
          Expanded(child: Text('${p.name} — not available now', style: body(13, color: kMute))),
          TextButton(onPressed: () { for (var i = 0; i < qty; i++) { s.remove(pid); } }, child: Text('Remove')),
        ]),
      );
    }
    final l = l0;
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
