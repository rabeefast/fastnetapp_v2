import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/delivery.dart';
import '../../../services/auth_service.dart';
import '../../../services/db_service.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().user!.uid;
    return StreamBuilder<List<Delivery>>(
      stream: DbService().deliveriesForManager(uid),
      builder: (_, s) {
        if (s.hasError) {
          return const Center(
              child: Text('تعذر تحميل السجل؛ تحقق من الاتصال والصلاحيات.'));
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final deliveries = s.data!;
        if (deliveries.isEmpty) {
          return const Center(child: Text('لا توجد عمليات تسليم بعد'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: deliveries.length,
          itemBuilder: (_, i) {
            final d = deliveries[i];
            final dt = d.createdAt;
            final summary = d.items.map((e) {
              final c = e.type == 'pages'
                  ? e.pages.toString() + ' صفحة'
                  : e.cardSerials.length.toString() + ' كرت';
              return e.categoryKey + ': ' + c;
            }).join(' ، ');
            return Card(
              child: ListTile(
                leading: Icon(
                  d.side == 'mg' ? Icons.handshake : Icons.storefront,
                ),
                title: Text(
                  d.toName + ' - ' + d.totalAmount.toStringAsFixed(0) + ' ر.ي',
                ),
                subtitle: Text(
                  summary +
                      '\n' +
                      dt.day.toString() +
                      '/' +
                      dt.month.toString() +
                      '/' +
                      dt.year.toString(),
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}
