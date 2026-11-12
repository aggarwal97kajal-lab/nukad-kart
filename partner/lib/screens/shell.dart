import 'package:flutter/material.dart';
import '../ui.dart';
import 'home.dart';
import 'produce_picker.dart';
import 'products.dart';
import 'orders.dart';
import '../push.dart';
import '../session.dart';
import '../thela_location.dart';

/// Which bottom tab is showing; Home's "Change prices" jumps to Products.
final shellTab = ValueNotifier<int>(0);

/// Bottom tabs once a partner is signed up. Orders join here next.
class PartnerShell extends StatefulWidget {
  const PartnerShell({super.key});
  @override
  State<PartnerShell> createState() => _PartnerShellState();
}

class _PartnerShellState extends State<PartnerShell> {
  @override
  void initState() {
    super.initState();
    shellTab.addListener(_tab);
    // A LIVE thela keeps sending its location, also after the app was closed and opened again.
    session.addListener(_loc);
    _loc();
    openedPush.addListener(_opened);
  }

  // Tapped a new-order notification: show the Orders tab.
  void _opened() {
    if (openedPush.value.startsWith('order_new') && session.store?['kind'] != 'thela') shellTab.value = 2;
  }

  void _loc() => ThelaLocation.instance.sync();

  @override
  void dispose() {
    shellTab.removeListener(_tab);
    session.removeListener(_loc);
    openedPush.removeListener(_opened);
    super.dispose();
  }

  void _tab() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final tab = shellTab.value;
    final thela = session.store?['kind'] == 'thela';
    return Scaffold(
      body: IndexedStack(index: thela && tab > 1 ? 0 : tab, children: [
        const HomeScreen(),
        thela ? const ProducePickerScreen() : const ProductsScreen(),
        if (!thela) const OrdersScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: thela && tab > 1 ? 0 : tab,
        backgroundColor: kCard,
        indicatorColor: kOkBg,
        onDestinationSelected: (i) => shellTab.value = i,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: t('Home')),
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2), label: t('Products')),
          if (!thela) NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: t('Orders')),
        ],
      ),
    );
  }
}
