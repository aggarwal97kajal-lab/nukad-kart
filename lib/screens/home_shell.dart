import 'package:flutter/material.dart';
import '../l10n.dart';
import '../widgets/ui.dart';
import '../widgets/cart_widgets.dart';
import 'home_tab.dart';
import 'categories_tab.dart';
import 'orders_tab.dart';
import 'account_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: IndexedStack(index: index, children: [
        HomeTab(),
        CategoriesTab(),
        OrdersTab(),
        AccountTab(),
      ]),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (index < 2) CartBar(),
        NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: kCard,
            surfaceTintColor: kCard,
            indicatorColor: kGBg,
            labelTextStyle: WidgetStateProperty.resolveWith((states) => body(11.5,
                color: states.contains(WidgetState.selected) ? kG : kMute,
                weight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500)),
          ),
          child: NavigationBar(
            selectedIndex: index,
            height: 66,
            onDestinationSelected: (i) => setState(() => index = i),
            destinations: [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: kG), label: t('Home')),
              NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view, color: kG), label: t('Categories')),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long, color: kG), label: t('Orders')),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: kG), label: t('Account')),
            ],
          ),
        ),
      ]),
    );
  }
}
