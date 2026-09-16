import 'package:flutter/material.dart';

/// Design tokens for the "UI/UX Pro Max" system: an 8-point spacing
/// grid, a consistent radius scale, layered soft shadows, and the
/// semantic status colors used for stock/expiry/payment badges across
/// the whole app. Centralizing these here means every screen that
/// imports this file automatically matches the same visual rhythm
/// instead of hand-picking magic numbers.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  const AppRadius._();

  static const double sm = 12;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 18;

  static BorderRadius get smRadius => BorderRadius.circular(sm);
  static BorderRadius get mdRadius => BorderRadius.circular(md);
  static BorderRadius get lgRadius => BorderRadius.circular(lg);
  static BorderRadius get xlRadius => BorderRadius.circular(xl);
}

/// Soft, multi-layered shadows (a tight low-opacity layer for definition
/// + a wide diffuse layer for depth) rather than a single harsh drop
/// shadow — the signature "floating card" look of modern dashboards.
class AppShadows {
  const AppShadows._();

  static List<BoxShadow> card({bool dark = false}) => [
        BoxShadow(
          color: (dark ? Colors.black : const Color(0xFF0F172A))
              .withValues(alpha: dark ? 0.28 : 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: (dark ? Colors.black : const Color(0xFF0F172A))
              .withValues(alpha: dark ? 0.22 : 0.06),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> raised({bool dark = false}) => [
        BoxShadow(
          color: (dark ? Colors.black : const Color(0xFF0F172A))
              .withValues(alpha: dark ? 0.32 : 0.07),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: (dark ? Colors.black : const Color(0xFF0F172A))
              .withValues(alpha: dark ? 0.24 : 0.09),
          blurRadius: 32,
          offset: const Offset(0, 16),
        ),
      ];

  static List<BoxShadow> subtle({bool dark = false}) => [
        BoxShadow(
          color: (dark ? Colors.black : const Color(0xFF0F172A))
              .withValues(alpha: dark ? 0.2 : 0.05),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];
}

/// Semantic tones for status pills/badges (stock levels, expiry alerts,
/// payment states). Each has a soft tint background + a strong
/// foreground so the badge stays legible without shouting.
enum AppStatusTone { success, warning, danger, info, neutral }

class AppStatusColors {
  const AppStatusColors._();

  static const _tones = <AppStatusTone, (Color fg, Color bg)>{
    AppStatusTone.success: (Color(0xFF15803D), Color(0xFFDCFCE7)),
    AppStatusTone.warning: (Color(0xFFB45309), Color(0xFFFEF3C7)),
    AppStatusTone.danger: (Color(0xFFB91C1C), Color(0xFFFEE2E2)),
    AppStatusTone.info: (Color(0xFF1D4ED8), Color(0xFFDBEAFE)),
    AppStatusTone.neutral: (Color(0xFF475569), Color(0xFFF1F5F9)),
  };

  static Color foreground(AppStatusTone tone) => _tones[tone]!.$1;
  static Color background(AppStatusTone tone) => _tones[tone]!.$2;
}
