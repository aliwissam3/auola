import 'package:flutter/material.dart';

/// The five brand color palettes the app supports. Persisted by name in
/// [ThemeProvider] so the user's choice survives restarts.
enum AppPaletteId {
  royalBurgundy,
  sapphireNavy,
  classicGold,
  emerald,
  pharmacyLight,
}

/// Static color definitions for one palette, matching the exact hex values
/// from the product spec. [isDark] palettes use light text on a dark base;
/// the single light palette ([AppPaletteId.pharmacyLight]) uses dark text on
/// an ivory base with white cards.
class AppPalette {
  const AppPalette({
    required this.id,
    required this.nameAr,
    required this.primary,
    required this.dark,
    required this.accent,
    required this.light,
    required this.isDark,
  });

  final AppPaletteId id;
  final String nameAr;

  /// Main brand color (buttons, app bar, selected states).
  final Color primary;

  /// Deep background color for dark palettes / secondary surface for light.
  final Color dark;

  /// Metallic / secondary accent (highlights, icons, borders).
  final Color accent;

  /// Softest tone: card backgrounds (dark palettes) or page background
  /// (light palette).
  final Color light;

  final bool isDark;

  static const royalBurgundy = AppPalette(
    id: AppPaletteId.royalBurgundy,
    nameAr: 'الملكي (عنابي)',
    primary: Color(0xFF6E1B2E),
    dark: Color(0xFF2E0D16),
    accent: Color(0xFFC08552),
    light: Color(0xFFEADCD9),
    isDark: true,
  );

  static const sapphireNavy = AppPalette(
    id: AppPaletteId.sapphireNavy,
    nameAr: 'الياقوتي (كحلي)',
    primary: Color(0xFF1B3A73),
    dark: Color(0xFF0A1631),
    accent: Color(0xFFB9BFCB),
    light: Color(0xFFD8E2F0),
    isDark: true,
  );

  static const classicGold = AppPalette(
    id: AppPaletteId.classicGold,
    nameAr: 'الكلاسيكي (ذهبي)',
    primary: Color(0xFFC6A227),
    dark: Color(0xFF141210),
    accent: Color(0xFF6F6A5E),
    light: Color(0xFFF0E6D2),
    isDark: true,
  );

  static const emerald = AppPalette(
    id: AppPaletteId.emerald,
    nameAr: 'الزمردي',
    primary: Color(0xFF0B6B4F),
    dark: Color(0xFF06231A),
    accent: Color(0xFFD3E4DA),
    light: Color(0xFFE2D3B3),
    isDark: true,
  );

  /// The default "Pro Max" theme: a crisp, trustworthy teal/blue on a
  /// soft neutral background — modeled on modern clinical/medical
  /// dashboards rather than a generic retail app.
  static const pharmacyLight = AppPalette(
    id: AppPaletteId.pharmacyLight,
    nameAr: 'المكتبي النهاري',
    primary: Color(0xFF0F766E),
    dark: Color(0xFFFFFFFF),
    accent: Color(0xFF2563EB),
    light: Color(0xFFF8FAFC),
    isDark: false,
  );

  static const List<AppPalette> all = [
    royalBurgundy,
    sapphireNavy,
    classicGold,
    emerald,
    pharmacyLight,
  ];

  static AppPalette byId(AppPaletteId id) =>
      all.firstWhere((p) => p.id == id, orElse: () => pharmacyLight);
}
