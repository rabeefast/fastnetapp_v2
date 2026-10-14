import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/settings_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/db_service.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().user!.uid;
    final db = DbService();
    return FutureBuilder<SettingsModel>(
      future: db.loadSettings(uid),
      builder: (_, ss) {
        final settings = ss.data;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.category),
                title: const Text('الفئات المتتبعة'),
                subtitle: Text(settings == null
                    ? 'جارٍ التحميل...'
                    : settings.categories.map((c) => c.label).join(' ، ')),
              ),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db.batchesOf(uid),
              builder: (_, s) => Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: const Text('الدفعات المستوردة'),
                  subtitle: Text((s.data?.size ?? 0).toString()),
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db.pendingRequests(),
              builder: (_, s) => Card(
                child: ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('طلبات حسابات بانتظار الموافقة'),
                  subtitle: Text((s.data?.size ?? 0).toString()),
                ),
              ),
            ),
            if (settings != null) ...[
              Text('المخزون الحالي (باليد)', style: Theme.of(context).textTheme.titleLarge),
              ...settings.categories.map((c) => FutureBuilder<int>(
                    future: db.countCards(db.stockQuery(uid, c.key)),
                    builder: (_, s) => Card(
                      child: ListTile(
                        title: Text('فئة ' + c.label),
                        trailing: Text((s.data ?? 0).toString() + ' كرت'),
                      ),
                    ),
                  )),
            ],
          ],
        );
      },
    );
  }
}
