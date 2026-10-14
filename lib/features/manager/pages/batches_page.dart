import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/initial_dropdown_form_field.dart';
import '../../../models/settings_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/db_service.dart';
import 'batch_cards_page.dart';
import 'pdf_batch_import_page.dart';

class BatchesPage extends StatelessWidget {
  const BatchesPage({super.key});

  Future<void> _importPdf(BuildContext context, String uid) async {
    final SettingsModel settings;
    try {
      settings = await DbService().loadSettings(uid);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل الفئات من Firestore.')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    if (settings.categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أضف فئة واحدة على الأقل من الإعدادات أولًا.'),
        ),
      );
      return;
    }
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PdfBatchImportPage(
          managerUid: uid,
          categories: settings.categories,
        ),
      ),
    );
    if (context.mounted && imported == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم استيراد الدفعة. افتحها لمراجعة جدول الكروت.'),
        ),
      );
    }
  }

  Future<void> _newBatch(BuildContext context, String uid) async {
    final SettingsModel s;
    try {
      s = await DbService().loadSettings(uid);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحميل الإعدادات؛ تحقق من اتصال Firestore.'),
          ),
        );
      }
      return;
    }
    if (s.categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أضف فئة واحدة على الأقل من الإعدادات أولًا.'),
        ),
      );
      return;
    }
    final nameCtrl = TextEditingController(
      text: 'دفعة ' + DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    String cat = s.categories.first.key;
    final firstSerial = TextEditingController();
    final count = TextEditingController();
    final firstCard = TextEditingController();
    String? error;
    bool saving = false;
    if (!context.mounted) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(saving ? 'جارٍ إنشاء الدفعة...' : 'دفعة كروت جديدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الدفعة'),
              ),
              InitialDropdownFormField<String>(
                initialValue: cat,
                decoration: const InputDecoration(labelText: 'الفئة'),
                items: s.categories
                    .map(
                      (c) =>
                          DropdownMenuItem(value: c.key, child: Text(c.label)),
                    )
                    .toList(),
                onChanged: (v) => setS(() => cat = v!),
              ),
              TextField(
                controller: firstSerial,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'أول رقم تسلسلي'),
              ),
              TextField(
                controller: count,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'عدد الكروت'),
              ),
              TextField(
                controller: firstCard,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'أول رقم كرت (اسم المستخدم)',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final n = int.tryParse(count.text) ?? 0;
                      final fs = int.tryParse(firstSerial.text) ?? 0;
                      final fc = int.tryParse(firstCard.text) ?? 0;
                      if (nameCtrl.text.trim().isEmpty ||
                          n < 1 ||
                          fs < 1 ||
                          fc < 1) {
                        setS(() => error = 'أدخل اسمًا وأرقامًا موجبة صحيحة.');
                        return;
                      }
                      setS(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await DbService().createBatch(
                          managerUid: uid,
                          name: nameCtrl.text.trim(),
                          categoryKey: cat,
                          firstSerial: fs,
                          count: n,
                          firstCardNo: fc,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setS(() {
                          saving = false;
                          error = e is StateError
                              ? 'بعض أرقام الكروت مستخدمة مسبقًا؛ غيّر رقم البداية.'
                              : e is ArgumentError
                                  ? e.message.toString()
                                  : 'تعذر إنشاء الدفعة. تحقق من الإنترنت والصلاحيات ثم أعد المحاولة.';
                        });
                      }
                    },
              child: Text(saving ? 'جارٍ الإنشاء...' : 'إنشاء'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    firstSerial.dispose();
    count.dispose();
    firstCard.dispose();
    if (context.mounted && created == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء الدفعة دون استبدال كروت موجودة.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().user!.uid;
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: DbService().batchesOf(uid),
        builder: (_, s) {
          if (s.hasError) {
            return const Center(child: Text('تعذر تحميل الدفعات.'));
          }
          if (!s.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = s.data!.docs;
          if (docs.isEmpty)
            return const Center(
              child: Text('لا توجد دفعات بعد؛ استورد ملفات PDF من الزر أدناه.'),
            );
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final batchId = docs[i].id;
              final d = docs[i].data();
              final categoryNames = (d['categoryLabels'] as List<dynamic>?)
                      ?.map((value) => value.toString())
                      .toList() ??
                  [
                    (d['categoryKey'] ?? 'فئات متعددة').toString(),
                  ];
              final count = (d['count'] as num?)?.toInt() ?? 0;
              final pageCount = (d['pageCount'] as num?)?.toInt() ?? 0;
              final importStatus = d['importStatus']?.toString() ?? 'ready';
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: Text(
                    importStatus == 'importing'
                        ? '${d['name'] ?? ''} — جارٍ الاستيراد'
                        : (d['name'] ?? '').toString(),
                  ),
                  subtitle: Text(
                    'الفئات: ${categoryNames.join('، ')} · $count كرت'
                    '${pageCount > 0 ? ' · $pageCount صفحة' : ''}'
                    '${d['fileCount'] != null ? ' · ${d['fileCount']} ملف' : ''}',
                  ),
                  trailing: importStatus == 'importing'
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_left),
                  onTap: importStatus == 'importing'
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BatchCardsPage(
                                batchId: batchId,
                                batchName: (d['name'] ?? '').toString(),
                              ),
                            ),
                          ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'manual-batch',
            tooltip: 'إنشاء دفعة يدويًا',
            onPressed: () => _newBatch(context, uid),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'pdf-import-batch',
            onPressed: () => _importPdf(context, uid),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('استيراد PDF'),
          ),
        ],
      ),
    );
  }
}
