import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/app_user.dart';
import '../../../models/payment.dart';
import '../../../services/auth_service.dart';
import '../../../services/db_service.dart';
import '../../../services/telegram_service.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  Future<void> _pay(BuildContext context, AppUser u) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final managerUid = context.read<AuthService>().user!.uid;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تسجيل سداد من ' + u.name),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amount, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ (ر.ي)')),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final a = double.tryParse(amount.text) ?? 0;
              if (a <= 0) return;
              Navigator.pop(ctx);
              final p = Payment(
                id: FirebaseFirestore.instance.collection('payments').doc().id,
                fromUid: u.uid, toUid: managerUid,
                amount: a, note: note.text.trim(), createdAt: DateTime.now(),
              );
              await DbService().addPayment(p);
              TelegramService.send('سداد جديد\nمن: ' + u.name + '\nالمبلغ: ' + a.toStringAsFixed(0) + ' ر.ي');
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Widget _userCard(BuildContext context, AppUser u) {
    return Card(
      child: FutureBuilder<double>(
        future: DbService().debtOf(u.uid),
        builder: (_, s) => ListTile(
          leading: const Icon(Icons.person),
          title: Text(u.name),
          subtitle: Text(u.role == 'agent' ? 'وكيل' : 'نقطة بيع'),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('المديونية: ' + (s.data ?? 0).toStringAsFixed(0) + ' ر.ي',
                style: TextStyle(color: (s.data ?? 0) > 0 ? Colors.red : Colors.green)),
            TextButton(onPressed: () => _pay(context, u), child: const Text('تسجيل سداد')),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().user!.uid;
    final db = DbService();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('طلبات الحسابات الجديدة', style: Theme.of(context).textTheme.titleLarge),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.pendingRequests(),
          builder: (_, s) {
            final docs = db.sortByCreatedDesc(s.data?.docs ?? []);
            if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text('لا توجد طلبات معلقة'));
            return Column(children: docs.map((d) {
              final r = d.data();
              return Card(
                child: ListTile(
                  title: Text(r['name'] ?? ''),
                  subtitle: Text((r['role'] == 'agent' ? 'وكيل' : 'نقطة بيع') + ' - ' + (r['phone'] ?? '')),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => db.approveRequest(d.id, r, uid)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => db.rejectRequest(d.id)),
                  ]),
                ),
              );
            }).toList());
          },
        ),
        const Divider(),
        Text('الوكلاء', style: Theme.of(context).textTheme.titleLarge),
        FutureBuilder<List<AppUser>>(
          future: db.childrenOf(uid, 'agent'),
          builder: (_, s) => Column(children: (s.data ?? []).map((u) => _userCard(context, u)).toList()),
        ),
        const Divider(),
        Text('نقاط البيع', style: Theme.of(context).textTheme.titleLarge),
        FutureBuilder<List<AppUser>>(
          future: db.childrenOf(uid, 'pos'),
          builder: (_, s) => Column(children: (s.data ?? []).map((u) => _userCard(context, u)).toList()),
        ),
      ],
    );
  }
}
