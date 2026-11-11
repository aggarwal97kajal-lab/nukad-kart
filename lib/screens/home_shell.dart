import 'package:flutter/material.dart';
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
      body: IndexedStack(index: index, children: const [
        HomeTab(),
        CategoriesTab(),
        OrdersTab(),
        AccountTab(),
      ]),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (index < 2) const CartBar(),
        NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            indicatorColor: kGBg,
            labelTextStyle: WidgetStateProperty.resolveWith((states) => body(11.5,
                color: states.contains(WidgetState.selected) ? kG : kMute,
                weight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500)),
          ),
          child: NavigationBar(
            selectedIndex: index,
            height: 66,
            onDestinationSelected: (i) => setState(() => index = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: kG), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view, color: kG), label: 'Categories'),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long, color: kG), label: 'Orders'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: kG), label: 'Account'),
            ],
          ),
        ),
      ]),
    );
  }
}
