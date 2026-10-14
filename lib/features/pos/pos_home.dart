import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../auth/biometric_settings.dart';
import '../sale/sale_dialog.dart';

class PosHome extends StatefulWidget {
  const PosHome({super.key});

  @override
  State<PosHome> createState() => _PosHomeState();
}

class _PosHomeState extends State<PosHome> {
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().profile!;
    final db = DbService();
    return Scaffold(
      appBar: AppBar(
        title: Text('فاست نت - ${me.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fingerprint),
            tooltip: 'الأمان والبصمة',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BiometricSettingsPage(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<double>(
            key: ValueKey(_refreshKey),
            future: db.debtOf(me.uid),
            builder: (_, snapshot) => Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text('مديونيتك الحالية'),
                trailing: Text(
                  '${(snapshot.data ?? 0).toStringAsFixed(0)} ر.ي',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.point_of_sale),
              label: const Text('تسجيل بيع كروت'),
              onPressed: () async {
                final count = await showSaleDialog(context, me.uid);
                if (!mounted || count == null) return;
                setState(() => _refreshKey++);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم تسجيل بيع $count كرت')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
