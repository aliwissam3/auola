/// An app section (dashboard card id — see `dashboardCardCatalog`) an
/// admin picked from Settings as a quick-switch button shown right on
/// the sales/POS screen, so the person working the register doesn't
/// need to back out to the dashboard to jump to e.g. "الديون" or
/// "التقارير" mid-shift.
class SectionShortcut {
  SectionShortcut({required this.id});

  /// Same value as the dashboard card's id (e.g. 'debts', 'reports').
  final String id;

  Map<String, dynamic> toJson() => {'id': id};

  factory SectionShortcut.fromJson(Map<String, dynamic> j) =>
      SectionShortcut(id: j['id'] as String);
}
