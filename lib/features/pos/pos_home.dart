import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/db_service.dart';

class PosHome extends StatelessWidget {
  const PosHome({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().profile!;
    final db = DbService();
    return Scaffold(
      appBar: AppBar(
        title: Text('فاست نت - ' + me.name),
        actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => context.read<AuthService>().signOut()),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<double>(
            future: db.debtOf(me.uid),
            builder: (_, s) => Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text('مديونيتك الحالية'),
                trailing: Text((s.data ?? 0).toStringAsFixed(0) + ' ر.ي',
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
