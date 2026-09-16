import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One universal renewal code/barcode, the same for every installation
/// of this app - scanning or typing it in extends the subscription by a
/// year. Kept here as the single source of truth so the profile screen
/// and the lockout screen both check against exactly this value.
const String kSubscriptionRenewalCode = 'SY-RENEW-UNIVERSAL';
const int kSubscriptionTrialDays = 30;
const int kSubscriptionRenewDays = 365;

/// Per-machine license state: pharmacy/owner name plus the subscription
/// expiry date. Stored locally (SharedPreferences) rather than synced,
/// since a subscription is tied to one installed copy of the app, not
/// to the shared pharmacy data - each device's own copy of the app is
/// what needs to be licensed.
class SubscriptionService extends ChangeNotifier {
  static const _pharmacyNameKey = 'sub_pharmacy_name';
  static const _ownerNameKey = 'sub_owner_name';
  static const _expiryKey = 'sub_expiry_iso';

  String pharmacyName = '';
  String ownerName = '';
  DateTime? expiry;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      pharmacyName = prefs.getString(_pharmacyNameKey) ?? '';
      ownerName = prefs.getString(_ownerNameKey) ?? '';
      final iso = prefs.getString(_expiryKey);
      expiry = iso == null ? null : DateTime.tryParse(iso);
      // First run ever: start a trial instead of locking the app out
      // before anyone has even seen it.
      if (expiry == null) {
        expiry = DateTime.now().add(const Duration(days: kSubscriptionTrialDays));
        await prefs.setString(_expiryKey, expiry!.toIso8601String());
      }
    } catch (_) {
      // Storage unavailable - fall back to a fresh trial for this
      // session rather than locking the app out entirely.
      expiry ??= DateTime.now().add(const Duration(days: kSubscriptionTrialDays));
    }
    notifyListeners();
  }

  bool get isExpired => expiry != null && expiry!.isBefore(DateTime.now());

  int get daysRemaining =>
      expiry == null ? 0 : expiry!.difference(DateTime.now()).inDays;

  Future<void> saveProfile({required String pharmacyName, required String ownerName}) async {
    this.pharmacyName = pharmacyName;
    this.ownerName = ownerName;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pharmacyNameKey, pharmacyName);
      await prefs.setString(_ownerNameKey, ownerName);
    } catch (_) {
      // Still applied for this session even if it can't persist.
    }
  }

  /// Returns true if [code] matched and the subscription was extended.
  Future<bool> applyRenewalCode(String code) async {
    if (code.trim() != kSubscriptionRenewalCode) return false;
    final base = (expiry != null && expiry!.isAfter(DateTime.now())) ? expiry! : DateTime.now();
    expiry = base.add(const Duration(days: kSubscriptionRenewDays));
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_expiryKey, expiry!.toIso8601String());
    } catch (_) {
      // Extended for this session even if it can't persist.
    }
    return true;
  }
}
