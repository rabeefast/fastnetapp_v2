import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/calculator.dart';
import '../../models/app_user.dart';
import '../../models/category_config.dart';
import '../../models/delivery.dart';
import '../../models/settings_model.dart';
import '../../services/db_service.dart';
import '../../services/telegram_service.dart';

/// معالج التسليم: دفعة ← مستلم ← فئة ← (صفحات | كروت متسلسلة قابلة للتعديل)
/// side: 'mg' (مدير->وكيل) أو 'ag' (وكيل->نقطة بيع)
class DeliveryWizard extends StatefulWidget {
  final String side;
  final String fromUid;
  final String managerUid;
  const DeliveryWizard({super.key, required this.side, required this.fromUid, required this.managerUid});

  @override
  State<DeliveryWizard> createState() => _DeliveryWizardState();
}

class _DeliveryInfo { final String id, name, categoryKey; final int inStock; _DeliveryInfo(this.id, this.name, this.categoryKey, this.inStock); }

class _DeliveryWizardState extends State<DeliveryWizard> {
  final _db = DbService();
  SettingsModel? _settings;
  List<AppUser> _recipients = [];
  final List<_DeliveryInfo> _batches = [];
  String? _batchId;
  String? _recipientUid;
  final List<_Item> _items = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    _settings = await _db.loadSettings(widget.managerUid);
    _recipients = await _db.childrenOf(widget.fromUid, widget.side == 'mg' ? 'agent' : 'pos');
    final bs = await FirebaseFirestore.instance
        .collection('batches').where('managerUid', isEqualTo: widget.managerUid).get();
    for (final d in bs.docs) {
      final cards = await _db.batchCards(d.id, d.data()['categoryKey'] ?? '');
      if (cards.isNotEmpty) {
        _batches.add(_DeliveryInfo(d.id, d.data()['name'] ?? '', d.data()['categoryKey'] ?? '', cards.length));
      }
    }
    if (mounted) setState(() {});
  }

  double _unit(CategoryConfig c) =>
      widget.side == 'mg' ? DeliveryCalculator.unitMg(c) : DeliveryCalculator.unitAg(c);
  double _pagePrice(CategoryConfig c) => widget.side == 'mg' ? c.mgPrice : c.agPrice;

  double _total() { double t = 0; for (final e in _items) { t += e.amount; } return t; }

  bool _canSave() => _batchId != null && _recipientUid != null && _items.isNotEmpty &&
      _items.every((e) => e.valid);

  Future<void> _save() async {
    final rec = _recipients.firstWhere((r) => r.uid == _recipientUid);
    final allIds = <String>[];
    final items = <DeliveryItem>[];
    for (final e in _items) {
      items.add(DeliveryItem(categoryKey: e.cat!.key, type: e.mode,
          pages: e.mode == 'pages' ? e.selectedPages.length : 0,
          cardSerials: e.mode == 'cards' ? e.chosenSerials : const [],
          amount: e.amount));
      allIds.addAll(e.cardIds);
    }
    final d = Delivery(
      id: FirebaseFirestore.instance.collection('deliveries').doc().id,
      fromUid: widget.fromUid, toUid: rec.uid, toName: rec.name,
      batchId: _batchId!, side: widget.side,
      items: items, totalAmount: _total(), createdAt: DateTime.now(),
    );
    await _db.addDelivery(d, allIds, rec.uid);
    TelegramService.send('تسليم جديد\nإلى: ' + rec.name +
        '\nالقيمة: ' + _total().toStringAsFixed(0) + ' ر.ي');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ التسليم وتوليد المديونية')));
      setState(() { _items.clear(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_settings == null) return const Center(child: CircularProgressIndicator());
    final cats = _settings!.categories;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          value: _batchId,
          decoration: const InputDecoration(labelText: 'الدفعة'),
          items: _batches.map((b) => DropdownMenuItem(
              value: b.id, child: Text(b.name + ' (' + b.categoryKey + ' - ' + b.inStock.toString() + ' كرت)'))).toList(),
          onChanged: (v) => setState(() { _batchId = v; _items.clear(); }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _recipientUid,
          decoration: InputDecoration(
              labelText: widget.side == 'mg' ? 'الوكيل المستلم' : 'نقطة البيع المستلمة'),
          items: _recipients.map((r) => DropdownMenuItem(value: r.uid, child: Text(r.name))).toList(),
          onChanged: (v) => setState(() => _recipientUid = v),
        ),
        const SizedBox(height: 12),
        ..._items.map((e) => _ItemEditor(
              key: ObjectKey(e),
              item: e,
              cats: cats,
              batchId: _batchId,
              unitPrice: _unit,
              pagePrice: _pagePrice,
              onChanged: () => setState(() {}),
              onRemove: _items.length > 1 ? () => setState(() => _items.remove(e)) : null,
            )),
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('إضافة فئة أخرى للتسليم'),
          onPressed: _batchId == null ? null : () => setState(() => _items.add(_Item())),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: const Text('إجمالي قيمة التسليم'),
            trailing: Text(_total().toStringAsFixed(0) + ' ر.ي',
                style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('حفظ التسليم وتوليد المديونية'),
          onPressed: _canSave() ? _save : null,
        ),
      ],
    );
  }
}

