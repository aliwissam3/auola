/// Whether a given dashboard card (identified by [id], a stable slug —
/// not the display title, so renaming a card's Arabic label later
/// doesn't lose the setting) is hidden. Only rows for HIDDEN cards need
/// to exist — a card with no row is visible by default.
class CardVisibility {
  CardVisibility({required this.id, required this.hidden});

  final String id;
  bool hidden;

  Map<String, dynamic> toJson() => {'id': id, 'hidden': hidden};

  factory CardVisibility.fromJson(Map<String, dynamic> j) => CardVisibility(
        id: j['id'] as String,
        hidden: j['hidden'] as bool? ?? true,
      );
}
