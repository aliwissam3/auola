import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small app-wide settings that don't belong to any single screen —
/// currently just the "نبّهني قبل الإكسباير بكم يوم" threshold used by
/// the Expiry screen, editable from Settings instead of per-product.
class SettingsService extends ChangeNotifier {
  static const _expiryDaysKey = 'expiry_alert_threshold_days';

  int _expiryAlertDays = 30;
  int get expiryAlertDays => _expiryAlertDays;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _expiryAlertDays = prefs.getInt(_expiryDaysKey) ?? 30;
    } catch (_) {
      // Storage unavailable: keep the default threshold for this session.
    }
    notifyListeners();
  }

  Future<void> setExpiryAlertDays(int days) async {
    _expiryAlertDays = days;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_expiryDaysKey, days);
    } catch (_) {
      // New threshold still applies for this session even if it can't persist.
    }
  }
}
