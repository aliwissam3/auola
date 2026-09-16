import 'package:flutter/material.dart';
import 'app_palette.dart';
import 'app_tokens.dart';

/// Builds a full [ThemeData] from an [AppPalette] following the
/// "UI/UX Pro Max" system: an 8-point spacing grid (applied at the
/// widget level via [AppSpacing]), a 12–18px radius scale, soft
/// layered shadows instead of harsh outlines, and a clean Arabic-first
/// typographic scale (Cairo) with clear weight distinctions between
/// headers, labels, numbers and status tags.
class AppTheme {
  static ThemeData build(AppPalette p) {
    final base = p.isDark ? ThemeData.dark() : ThemeData.light();

    final scheme = p.isDark
        ? ColorScheme.dark(
            primary: p.primary,
            secondary: p.accent,
            surface: _lighten(p.dark, 0.08),
            onSurface: p.light,
            onPrimary: Colors.white,
            error: const Color(0xFFDC2626),
          )
        : ColorScheme.light(
            primary: p.primary,
            secondary: p.accent,
            surface: Colors.white,
            onSurface: const Color(0xFF0F172A),
            error: const Color(0xFFDC2626),
            onPrimary: Colors.white,
          );

    final scaffoldBg = p.isDark ? p.dark : p.light;
    final cardBg = p.isDark ? _lighten(p.dark, 0.08) : Colors.white;
    final textColor = p.isDark ? p.light : const Color(0xFF0F172A);
    final mutedText =
        p.isDark ? p.light.withValues(alpha: 0.64) : const Color(0xFF64748B);

    // Cairo is a modern, highly-legible Arabic typeface with a full
    // Latin set too, so numbers/prices/dates read cleanly alongside it.
    final baseTextTheme = base.textTheme.apply(fontFamily: 'Cairo');

    return base.copyWith(
      brightness: p.isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      primaryColor: p.primary,
      splashFactory: InkRipple.splashFactory,
      // Forces a visible fade+scale transition on every screen push, on
      // every platform (Windows/desktop otherwise gets no animation by
      // default in some Flutter configurations) — so tapping any
      // dashboard tile always opens its screen with a smooth animation.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
      textTheme: baseTextTheme
          .apply(bodyColor: textColor, displayColor: textColor)
          .copyWith(
            // Clear hierarchy: bold, tight headlines for page/section
            // titles; a distinct semi-bold "label" weight for field
            // captions and table headers; a slightly looser body for
            // long-form text.
            headlineSmall: TextStyle(fontFamily: 'Cairo', 
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.2,
            ),
            titleLarge: TextStyle(fontFamily: 'Cairo', 
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            titleMedium: TextStyle(fontFamily: 'Cairo', 
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            bodyMedium: TextStyle(fontFamily: 'Cairo', 
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textColor,
              height: 1.45,
            ),
            bodySmall: TextStyle(fontFamily: 'Cairo', 
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: mutedText,
              height: 1.4,
            ),
            labelLarge: TextStyle(fontFamily: 'Cairo', 
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.1,
            ),
          ),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Cairo'),
      appBarTheme: p.isDark
          ? AppBarTheme(
              backgroundColor: p.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(fontFamily: 'Cairo', 
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            )
          : AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: textColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              shadowColor: Colors.black.withValues(alpha: 0.06),
              iconTheme: IconThemeData(color: p.primary),
              titleTextStyle: TextStyle(fontFamily: 'Cairo', 
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlRadius,
        ),
        margin: EdgeInsets.zero,
      ),
      dividerColor: p.isDark
          ? p.accent.withValues(alpha: 0.35)
          : const Color(0xFFE2E8F0),
      dividerTheme: DividerThemeData(
        color: p.isDark
            ? p.accent.withValues(alpha: 0.35)
            : const Color(0xFFE2E8F0),
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.primary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdRadius,
          ),
          textStyle: TextStyle(fontFamily: 'Cairo', 
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(
            Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          textStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
          textStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.isDark ? p.light : p.primary,
          side: BorderSide(
            color: p.isDark ? p.accent : const Color(0xFFCBD5E1),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdRadius,
          ),
          textStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.isDark ? Colors.white : textColor,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            p.isDark ? _lighten(p.dark, 0.12) : const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: TextStyle(fontFamily: 'Cairo', color: mutedText, fontSize: 13.5),
        labelStyle: TextStyle(fontFamily: 'Cairo', color: mutedText, fontSize: 13.5),
        prefixIconColor: mutedText,
        suffixIconColor: mutedText,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: BorderSide(color: p.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.4),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: p.isDark
            ? p.accent.withValues(alpha: 0.18)
            : const Color(0xFFF1F5F9),
        labelStyle: TextStyle(fontFamily: 'Cairo', 
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.isDark ? p.accent : p.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        highlightElevation: 5,
        extendedTextStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: Color(0xFFDC2626),
        textColor: Colors.white,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.isDark ? Colors.white : p.primary,
        unselectedLabelColor: textColor.withValues(alpha: 0.45),
        labelStyle:
            TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13.5),
        unselectedLabelStyle:
            TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 13.5),
        indicatorColor: p.isDark ? p.accent : p.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        titleTextStyle: TextStyle(fontFamily: 'Cairo', 
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
        contentTextStyle: TextStyle(fontFamily: 'Cairo', 
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlRadius,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.isDark ? p.accent : const Color(0xFF0F172A),
        contentTextStyle: TextStyle(fontFamily: 'Cairo', 
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdRadius,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: mutedText,
        titleTextStyle: TextStyle(fontFamily: 'Cairo', 
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        subtitleTextStyle: TextStyle(fontFamily: 'Cairo', 
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: mutedText,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: TextStyle(fontFamily: 'Cairo', 
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: mutedText,
        ),
        dataTextStyle: TextStyle(fontFamily: 'Cairo', 
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
        dividerThickness: 1,
        headingRowColor: WidgetStateProperty.all(
          p.isDark ? _lighten(p.dark, 0.1) : const Color(0xFFF8FAFC),
        ),
      ),
      extensions: [AppPaletteColors.fromPalette(p)],
    );
  }

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final l = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }
}

/// Theme extension exposing the raw palette tones (accent / dark / light)
/// to widgets that need brand-specific colors beyond [ColorScheme].
class AppPaletteColors extends ThemeExtension<AppPaletteColors> {
  const AppPaletteColors({
    required this.primary,
    required this.dark,
    required this.accent,
    required this.light,
    required this.isDark,
  });

  final Color primary;
  final Color dark;
  final Color accent;
  final Color light;
  final bool isDark;

  factory AppPaletteColors.fromPalette(AppPalette p) => AppPaletteColors(
        primary: p.primary,
        dark: p.dark,
        accent: p.accent,
        light: p.light,
        isDark: p.isDark,
      );

  @override
  AppPaletteColors copyWith({
    Color? primary,
    Color? dark,
    Color? accent,
    Color? light,
    bool? isDark,
  }) {
    return AppPaletteColors(
      primary: primary ?? this.primary,
      dark: dark ?? this.dark,
      accent: accent ?? this.accent,
      light: light ?? this.light,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppPaletteColors lerp(ThemeExtension<AppPaletteColors>? other, double t) {
    if (other is! AppPaletteColors) return this;
    return AppPaletteColors(
      primary: Color.lerp(primary, other.primary, t)!,
      dark: Color.lerp(dark, other.dark, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      light: Color.lerp(light, other.light, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}
