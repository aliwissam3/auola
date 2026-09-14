import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import 'debts_screen.dart';
import 'login_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'sales_screen.dart';
import 'settings_screen.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final Widget Function() builder;
  final bool adminOnly;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.builder,
    this.adminOnly = false,
  });
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _items = <_NavItem>[
    _NavItem(label: 'المنتجات', icon: Icons.inventory_2_outlined, builder: () => const ProductsScreen()),
    _NavItem(label: 'المبيعات', icon: Icons.point_of_sale_outlined, builder: () => const SalesScreen()),
    _NavItem(label: 'الديون', icon: Icons.credit_score_outlined, builder: () => const DebtsScreen()),
    _NavItem(label: 'التقارير', icon: Icons.bar_chart_outlined, builder: () => const ReportsScreen()),
    _NavItem(label: 'الإعدادات', icon: Icons.settings_outlined, builder: () => const SettingsScreen(), adminOnly: true),
  ];

  List<_NavItem> _visibleItems(bool isAdmin) {
    return _items.where((item) => !item.adminOnly || isAdmin).toList();
  }

  void _logout() {
    context.read<Session>().logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final items = _visibleItems(session.isAdmin);
    final index = _index.clamp(0, items.length - 1);

    final destinationsRail = items
        .map((item) => NavigationRailDestination(
              icon: Icon(item.icon),
              label: Text(item.label),
            ))
        .toList();

    final destinationsBar = items
        .map((item) => NavigationDestination(icon: Icon(item.icon), label: item.label))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('محلي — ${session.employee?.name ?? ''}'),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final page = items[index].builder();
          if (wide) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: destinationsRail,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: page),
              ],
            );
          }
          return page;
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          if (wide) return const SizedBox.shrink();
          return NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: destinationsBar,
          );
        },
      ),
    );
  }
}
