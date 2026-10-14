import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import 'pages/accounts_page.dart';
import 'pages/batches_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/deliveries_page.dart';
import 'pages/history_page.dart';
import 'settings/settings_page.dart';

class ManagerShell extends StatefulWidget {
  const ManagerShell({super.key});
  @override
  State<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends State<ManagerShell> {
  int _index = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardPage(onNavigate: _navigate),
      const DeliveriesPage(),
      const BatchesPage(),
      const AccountsPage(),
      const HistoryPage(),
      const SettingsPage(),
    ];
  }

  void _navigate(int index) {
    if (index < 0 || index >= _pages.length) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فاست نت — المدير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.handshake), label: 'التسليم'),
          NavigationDestination(
            icon: Icon(Icons.inventory_2),
            label: 'الدفعات',
          ),
          NavigationDestination(icon: Icon(Icons.people), label: 'الحسابات'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'السجل'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}
