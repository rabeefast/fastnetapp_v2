import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import '../lib/services/pdf_card_import_service.dart';

void main() {
  const service = PdfCardImportService();

  _CardTextFragment token(String value, double x, double top) {
    final characterRects = [
      for (var i = 0; i < value.length; i++)
        PdfRect(x + i * 5, top, x + (i + 1) * 5, top - 10),
    ];
    return _CardTextFragment(
      text: value,
      bounds: PdfRect(x, top, x + value.length * 5, top - 10),
      charRects: characterRects,
    );
  }

  group('PDF card pairing', () {
    test('pairs usernames and serials left-to-right on each page row', () {
      final fragments = <_CardTextFragment>[
        token('12345678', 10, 810),
        token('23456789', 200, 810),
        token('34567890', 400, 810),
        token('601001', 100, 806),
        token('601002', 300, 806),
        token('601003', 500, 806),
        token('45678901', 10, 750),
        token('56789012', 200, 750),
        token('67890123', 400, 750),
        token('601004', 100, 746),
        token('601005', 300, 746),
        token('601006', 500, 746),
      ];
      final pageText = _pageText(
        pageNumber: 3,
        fragments: fragments,
      );

      final cards = service.parsePageText(
        pageText,
        pageHeight: 842,
        fileName: 'cards.pdf',
      );

      expect(cards, hasLength(6));
      expect(cards.map((card) => card.username).toList(), [
        '12345678',
        '23456789',
        '34567890',
        '45678901',
        '56789012',
        '67890123',
      ]);
      expect(cards.map((card) => card.serial).toList(), [
        601001,
        601002,
        601003,
        601004,
        601005,
        601006,
      ]);
      expect(cards.every((card) => card.pageNumber == 3), isTrue);
    });

    test('normalizes Arabic-Indic digits without losing leading zeroes', () {
      final pageText = _pageText(
        pageNumber: 1,
        fragments: [
          token('٠١٢٣٤٥٦٧', 10, 810),
          token('٦٠١٠٠١', 100, 806),
        ],
      );

      final cards = service.parsePageText(
        pageText,
        pageHeight: 842,
        fileName: 'arabic-digits.pdf',
      );

      expect(cards.single.username, '01234567');
      expect(cards.single.serial, 601001);
    });

    test('rejects rows where a username cannot be matched to a serial', () {
      final pageText = _pageText(
        pageNumber: 2,
        fragments: [
          token('12345678', 10, 810),
          token('601001', 100, 806),
          token('601002', 200, 806),
        ],
      );

      expect(
        () => service.parsePageText(
          pageText,
          pageHeight: 842,
          fileName: 'ambiguous.pdf',
        ),
        throwsFormatException,
      );
    });
  });

  final samplePaths = (Platform.environment['FASTNET_PDF_SAMPLES'] ?? '')
      .split(',')
      .where((path) => path.trim().isNotEmpty)
      .toList();
  for (final samplePath in samplePaths) {
    final fileName = samplePath.split(Platform.pathSeparator).last;
    test('extracts 51 cards per page from $fileName', () async {
      final bytes = await File(samplePath).readAsBytes();
      final parsed = await PdfCardImportService().parse(
        bytes: bytes,
        fileName: fileName,
      );
      expect(parsed.cardsPerPage, everyElement(51));
      expect(parsed.cards, hasLength(parsed.pageCount * 51));
    });
  }
}

class _CardTextFragment {
  final String text;
  final PdfRect bounds;
  final List<PdfRect> charRects;

  const _CardTextFragment({
    required this.text,
    required this.bounds,
    required this.charRects,
  });
}

PdfPageText _pageText({
  required int pageNumber,
  required List<_CardTextFragment> fragments,
}) {
  final fullText = fragments.map((fragment) => fragment.text).join(' ');
  final fullTextRects = <PdfRect>[];
  for (var i = 0; i < fragments.length; i++) {
    fullTextRects.addAll(fragments[i].charRects);
    if (i + 1 < fragments.length) fullTextRects.add(PdfRect.empty);
  }

  final owner = PdfPageText(
    pageNumber: pageNumber,
    fullText: fullText,
    charRects: fullTextRects,
    fragments: const [],
  );
  var index = 0;
  final pdfFragments = fragments.map((fragment) {
    final result = PdfPageTextFragment(
      pageText: owner,
      index: index,
      length: fragment.text.length,
      bounds: fragment.bounds,
      charRects: fragment.charRects,
      direction: PdfTextDirection.ltr,
    );
    index += fragment.text.length + 1;
    return result;
  }).toList();

  return PdfPageText(
    pageNumber: pageNumber,
    fullText: fullText,
    charRects: fullTextRects,
    fragments: pdfFragments,
  );
}
