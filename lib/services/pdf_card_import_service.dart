import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

/// One extracted card. The username remains a string because it is the exact
/// User Manager key and may contain leading zeroes.
class PdfCardRecord {
  final String username;
  final int serial;
  final int pageNumber;
  final String fileName;

  const PdfCardRecord({
    required this.username,
    required this.serial,
    required this.pageNumber,
    required this.fileName,
  });
}

class ParsedPdfCards {
  final String fileName;
  final int pageCount;
  final List<PdfCardRecord> cards;
  final List<int> cardsPerPage;

  const ParsedPdfCards({
    required this.fileName,
    required this.pageCount,
    required this.cards,
    required this.cardsPerPage,
  });
}

class _NumberToken {
  final String value;
  final double x;
  final double yFromTop;

  const _NumberToken(this.value, this.x, this.yFromTop);
}

class _Row {
  final List<_NumberToken> tokens = [];
  double get centerY =>
      tokens.fold<double>(0, (sum, token) => sum + token.yFromTop) /
      tokens.length;
}

/// Extracts printable username/serial pairs from text-based voucher PDFs.
///
/// The importer deliberately rejects image-only or ambiguous pages rather
/// than guessing and silently assigning a serial to the wrong username.
class PdfCardImportService {
  static const int maxFileBytes = 20 * 1024 * 1024;

  const PdfCardImportService();

  Future<ParsedPdfCards> parse({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.length < 5 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != '%PDF') {
      throw const FormatException('الملف المحدد ليس ملف PDF صالحًا.');
    }
    if (bytes.length > maxFileBytes) {
      throw const FormatException('حجم ملف PDF يتجاوز الحد المسموح (20 MB).');
    }

    PdfDocument? document;
    try {
      document = await PdfDocument.openData(
        bytes,
        sourceName: fileName,
      );
      if (document.pages.isEmpty) {
        throw const FormatException('ملف PDF لا يحتوي على صفحات.');
      }

      final records = <PdfCardRecord>[];
      final counts = <int>[];
      final seenUsernames = <String>{};
      for (final page in document.pages) {
        final pageText = await page.loadText();
        final pageRecords = parsePageText(
          pageText,
          pageHeight: page.height,
          fileName: fileName,
        );
        if (pageRecords.isEmpty) {
          throw FormatException(
            'لم يتم العثور على بطاقات قابلة للقراءة في الصفحة ${page.pageNumber}. '
            'إذا كان الملف ممسوحًا ضوئيًا كصورة، فلن يمكن استخراجه تلقائيًا.',
          );
        }
        for (final record in pageRecords) {
          if (!seenUsernames.add(record.username)) {
            throw FormatException(
              'اسم مستخدم مكرر داخل ملف PDF في الصفحة ${record.pageNumber}. '
              'لم يتم قبول الملف لتجنب استبدال كرت آخر.',
            );
          }
        }
        records.addAll(pageRecords);
        counts.add(pageRecords.length);
      }

      return ParsedPdfCards(
        fileName: fileName,
        pageCount: document.pages.length,
        cards: List.unmodifiable(records),
        cardsPerPage: List.unmodifiable(counts),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'تعذر قراءة ملف PDF. تأكد أنه غير محمي بكلمة مرور ويحتوي نصًا قابلًا للنسخ.',
      );
    } finally {
      await document?.dispose();
    }
  }

  /// Public to make the geometric pairing logic testable without a native PDF.
  List<PdfCardRecord> parsePageText(
    PdfPageText pageText, {
    required double pageHeight,
    required String fileName,
  }) {
    final tokens = <_NumberToken>[];
    for (final fragment in pageText.fragments) {
      final text = _normalizeDigits(fragment.text);
      for (final match in RegExp(r'\d+').allMatches(text)) {
        final value = match.group(0)!;
        final length = value.length;
        if (length < 1 || length > 14) continue;

        final charRects = fragment.charRects;
        final tokenRects =
            match.end <= charRects.length && match.start < match.end
                ? charRects
                    .sublist(match.start, match.end)
                    .where((rect) => rect.isNotEmpty)
                    .toList()
                : <PdfRect>[];
        final rect = tokenRects.isEmpty ? fragment.bounds : _union(tokenRects);
        if (rect.isEmpty) continue;
        final centerY = (rect.top + rect.bottom) / 2;
        tokens.add(
          _NumberToken(
            value,
            (rect.left + rect.right) / 2,
            pageHeight - centerY,
          ),
        );
      }
    }

    if (tokens.isEmpty) {
      throw FormatException(
        'لا يوجد نص رقمي يمكن قراءته في الصفحة ${pageText.pageNumber}.',
      );
    }

    tokens.sort((a, b) => a.yFromTop.compareTo(b.yFromTop));
    final rows = <_Row>[];
    final rowTolerance = pageHeight * 0.025;
    for (final token in tokens) {
      if (rows.isEmpty ||
          (token.yFromTop - rows.last.centerY).abs() > rowTolerance) {
        rows.add(_Row()..tokens.add(token));
      } else {
        rows.last.tokens.add(token);
      }
    }

    final result = <PdfCardRecord>[];
    for (final row in rows) {
      final usernames = row.tokens
          .where((token) => token.value.length >= 8 && token.value.length <= 14)
          .toList()
        ..sort((a, b) => a.x.compareTo(b.x));
      final serials = row.tokens
          .where((token) => token.value.length >= 1 && token.value.length <= 7)
          .toList()
        ..sort((a, b) => a.x.compareTo(b.x));

      if (usernames.isEmpty && serials.isEmpty) continue;
      if (usernames.isEmpty || usernames.length != serials.length) {
        throw FormatException(
          'تعذر مطابقة الأسماء مع الأرقام التسلسلية في الصفحة ${pageText.pageNumber}. '
          'راجع الملف قبل استيراده.',
        );
      }

      for (var i = 0; i < usernames.length; i++) {
        final serial = int.tryParse(serials[i].value);
        if (serial == null || serial < 1) {
          throw FormatException(
            'رقم تسلسلي غير صالح في الصفحة ${pageText.pageNumber}.',
          );
        }
        result.add(
          PdfCardRecord(
            username: usernames[i].value,
            serial: serial,
            pageNumber: pageText.pageNumber,
            fileName: fileName,
          ),
        );
      }
    }

    return List.unmodifiable(result);
  }

  static PdfRect _union(List<PdfRect> rects) {
    var left = rects.first.left;
    var top = rects.first.top;
    var right = rects.first.right;
    var bottom = rects.first.bottom;
    for (final rect in rects.skip(1)) {
      if (rect.left < left) left = rect.left;
      if (rect.top > top) top = rect.top;
      if (rect.right > right) right = rect.right;
      if (rect.bottom < bottom) bottom = rect.bottom;
    }
    return PdfRect(left, top, right, bottom);
  }

  static String _normalizeDigits(String text) => String.fromCharCodes(
        text.runes.map((rune) {
          if (rune >= 0x0660 && rune <= 0x0669) return rune - 0x0660 + 0x30;
          if (rune >= 0x06F0 && rune <= 0x06F9) return rune - 0x06F0 + 0x30;
          return rune;
        }),
      );
}
