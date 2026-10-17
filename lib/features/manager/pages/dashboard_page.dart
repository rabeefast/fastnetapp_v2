import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/settings_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/db_service.dart';

class DashboardPage extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const DashboardPage({super.key, required this.onNavigate});

  static const _shortcuts = <({String label, IconData icon, int destination})>[
    (label: 'الرئيسية', icon: Icons.dashboard, destination: 0),
    (label: 'التسليم', icon: Icons.handshake, destination: 1),
    (label: 'الدفعات', icon: Icons.inventory_2, destination: 2),
    (label: 'الحسابات', icon: Icons.people, destination: 3),
    (label: 'السجل', icon: Icons.receipt_long, destination: 4),
    (label: 'الإعدادات', icon: Icons.settings, destination: 5),
  ];

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().user!.uid;
    final db = DbService();
    return FutureBuilder<SettingsModel>(
      future: db.loadSettings(uid),
      builder: (_, settingsSnapshot) {
        final settings = settingsSnapshot.data;
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _shortcuts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemBuilder: (context, index) {
                final shortcut = _shortcuts[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onNavigate(shortcut.destination),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(shortcut.icon, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            shortcut.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db.batchesOf(uid),
              builder: (_, snapshot) {
                final readyCount =
                    snapshot.data?.docs.where((doc) {
                      final status = doc.data()['importStatus']?.toString();
                      return status == null || status == 'ready';
                    }).length;
                final batchCount = snapshot.data?.size;
                final subtitle =
                    snapshot.hasError
                        ? 'تعذر التحميل (${snapshot.error is FirebaseException ? (snapshot.error! as FirebaseException).code : 'unknown'})'
                        : snapshot.hasData
                        ? '$batchCount دفعة · $readyCount مكتملة'
                        : 'جارٍ التحميل...';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2),
                    title: const Text('الدفعات المستوردة'),
                    subtitle: Text(subtitle),
                    onTap: () => onNavigate(2),
                  ),
                );
              },
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db.pendingRequests(),
              builder: (_, snapshot) {
                final subtitle =
                    snapshot.hasError
                        ? 'تعذر التحميل (${snapshot.error is FirebaseException ? (snapshot.error! as FirebaseException).code : 'unknown'})'
                        : snapshot.hasData
                        ? '${snapshot.data!.size} طلب'
                        : 'جارٍ التحميل...';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_add),
                    title: const Text('طلبات حسابات بانتظار الموافقة'),
                    subtitle: Text(subtitle),
                    onTap: () => onNavigate(3),
                  ),
                );
              },
            ),
            if (settings != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Text(
                  'المخزون الحالي',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ...settings.categories.map(
                (category) => FutureBuilder<int>(
                  future: db.stockCount(uid, category.key),
                  builder:
                      (_, snapshot) => Card(
                        child: ListTile(
                          title: Text('فئة ${category.label}'),
                          trailing: Text('${snapshot.data ?? 0} كرت'),
                          onTap: () => onNavigate(2),
                        ),
                      ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
