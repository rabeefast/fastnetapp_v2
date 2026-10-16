import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/initial_dropdown_form_field.dart';
import '../../../models/category_config.dart';
import '../../../services/db_service.dart';
import '../../../services/pdf_card_import_service.dart';

class PdfBatchImportPage extends StatefulWidget {
  final String managerUid;
  final List<CategoryConfig> categories;

  const PdfBatchImportPage({
    super.key,
    required this.managerUid,
    required this.categories,
  });

  @override
  State<PdfBatchImportPage> createState() => _PdfBatchImportPageState();
}

class _PdfSelection {
  final ParsedPdfCards parsed;
  String? categoryKey;

  _PdfSelection(this.parsed, this.categoryKey);
}

class _PdfBatchImportPageState extends State<PdfBatchImportPage> {
  final _nameController = TextEditingController(
    text: 'دفعة ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
  );
  final _parser = PdfCardImportService();
  final List<_PdfSelection> _files = [];
  String? _error;
  bool _parsing = false;
  bool _saving = false;
  int _checkedCards = 0;
  int _completedCards = 0;
  int _totalCards = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfs() async {
    if (_parsing || _saving) return;
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
      withData: false,
    );
    if (selection == null || selection.files.isEmpty) return;

    setState(() {
      _files.clear();
      _error = null;
      _parsing = true;
    });
    try {
      final allBytes = selection.files.fold<int>(
        0,
        (sum, file) => sum + file.size,
      );
      if (allBytes > 60 * 1024 * 1024) {
        throw const FormatException(
          'إجمالي حجم الملفات يتجاوز 60 MB؛ اختر ملفات أقل في كل مرة.',
        );
      }
      final parsedFiles = <_PdfSelection>[];
      var cardCount = 0;
      for (final file in selection.files) {
        if (cardCount >= maxPdfImportCardsPerBatch) {
          throw const FormatException(
            'الحد الأقصى للاستيراد في دفعة واحدة هو 7000 كرت. '
            'قسّم الملفات إلى دفعتين أو أكثر.',
          );
        }
        var bytes = file.bytes;
        if (bytes == null) {
          final path = file.path;
          if (path == null) {
            throw FormatException('تعذر قراءة الملف ${file.name} من الجهاز.');
          }
          try {
            bytes = await File(path).readAsBytes();
          } catch (_) {
            throw FormatException('تعذر فتح الملف ${file.name} من الجهاز.');
          }
        }
        final parsed = await _parser.parse(
          bytes: bytes,
          fileName: file.name,
          maxCards: maxPdfImportCardsPerBatch - cardCount,
        );
        cardCount += parsed.cards.length;
        if (cardCount > maxPdfImportCardsPerBatch) {
          throw const FormatException(
            'تتجاوز الملفات 7000 كرت. قسّمها إلى دفعتين أو أكثر.',
          );
        }
        parsedFiles.add(
          _PdfSelection(parsed, _guessCategory(file.name)),
        );
      }

      if (parsedFiles.map((file) => file.parsed.fileName).toSet().length !=
          parsedFiles.length) {
        throw const FormatException(
          'اختر الملفات مرة واحدة فقط؛ يوجد اسمان متطابقان للملفات.',
        );
      }
      if (!mounted) return;
      setState(() {
        _files
          ..clear()
          ..addAll(parsedFiles);
        _totalCards = cardCount;
        _parsing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _files.clear();
        _totalCards = 0;
        _parsing = false;
        _error = error is FormatException
            ? error.message
            : 'تعذر قراءة الملفات. لم يتم حفظ أي بطاقة.';
      });
    }
  }

  String? _guessCategory(String fileName) {
    final normalizedName = fileName.toLowerCase();
    for (final category in widget.categories) {
      final profile = category.umProfile.trim().toLowerCase();
      if (profile.isNotEmpty && normalizedName.contains(profile)) {
        return category.key;
      }
    }
    for (final category in widget.categories) {
      final label = category.label.trim();
      if (label.isEmpty) continue;
      final boundary = RegExp(
        '(^|[^0-9])${RegExp.escape(label)}([^0-9]|\$)',
      );
      if (boundary.hasMatch(fileName)) return category.key;
    }
    return null;
  }

  Map<String, int> get _usernameCounts {
    final counts = <String, int>{};
    for (final file in _files) {
      for (final card in file.parsed.cards) {
        counts.update(card.username, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  int get _duplicateCount =>
      _usernameCounts.values.where((count) => count > 1).length;

  bool get _canImport =>
      !_parsing &&
      !_saving &&
      _files.isNotEmpty &&
      _nameController.text.trim().isNotEmpty &&
      _files.every((file) => file.categoryKey != null) &&
      _duplicateCount == 0 &&
      _totalCards <= maxPdfImportCardsPerBatch;

  Future<void> _import() async {
    if (!_canImport) return;
    setState(() {
      _saving = true;
      _checkedCards = 0;
      _completedCards = 0;
      _error = null;
    });
    try {
      final categoryByFile = {
        for (final file in _files) file.parsed.fileName: file.categoryKey!,
      };
      final categoryLabelByKey = {
        for (final category in widget.categories) category.key: category.label,
      };
      await DbService().createPdfBatch(
        managerUid: widget.managerUid,
        name: _nameController.text.trim(),
        files: _files.map((file) => file.parsed).toList(),
        categoryByFile: categoryByFile,
        categoryLabelByKey: categoryLabelByKey,
        onCheckProgress: (checked, total) {
          if (mounted) {
            setState(() {
              _checkedCards = checked;
              _totalCards = total;
            });
          }
        },
        onProgress: (completed, total) {
          if (mounted) {
            setState(() {
              _completedCards = completed;
              _totalCards = total;
            });
          }
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is StateError || error is ArgumentError
            ? error.toString().replaceFirst('Bad state: ', '')
            : error is FirebaseException
                ? 'Firestore: ${error.code}'
                    '${error.message == null ? '' : ' — ${error.message}'}'
                : 'تعذر حفظ الدفعة. استيراد PDF يحتاج اتصالًا فعّالًا بالإنترنت '
                    'وصلاحية الوصول إلى Firestore؛ '
                    'لن تُعرض أي دفعة غير مكتملة.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories
        .where((category) => category.key.trim().isNotEmpty)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('استيراد دفعة PDF')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'اختر ملفًا أو عدة ملفات PDF. يقرأ التطبيق اسم المستخدم والرقم '
                'التسلسلي ورقم الصفحة تلقائيًا، ثم يربط كل ملف بفئته. '
                'المطابقة مع User Manager تتم باسم المستخدم، لا بالرقم التسلسلي.',
                style: TextStyle(height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'اسم الدفعة'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _parsing || _saving ? null : _pickPdfs,
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(_files.isEmpty ? 'اختيار ملفات PDF' : 'تغيير الملفات'),
          ),
          if (_parsing) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('جارٍ قراءة الصفحات والتحقق من الأرقام...'),
          ],
          if (_files.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'الإجمالي: $_totalCards كرت · '
                  '${_files.fold<int>(0, (sum, file) => sum + file.parsed.pageCount)} صفحة · '
                  '${_files.length} ملف · '
                  '${_files.map((file) => file.categoryKey).whereType<String>().toSet().length} فئات',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            ..._files.map(
              (file) => _filePreview(file, categories),
            ),
            if (_duplicateCount > 0)
              const Card(
                color: Color(0xFFFFE5E5),
                child: ListTile(
                  leading: Icon(Icons.error_outline, color: Colors.red),
                  title: Text(
                    'توجد أسماء مستخدمين مكررة بين الملفات؛ أزل التكرار قبل الحفظ.',
                  ),
                ),
              ),
          ],
          if (_saving) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _totalCards == 0
                  ? null
                  : _completedCards > 0
                      ? (0.5 + 0.5 * _completedCards / _totalCards)
                          .clamp(0.0, 1.0)
                          .toDouble()
                      : (0.5 * _checkedCards / _totalCards)
                          .clamp(0.0, 0.5)
                          .toDouble(),
            ),
            const SizedBox(height: 8),
            Text(
              _completedCards == 0
                  ? _checkedCards == 0
                      ? 'جارٍ الاتصال بقاعدة البيانات وفحص الأسماء...'
                      : _checkedCards < _totalCards
                          ? 'تم فحص $_checkedCards من $_totalCards اسمًا...'
                          : 'تم فحص الأسماء؛ جارٍ حفظ الكروت...'
                  : 'تم حفظ $_completedCards من $_totalCards كرت',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _canImport ? _import : null,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(
              _saving ? 'جارٍ الحفظ...' : 'حفظ الدفعة ($_totalCards كرت)',
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _filePreview(
    _PdfSelection file,
    List<CategoryConfig> categories,
  ) {
    final uniqueCounts = file.parsed.cardsPerPage.toSet();
    final pageCardLabel = uniqueCounts.length == 1
        ? '${uniqueCounts.single} كرت/صفحة'
        : 'عدد الكروت يختلف بين الصفحات';
    final samples = file.parsed.cards.take(5).toList();
    return Card(
      key: ValueKey(file.parsed.fileName),
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    file.parsed.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            Text(
              '${file.parsed.pageCount} صفحة · '
              '${file.parsed.cards.length} كرت · $pageCardLabel',
            ),
            const SizedBox(height: 8),
            InitialDropdownFormField<String>(
              initialValue: file.categoryKey,
              decoration: const InputDecoration(
                labelText: 'فئة هذا الملف',
                hintText: 'اختر الفئة',
              ),
              items: categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category.key,
                      child: Text(category.label),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => file.categoryKey = value),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 38,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 44,
                columns: const [
                  DataColumn(label: Text('الفئة')),
                  DataColumn(label: Text('التسلسل')),
                  DataColumn(label: Text('اسم المستخدم')),
                  DataColumn(label: Text('الصفحة')),
                ],
                rows: samples
                    .map(
                      (card) => DataRow(
                        cells: [
                          DataCell(Text(_categoryLabel(file.categoryKey))),
                          DataCell(Text('${card.serial}')),
                          DataCell(Text(card.username)),
                          DataCell(Text('${card.pageNumber}')),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
            if (file.parsed.cards.length > samples.length)
              Text(
                'معاينة ${samples.length} من ${file.parsed.cards.length} كرت',
              ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(String? key) {
    if (key == null) return 'غير محددة';
    for (final category in widget.categories) {
      if (category.key == key) return category.label;
    }
    return key;
  }
}
