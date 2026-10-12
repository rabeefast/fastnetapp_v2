import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/auth_service.dart';
import '../../../state/app_state.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().user!.uid;
    final settings = context.watch<AppState>().settings;
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
        FutureBuilder<int>(
          future: FirebaseFirestore.instance
              .collection('batches')
              .where('managerUid', isEqualTo: uid)
              .get()
              .then((s) => s.size),
          builder: (_, s) => Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('الدفعات المستوردة'),
              subtitle: Text('${s.data ?? 0}'),
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.handshake),
            title: Text('التسليم والمديونيات'),
            subtitle: Text('تُفعّل في المرحلة الثانية'),
          ),
        ),
      ],
    );
  }
}
