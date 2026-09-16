import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_palette.dart';
import 'app_theme.dart';

/// Holds the currently selected color palette, persists the choice to
/// local storage, and exposes the resulting [ThemeData] to [MaterialApp].
class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'app_theme_palette';

  AppPalette _palette = AppPalette.pharmacyLight;
  AppPalette get palette => _palette;
  ThemeData get themeData => AppTheme.build(_palette);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null) {
        final match = AppPalette.all.where((p) => p.id.name == saved);
        if (match.isNotEmpty) {
          _palette = match.first;
        }
      }
    } catch (_) {
      // Storage unavailable: fall back to the default palette.
    }
    notifyListeners();
  }

  Future<void> setPalette(AppPaletteId id) async {
    _palette = AppPalette.byId(id);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, id.name);
    } catch (_) {
      // Selection still applies for this session even if it can't persist.
    }
  }
}
