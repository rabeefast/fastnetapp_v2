/// Parses individual serials and inclusive ranges; refuses malformed,
/// duplicate, non-positive, reversed, or oversized input.
List<int> parseSerials(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return [];

  final serials = <int>{};
  for (final part in trimmed.split(RegExp(r'[,\s]+'))) {
    if (!RegExp(r'^\d+(?:-\d+)?$').hasMatch(part)) {
      throw const FormatException('اكتب أرقامًا أو نطاقات مثل 120-125 فقط.');
    }

    if (part.contains('-')) {
      final bounds = part.split('-');
      final start = int.parse(bounds[0]);
      final end = int.parse(bounds[1]);
      if (start <= 0 || end < start) {
        throw const FormatException('النطاق غير صالح؛ تأكد من ترتيب أرقامه.');
      }
      final rangeLength = end - start + 1;
      if (rangeLength > 499 || serials.length + rangeLength > 499) {
        throw const FormatException('يمكن بيع 499 كرتًا كحد أقصى في العملية.');
      }
      for (var serial = start; serial <= end; serial++) {
        if (!serials.add(serial)) {
          throw const FormatException('لا تكرر رقم الكرت في الإدخال.');
        }
      }
    } else {
      final serial = int.parse(part);
      if (serial <= 0) {
        throw const FormatException('يجب أن تكون الأرقام التسلسلية موجبة.');
      }
      if (!serials.add(serial)) {
        throw const FormatException('لا تكرر رقم الكرت في الإدخال.');
      }
      if (serials.length > 499) {
        throw const FormatException('يمكن بيع 499 كرتًا كحد أقصى في العملية.');
      }
    }
  }
  return serials.toList(growable: false);
}
