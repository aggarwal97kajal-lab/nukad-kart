import 'package:flutter/material.dart';
import '../ui.dart';
import 'home.dart';
import 'products.dart';

/// Bottom tabs once a partner is signed up. Orders join here next.
class PartnerShell extends StatefulWidget {
  const PartnerShell({super.key});
  @override
  State<PartnerShell> createState() => _PartnerShellState();
}

class _PartnerShellState extends State<PartnerShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: tab, children: const [HomeScreen(), ProductsScreen()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        backgroundColor: kCard,
        indicatorColor: kOkBg,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: t('Home')),
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2), label: t('Products')),
        ],
      ),
    );
  }
}
