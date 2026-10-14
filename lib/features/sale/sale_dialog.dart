import 'package:flutter/material.dart';

import '../../core/serial_parser.dart';
import '../../services/db_service.dart';

Future<int?> showSaleDialog(BuildContext context, String uid) {
  return showDialog<int>(
    context: context,
    builder: (_) => _SaleDialog(uid: uid),
  );
}

class _SaleDialog extends StatefulWidget {
  final String uid;
  const _SaleDialog({required this.uid});

  @override
  State<_SaleDialog> createState() => _SaleDialogState();
}

class _SaleDialogState extends State<_SaleDialog> {
  final _input = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    late final List<int> serials;
    try {
      serials = parseSerials(_input.text);
      if (serials.isEmpty) {
        throw const FormatException('أدخل رقمًا تسلسليًا واحدًا على الأقل.');
      }
    } on FormatException catch (e) {
      setState(() => _error = e.message.toString());
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final count = await DbService().markSold(widget.uid, serials);
      if (mounted) Navigator.of(context).pop(count);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is StateError
            ? e.message.toString()
            : 'تعذر تسجيل البيع. تحقق من الاتصال والمخزون.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تسجيل بيع كروت'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _input,
            keyboardType: TextInputType.number,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'الأرقام التسلسلية',
              helperText: 'افصل بينها بفاصلة أو مسافة؛ مثال: 238542-238550',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'جارٍ الحفظ...' : 'تأكيد البيع'),
        ),
      ],
    );
  }
}
