import 'package:flutter/material.dart';
import '../l10n.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../screens/cart_screen.dart';
import 'ui.dart';

/// Adds a product, enforcing "one store at a time".
Future<void> tryAddToCart(BuildContext context, String storeId, String productId) async {
  final s = AppScope.read(context);
  if (s.canAddFrom(storeId)) {
    s.add(storeId, productId);
    return;
  }
  final current = storeById(s.cartStoreId!);
  final next = storeById(storeId);
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kCard,
      surfaceTintColor: kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text('You can order from one store at a time', style: head(19)),
      content: Text(
        'Your cart has ${s.cartCount} item(s) (${rupees(s.cartTotal)}) from ${current.name}. '
        'Start a new cart with ${next.name}? Your current cart will be cleared.',
        style: body(14, color: kMute),
      ),
      actionsPadding: EdgeInsets.fromLTRB(20, 0, 20, 18),
      actions: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          PrimaryButton('Yes, start new cart', onTap: () => Navigator.pop(ctx, true), height: 48),
          SizedBox(height: 10),
          PrimaryButton('No, keep ${current.name.split(' ').first} cart',
              outline: true, onTap: () => Navigator.pop(ctx, false), height: 48),
        ]),
      ],
    ),
  );
  if (yes == true) {
    s.startNewCart(storeId, productId);
    if (context.mounted) showToast(context, 'New cart started · ${current.name} items removed');
  }
}

class CartBar extends StatelessWidget {
  const CartBar({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (s.cartCount == 0 || s.cartStoreId == null) return SizedBox.shrink();
    final store = storeById(s.cartStoreId!);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Material(
          color: kG,
          elevation: 8,
          shadowColor: Color(0x591E7A2E),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen())),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Color(0x2EFFFFFF), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.shopping_bag_outlined, color: Colors.white),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${s.cartCount} item${s.cartCount > 1 ? 's' : ''} · ${store.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: body(11.5, color: Color(0xFFD7EED0))),
                    Text(rupees(s.cartTotal), style: head(17, color: Colors.white)),
                  ]),
                ),
                Text(t('View cart'), style: head(15, color: Colors.white)),
                Icon(Icons.chevron_right, color: Colors.white),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
