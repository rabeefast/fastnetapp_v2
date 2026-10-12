import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/category_config.dart';
import '../../../models/settings_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/telegram_service.dart';
import '../../../state/app_state.dart';

/// إعدادات المدير: الفئات (العدد + الأسماء) والأسعار للمسارين،
/// حد تنبيه المخزون، وربط التليجرام.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<void> _loader;
  late SettingsModel _draft;
  final _tgToken = TextEditingController();
  final _tgChat = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loader = _load();
  }

  Future<void> _load() async {
    final uid = context.read<AuthService>().user!.uid;
    final app = context.read<AppState>();
    await app.load(uid);
    _draft = SettingsModel.fromMap(app.settings!.toMap());
    _tgToken.text = await TelegramService.token ?? '';
    _tgChat.text = await TelegramService.chatId ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final uid = context.read<AuthService>().user!.uid;
    context.read<AppState>().settings = SettingsModel.fromMap(_draft.toMap());
    await context.read<AppState>().save(uid);
    await TelegramService.saveCredentials(_tgToken.text.trim(), _tgChat.text.trim());
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الإعدادات')));
    }
  }

  void _setCount(int n) {
    if (n < 1 || n > 12) return;
    final cats = _draft.categories;
    while (cats.length < n) {
      cats.add(CategoryConfig(
          key: 'c${DateTime.now().millisecondsSinceEpoch}',
          label: '',
          umProfile: ''));
    }
    while (cats.length > n) {
      cats.removeLast();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loader,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildCategoriesSection(),
            const SizedBox(height: 16),
            _buildThresholdSection(),
            const SizedBox(height: 16),
            _buildTelegramSection(),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الإعدادات'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الفئات المتتبعة', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('عدد الفئات:'),
            const SizedBox(width: 12),
            SizedBox(
              width: 90,
              child: TextFormField(
                key: ValueKey(_draft.categories.length),
                initialValue: '${_draft.categories.length}',
                keyboardType: TextInputType.number,
                onChanged: (v) => _setCount(int.tryParse(v) ?? _draft.categories.length),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_draft.categories.length, (i) {
          return _CategoryEditor(
            cat: _draft.categories[i],
            onChanged: () => setState(() {}),
            onDelete: _draft.categories.length > 1
                ? () => setState(() => _draft.categories.removeAt(i))
                : null,
          );
        }),
      ],
    );
  }

  Widget _buildThresholdSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('حد تنبيه انخفاض المخزون', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('thr${_draft.lowStockThreshold}'),
          initialValue: '${_draft.lowStockThreshold}',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'كروت', helperText: 'يُرسل تنبيه تليجرام عند وصول مخزون أي مستلم لهذا الحد أو أقل'),
          onChanged: (v) => _draft.lowStockThreshold = int.tryParse(v) ?? 20,
        ),
      ],
    );
  }

  Widget _buildTelegramSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('إشعارات تليجرام', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _tgToken,
          obscureText: true,
          decoration: const InputDecoration(
              labelText: 'Bot Token',
              helperText: 'يُحفظ على أجهزة المدير فقط ولا يُرسل لأي سيرفر'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _tgChat,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Chat ID'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('إرسال رسالة اختبار'),
          onPressed: () async {
            await TelegramService.saveCredentials(
                _tgToken.text.trim(), _tgChat.text.trim());
            final ok = await TelegramService.sendTest();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'تم الإرسال — تحقق من تليجرام' : 'فشل الإرسال — تحقق من التوكن والـ Chat ID')));
            }
          },
        ),
      ],
    );
  }
}

class _CategoryEditor extends StatelessWidget {
  final CategoryConfig cat;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  const _CategoryEditor({required this.cat, required this.onChanged, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('l${cat.key}'),
                    initialValue: cat.label,
                    decoration: const InputDecoration(labelText: 'اسم الفئة (الظاهر)'),
                    onChanged: (v) { cat.label = v; },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('u${cat.key}'),
                    initialValue: cat.umProfile,
                    decoration: const InputDecoration(
                        labelText: 'اسمها في User Manager',
                        hintText: 'مثال: 100new'),
                    onChanged: (v) { cat.umProfile = v; },
                  ),
                ),
                if (onDelete != null)
                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _modeField('المدير ← الوكيل', cat.mgMode, (m) { cat.mgMode = m; onChanged(); })),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  key: ValueKey('mg${cat.key}'),
                  initialValue: '${cat.mgPrice}',
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: cat.mgMode == 'page' ? 'سعر الصفحة (ر.ي)' : 'سعر الكرت (ر.ي)'),
                  onChanged: (v) { cat.mgPrice = double.tryParse(v) ?? cat.mgPrice; },
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _modeField('الوكيل ← نقطة البيع', cat.agMode, (m) { cat.agMode = m; onChanged(); })),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  key: ValueKey('ag${cat.key}'),
                  initialValue: '${cat.agPrice}',
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: cat.agMode == 'page' ? 'سعر الصفحة (ر.ي)' : 'سعر الكرت (ر.ي)'),
                  onChanged: (v) { cat.agPrice = double.tryParse(v) ?? cat.agPrice; },
                ),
              ),
            ]),
            if (cat.mgMode == 'page' || cat.agMode == 'page')
              Row(children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('ps${cat.key}'),
                    initialValue: '${cat.pageSize}',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'كروت الصفحة'),
                    onChanged: (v) { cat.pageSize = int.tryParse(v) ?? cat.pageSize; },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('fp${cat.key}'),
                    initialValue: '${cat.freePerPage}',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'مجاني بعد كل صفحة'),
                    onChanged: (v) { cat.freePerPage = int.tryParse(v) ?? cat.freePerPage; },
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _modeField(String title, String mode, ValueChanged<String> onMode) {
    return InputDecorator(
      decoration: InputDecoration(labelText: title),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: mode,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'page', child: Text('بالصفحات')),
            DropdownMenuItem(value: 'card', child: Text('تجزئة بالكرت')),
          ],
          onChanged: (v) { if (v != null) onMode(v); },
        ),
      ),
    );
  }
}