class _Item {
  CategoryConfig? cat;
  String mode = 'pages';
  List<Map<String, dynamic>> cards = [];
  List<int> selectedPages = [];
  List<int> chosenSerials = [];
  List<String> cardIds = [];
  double amount = 0;
  bool get valid {
    if (cat == null) return false;
    if (mode == 'pages') return selectedPages.isNotEmpty;
    if (chosenSerials.isEmpty) return false;
    final known = cards.map((c) => c['serial'] as int).toSet();
    return chosenSerials.every(known.contains);
  }
}

class _ItemEditor extends StatefulWidget {
  final _Item item;
  final List<CategoryConfig> cats;
  final String? batchId;
  final double Function(CategoryConfig) unitPrice;
  final double Function(CategoryConfig) pagePrice;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  const _ItemEditor({super.key, required this.item, required this.cats, required this.batchId,
      required this.unitPrice, required this.pagePrice, required this.onChanged, this.onRemove});

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  final _serialCtrl = TextEditingController();
  final _manual = <TextEditingController>[];
  bool _loaded = false;

  Future<void> _loadSerials() async {
    if (widget.batchId == null || widget.item.cat == null) return;
    widget.item.cards = await DbService().batchCards(widget.batchId!, widget.item.cat!.key);
    _loaded = true;
    if (mounted) setState(() {});
  }

  List<List<Map<String, dynamic>>> get _pages {
    final ps = widget.item.cat?.pageSize ?? 51;
    final out = <List<Map<String, dynamic>>>[];
    final s = widget.item.cards;
    for (var i = 0; i < s.length; i += ps) {
      out.add(s.sublist(i, (i + ps > s.length) ? s.length : i + ps));
    }
    return out;
  }

  String? _idOf(int serial) {
    for (final c in widget.item.cards) {
      if (c['serial'] == serial) return c['id'] as String;
    }
    return null;
  }

  void _recalc() {
    final it = widget.item;
    if (it.cat == null) return;
    if (it.mode == 'pages') {
      it.amount = it.selectedPages.length * widget.pagePrice(it.cat!);
      it.cardIds = [];
      for (final p in it.selectedPages) {
        it.cardIds.addAll(_pages[p].map((c) => c['id'] as String));
      }
    } else {
      it.amount = it.chosenSerials.length * widget.unitPrice(it.cat!);
      it.cardIds = it.chosenSerials.map((s) => _idOf(s)).whereType<String>().toList();
    }
    widget.onChanged();
  }

  Future<void> _autofill() async {
    final start = int.tryParse(_serialCtrl.text.trim());
    if (start == null || widget.item.cards.isEmpty) return;
    final next = widget.item.cards.where((c) => (c['serial'] as int) >= start).take(5).toList();
    setState(() {
      widget.item.chosenSerials = next.map((c) => c['serial'] as int).toList();
      _manual.clear();
      _manual.addAll(widget.item.chosenSerials.map((s) => TextEditingController(text: s.toString())));
      _recalc();
    });
  }

