import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/settings_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/db_service.dart';

class BatchesPage extends StatelessWidget {
  const BatchesPage({super.key});

  Future<void> _newBatch(BuildContext context, String uid) async {
    final s = await DbService().loadSettings(uid);
    final nameCtrl = TextEditingController(text: 'دفعة ' + DateFormat('yyyy-MM-dd').format(DateTime.now()));
    String cat = s.categories.first.key;
    final firstSerial = TextEditingController();
    final count = TextEditingController();
    final firstCard = TextEditingController();
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('دفعة كروت جديدة'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الدفعة')),
            DropdownButtonFormField<String>(
              value: cat,
              decoration: const InputDecoration(labelText: 'الفئة'),
              items: s.categories.map((c) => DropdownMenuItem(value: c.key, child: Text(c.label))).toList(),
              onChanged: (v) => setS(() => cat = v!),
            ),
            TextField(controller: firstSerial, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'أول رقم تسلسلي')),
            TextField(controller: count, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'عدد الكروت')),
            TextField(controller: firstCard, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'أول رقم كرت (اسم المستخدم)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final n = int.tryParse(count.text) ?? 0;
                final fs = int.tryParse(firstSerial.text) ?? 0;
                final fc = int.tryParse(firstCard.text) ?? 0;
                if (n < 1 || fs < 1 || fc < 1) return;
                Navigator.pop(ctx);
                await DbService().createBatch(
                    managerUid: uid, name: nameCtrl.text.trim(), categoryKey: cat,
                    firstSerial: fs, count: n, firstCardNo: fc);
              },
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().user!.uid;
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: DbService().batchesOf(uid),
        builder: (_, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final docs = s.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('لا توجد دفعات بعد'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: Text(d['name'] ?? ''),
                  subtitle: Text('الفئة: ' + (d['categoryKey'] ?? '') +
                      ' - من تسلسل ' + (d['firstSerial']?.toString() ?? '') +
                      ' - ' + (d['count']?.toString() ?? '') + ' كرت'),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newBatch(context, uid),
        icon: const Icon(Icons.add),
        label: const Text('دفعة جديدة'),
      ),
    );
  }
}
