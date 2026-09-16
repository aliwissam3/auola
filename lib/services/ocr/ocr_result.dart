/// One product line heuristically parsed from a purchase receipt photo.
class OcrLine {
  OcrLine({required this.name, this.quantity = 1, this.unitCost = 0});
  String name;
  int quantity;
  double unitCost;
}

/// Best-effort structured data pulled out of a receipt's raw OCR text:
/// a possible supplier name, per-product lines, and the printed total —
/// the purchases screen pre-fills its form with this and lets the
/// pharmacist review/correct it before saving.
class OcrPurchaseData {
  OcrPurchaseData({
    required this.rawText,
    this.supplierNameGuess,
    this.lines = const [],
    this.totalGuess,
  });

  final String rawText;
  final String? supplierNameGuess;
  final List<OcrLine> lines;
  final double? totalGuess;
}

/// Best-guess product name out of a photo of its box/label — the
/// printed brand name is usually the most prominent (largest) text, and
/// tends to land among the first few lines OCR returns in roughly
/// top-to-bottom order, so the longest of the first several lines is a
/// reasonable guess. Shared by every OCR engine implementation.
String? guessProductName(String rawText) {
  final lines = rawText
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.length >= 2)
      .toList();
  if (lines.isEmpty) return null;
  final candidates = lines.take(5).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return candidates.first;
}

/// Very simple heuristic parser shared by every OCR engine implementation:
/// - first non-numeric line → supplier name guess
/// - lines shaped like "اسم ... كمية سعر" → a product line
/// - the largest number found near a "مجموع/اجمالي/total" keyword → total
OcrPurchaseData parseReceiptText(String text) {
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  String? supplierGuess;
  double? totalGuess;
  final items = <OcrLine>[];

  final numberPattern = RegExp(r'(\d+[\.,]?\d*)');
  final totalKeywords = ['مجموع', 'اجمالي', 'إجمالي', 'total', 'المجموع'];

  for (final line in lines) {
    final lower = line.toLowerCase();

    if (totalKeywords.any((k) => lower.contains(k))) {
      final matches = numberPattern.allMatches(line).toList();
      if (matches.isNotEmpty) {
        totalGuess = double.tryParse(
          matches.last.group(0)!.replaceAll(',', ''),
        );
      }
      continue;
    }

    final numbers = numberPattern.allMatches(line).toList();
    if (numbers.isEmpty) {
      supplierGuess ??= line;
      continue;
    }

    // A plausible product line has a name plus at least one trailing number
    // (price), optionally a quantity before it.
    final namePart = line.substring(0, numbers.first.start).trim();
    if (namePart.length < 2) continue;

    double? price;
    int qty = 1;
    if (numbers.length >= 2) {
      qty = int.tryParse(numbers[numbers.length - 2].group(0)!.split('.').first) ?? 1;
      price = double.tryParse(numbers.last.group(0)!.replaceAll(',', ''));
    } else {
      price = double.tryParse(numbers.last.group(0)!.replaceAll(',', ''));
    }

    if (price != null && price > 0) {
      items.add(OcrLine(name: namePart, quantity: qty <= 0 ? 1 : qty, unitCost: price));
    }
  }

  return OcrPurchaseData(
    rawText: text,
    supplierNameGuess: supplierGuess,
    lines: items,
    totalGuess: totalGuess,
  );
}