  void _addFive() {
    final last = widget.item.chosenSerials.last;
    final next = widget.item.cards.where((c) => (c['serial'] as int) > last).take(5).toList();
    if (next.isEmpty) return;
    setState(() {
      widget.item.chosenSerials.addAll(next.map((c) => c['serial'] as int));
      _manual.addAll(next.map((c) => TextEditingController(text: (c['serial'] as int).toString())));
      _recalc();
    });
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final known = it.cards.map((c) => c['serial'] as int).toSet();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<CategoryConfig>(
                  value: it.cat,
                  decoration: const InputDecoration(labelText: 'الفئة'),
                  items: widget.cats.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
                  onChanged: (v) {
                    setState(() { it.cat = v; it.selectedPages.clear(); it.chosenSerials.clear(); it.amount = 0; });
                    _loaded = false;
                    _loadSerials().then((_) => _recalc());
                  },
                ),
              ),
              IconButton(icon: const Icon(Icons.delete_outline), onPressed: widget.onRemove),
            ]),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pages', label: Text('بالصفحات')),
                ButtonSegment(value: 'cards', label: Text('بالكروت')),
              ],
              selected: {it.mode},
              onSelectionChanged: (s) => setState(() { it.mode = s.first; _recalc(); }),
            ),
            const SizedBox(height: 8),
            if (it.mode == 'pages') _pagesMode() else _cardsMode(known),
            if (it.cat != null)
              Text('القيمة: ' + it.amount.toStringAsFixed(0) + ' ر.ي',
                  style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  Widget _pagesMode() {
    if (!_loaded) return const Padding(padding: EdgeInsets.all(8), child: Text('جارٍ تحميل الصفحات...'));
    final pages = _pages;
    if (pages.isEmpty) return const Text('لا يوجد مخزون متاح لهذه الفئة في هذه الدفعة');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('الصفحات المتاحة (' + pages.length.toString() + '):'),
      ...List.generate(pages.length, (i) {
        final sel = widget.item.selectedPages.contains(i);
        return CheckboxListTile(
          dense: true,
          value: sel,
          title: Text('صفحة تبدأ من تسلسل ' + (pages[i].first['serial'] as int).toString() +
              ' (' + pages[i].length.toString() + ' كرت)'),
          onChanged: (_) => setState(() {
            if (sel) { widget.item.selectedPages.remove(i); } else { widget.item.selectedPages.add(i); }
            widget.item.selectedPages.sort();
            _recalc();
          }),
        );
      }),
      if (widget.item.selectedPages.isNotEmpty)
        Text('المختارة: ' + widget.item.selectedPages
            .map((i) => 'صفحة من ' + (pages[i].first['serial'] as int).toString()).join(' ، ')),
    ]);
  }

  Widget _cardsMode(Set<int> known) {
    return Column(children: [
      Row(children: [
        Expanded(
          child: TextField(
            controller: _serialCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'أدخل الرقم التسلسلي الأول'),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: _autofill, child: const Text('توليد +4')),
      ]),
      const SizedBox(height: 8),
      ...List.generate(_manual.length, (i) {
        final s = int.tryParse(_manual[i].text.trim()) ?? 0;
        final ok = known.contains(s);
        return TextField(
          controller: _manual[i],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'كرت ' + (i + 1).toString(),
            helperText: ok ? null : 'تسلسل غير موجود في الدفعة',
            helperStyle: const TextStyle(color: Colors.red),
          ),
          onChanged: (v) {
            final x = int.tryParse(v.trim());
            if (x != null) { widget.item.chosenSerials[i] = x; _recalc(); setState(() {}); }
          },
        );
      }),
      if (_manual.isNotEmpty)
        TextButton.icon(icon: const Icon(Icons.add), label: const Text('إضافة 5 كروت تالية'),
            onPressed: _addFive),
    ]);
  }
}
