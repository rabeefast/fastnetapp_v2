import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../delivery/delivery_wizard.dart';

class AgentHome extends StatelessWidget {
  const AgentHome({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().profile!;
    final db = DbService();
    return Scaffold(
      appBar: AppBar(
        title: Text('فاست نت - ' + me.name),
        actions: [
          IconButton(icon: const Icon(Icons.logout),
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
          FutureBuilder<SettingsModel2>(
            future: db.loadSettings(me.parentUid ?? me.uid).then((s) => SettingsModel2(s)),
            builder: (_, ss) {
              final s = ss.data?.s;
              if (s == null) return const SizedBox.shrink();
              return Column(children: s.categories.map((c) => FutureBuilder<int>(
                future: db.countCards(db.stockQuery(me.uid, c.key)),
                builder: (_, x) => Card(
                  child: ListTile(title: Text('مخزونك فئة ' + c.label),
                      trailing: Text((x.data ?? 0).toString() + ' كرت')),
                ),
              )).toList());
            },
          ),
          const Divider(),
          FutureBuilder<List<AppUser>>(
            future: db.childrenOf(me.uid, 'pos'),
            builder: (_, s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نقاط البيع التابعة لك', style: Theme.of(context).textTheme.titleLarge),
                ...(s.data ?? []).map((p) => Card(
                  child: ListTile(title: Text(p.name), subtitle: const Text('نقطة بيع')),
                )),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.handshake),
                    label: const Text('تسليم كروت لنقطة بيع'),
                    onPressed: (s.data ?? []).isEmpty ? null : () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('تسليم لنقطة بيع')),
                          body: DeliveryWizard(side: 'ag', fromUid: me.uid, managerUid: me.parentUid ?? me.uid),
                        ),
                      ));
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsModel2 { final dynamic s; SettingsModel2(this.s); }
