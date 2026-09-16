import 'package:flutter/material.dart';

import '../../services/store_account_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';

/// The very first screen a device ever sees, before anything about a
/// specific pharmacy is loaded — registers a brand-new pharmacy account
/// or signs into an existing one. Everything past this point (products,
/// sales, employees...) belongs to exactly the pharmacy signed in here;
/// a second, unrelated pharmacy registering elsewhere gets its own
/// completely separate copy of all of it.
class StoreAuthScreen extends StatefulWidget {
  const StoreAuthScreen({super.key, required this.onAuthenticated});

  final VoidCallback onAuthenticated;

  @override
  State<StoreAuthScreen> createState() => _StoreAuthScreenState();
}

class _StoreAuthScreenState extends State<StoreAuthScreen> {
  bool _isRegistering = true;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  final _pharmacyName = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _pharmacyName.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    final code = _code.text;
    final pharmacyName = _pharmacyName.text.trim();

    if (phone.isEmpty || code.isEmpty || (_isRegistering && pharmacyName.isEmpty)) {
      setState(() => _error = 'عبّي كل الحقول');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final service = StoreAccountService.instance;
    final error = _isRegistering
        ? await service.register(pharmacyName: pharmacyName, phone: phone, code: code)
        : await service.signIn(phone: phone, code: code);

    if (!mounted) return;
    // Only ever move on once there's an actual session — signUp() alone
    // can succeed (return a user) while still leaving the account
    // unconfirmed and signed out, in which case staying here with a
    // clear message beats calling onAuthenticated() and bouncing right
    // back to this same screen with the button stuck on its spinner.
    if (error == null && service.isSignedIn) {
      widget.onAuthenticated();
      return;
    }
    setState(() {
      _busy = false;
      _error = error ?? 'تعذر تسجيل الدخول، حاول مرة أخرى';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppPaletteColors>();
    final primary = ext?.primary ?? theme.colorScheme.primary;
    final isDark = ext?.isDark ?? theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    primary.withValues(alpha: 0.06),
                    theme.scaffoldBackgroundColor,
                  ],
                ),
          color: isDark ? theme.scaffoldBackgroundColor : null,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.colorScheme.surface,
                    borderRadius: AppRadius.xlRadius,
                    boxShadow: AppShadows.raised(dark: isDark),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg + 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            borderRadius: AppRadius.lgRadius,
                          ),
                          child: Icon(Icons.store_rounded, size: 40, color: primary),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text('صيدليتي', style: theme.textTheme.headlineSmall),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _isRegistering
                              ? 'أنشئ حساب صيدليتك الجديد'
                              : 'سجّل الدخول لحساب صيدليتك',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (_isRegistering) ...[
                          TextField(
                            controller: _pharmacyName,
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              labelText: 'اسم الصيدلية',
                              prefixIcon: Icon(Icons.local_pharmacy_outlined),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        TextField(
                          controller: _phone,
                          textAlign: TextAlign.right,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'رقم الهاتف',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _code,
                          textAlign: TextAlign.right,
                          obscureText: _obscure,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'الرمز (6 أحرف/أرقام على الأقل)',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _error!,
                            style: TextStyle(color: theme.colorScheme.error),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(_isRegistering ? 'إنشاء الحساب' : 'تسجيل الدخول'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _isRegistering = !_isRegistering;
                                    _error = null;
                                  }),
                          child: Text(
                            _isRegistering
                                ? 'عندك حساب صيدلية مسبقاً؟ سجّل الدخول'
                                : 'صيدلية جديدة؟ أنشئ حساب',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
