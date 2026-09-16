import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One Supabase Auth account = one pharmacy ("store"). Every row this app
/// writes to the cloud is tagged with this account's id ([storeId]), and a
/// matching Row Level Security policy on `store_records` restricts each
/// account to only ever read/write its own rows — so several unrelated
/// pharmacies can share the same app and the same database table without
/// ever seeing each other's data.
///
/// The person only ever types a phone number and a code — never an email
/// — since that's the identifier they already understand from the
/// employee-login screen. Supabase Auth itself only speaks email/phone
/// (phone needs an SMS provider this project doesn't have configured), so
/// the phone number is turned into a synthetic, never-emailed address
/// (`<digits>@storelogin.pharmacy`) behind the scenes purely so Supabase
/// has something to key the account on.
///
/// A singleton (like [ConnectivityStatus]) rather than something threaded
/// through the widget tree: [SupabaseRepository] needs [storeId] on every
/// query and isn't part of the provider tree itself.
class StoreAccountService extends ChangeNotifier {
  StoreAccountService._() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  static final instance = StoreAccountService._();

  SupabaseClient get _client => Supabase.instance.client;

  User? get _currentUser => _client.auth.currentUser;

  /// Null until a pharmacy has registered/signed in at least once. Every
  /// screen behind the store-auth gate in main.dart can assume this is
  /// non-null.
  String? get storeId => _currentUser?.id;

  /// True only once there's an actual active session — NOT merely once
  /// signUp() has been called. If this project ever has "confirm email"
  /// turned on, signUp() succeeds (returns a user) well before there's a
  /// session, and treating that as "signed in" would move on to loading
  /// pharmacy data that isn't accessible yet.
  bool get isSignedIn => _client.auth.currentSession != null;

  String? get pharmacyName => _currentUser?.userMetadata?['pharmacy_name'] as String?;

  String? get phone => _currentUser?.userMetadata?['phone'] as String?;

  String _digitsOnly(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');

  String _syntheticEmail(String phone) => '${_digitsOnly(phone)}@storelogin.pharmacy';

  /// Returns null on success, or a message (already Arabic where the
  /// cause is known) to show the person otherwise.
  Future<String?> register({
    required String pharmacyName,
    required String phone,
    required String code,
  }) async {
    final digits = _digitsOnly(phone);
    if (digits.length < 7) return 'رقم الهاتف غير صحيح';
    try {
      final res = await _client.auth.signUp(
        email: _syntheticEmail(digits),
        password: code,
        data: {'pharmacy_name': pharmacyName, 'phone': digits},
      );
      if (res.user == null) return 'تعذر إنشاء الحساب، حاول مرة أخرى';
      if (res.session == null) {
        // This project has "Confirm email" turned on — since the address
        // above was never real, no confirmation link can ever arrive.
        // Nothing to do but say so plainly rather than hang forever.
        return 'تعذر إنشاء الحساب: خيار "Confirm email" مفعّل بمشروع Supabase — لازم يتطفى قبل التسجيل';
      }
      return null;
    } on AuthException catch (e) {
      return _translateAuthError(e);
    } catch (_) {
      return 'تحتاج اتصال بالإنترنت لإنشاء حساب جديد أول مرة';
    }
  }

  Future<String?> signIn({required String phone, required String code}) async {
    final digits = _digitsOnly(phone);
    if (digits.length < 7) return 'رقم الهاتف غير صحيح';
    try {
      await _client.auth.signInWithPassword(email: _syntheticEmail(digits), password: code);
      return null;
    } on AuthException catch (e) {
      return _translateAuthError(e);
    } catch (_) {
      return 'تعذر الاتصال بالإنترنت';
    }
  }

  Future<void> signOut() => _client.auth.signOut();

  String _translateAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'هذا الرقم مسجل مسبقاً — جرب تسجيل الدخول بدل إنشاء حساب جديد';
    }
    if (msg.contains('invalid login credentials')) {
      return 'رقم الهاتف أو الرمز غير صحيح';
    }
    if (msg.contains('password') && msg.contains('least')) {
      return 'الرمز قصير جداً — لازم 6 أحرف/أرقام على الأقل';
    }
    return e.message;
  }
}
