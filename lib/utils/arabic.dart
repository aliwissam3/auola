/// Folds Arabic hamza variants (أ إ آ) to plain ا so search matches
/// regardless of whether the user typed the hamza — e.g. typing "اوجمنتين"
/// still finds a product stored as "أوجمنتين". Applied to both the query
/// and the haystack before comparing.
String normalizeArabic(String input) {
  return input.replaceAll(RegExp('[أإآ]'), 'ا');
}

/// Case/hamza-insensitive "does [haystack] contain [query]" check, with
/// an empty query always matching (so search fields default to showing
/// everything until the user types).
bool arabicContains(String haystack, String query) {
  if (query.trim().isEmpty) return true;
  return normalizeArabic(haystack).contains(normalizeArabic(query));
}
