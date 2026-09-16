import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../services/auth_service.dart';
import '../../services/local_web_server_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../utils/web_deep_link.dart';
import '../../widgets/network_login_qr_dialog.dart';

/// One unified login form for everyone - admin and staff alike. Just a
/// name and a code; the matched employee's own admin flag/permissions
/// decide what they can see once inside, so there is nothing to choose
/// up front. A barcode (typed, scanned with a USB/Bluetooth reader, or
/// read from a phone camera) logs in on its own, without the name.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _barcode = TextEditingController();
  String? _error;
  bool _autoLoggingIn = false;

  @override
  void initState() {
    super.initState();
    // Scanning a printed employee QR with an ordinary phone camera opens
    // this app with ?emp=...&code=... in the URL - log straight in with
    // that code rather than making the person retype it.
    final info = initialLoginInfoFromUrl();
    if (info != null) {
      final (_, code) = info;
      _barcode.text = code;
      _autoLoggingIn = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _submitBarcode(auto: true));
    }
  }

  Future<void> _submitNameAndCode() async {
    final auth = context.read<AuthService>();
    final ok = await auth.loginWithNameAndCode(_name.text, _code.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      setState(() => _error = 'الاسم أو الرمز غير صحيح');
    }
  }

  Future<void> _submitBarcode({bool auto = false}) async {
    // A physical scanner reading a QR that encodes a full login link
    // (rather than a plain code) would otherwise type the whole URL into
    // this field - pull the real code back out of it if so.
    var value = _barcode.text.trim();
    if (value.startsWith('http')) {
      value = Uri.tryParse(value)?.queryParameters['code'] ?? value;
    }
    if (value.isEmpty) return;

    final auth = context.read<AuthService>();
    final ok = await auth.loginWithBarcode(value);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      setState(() {
        _error = 'الباركود غير صحيح';
        _autoLoggingIn = false;
      });
      _barcode.clear();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _barcode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppPaletteColors>();
    final primary = ext?.primary ?? theme.colorScheme.primary;
    final isDark = ext?.isDark ?? theme.brightness == Brightness.dark;
    context.watch<AppData>();

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
                          child: Icon(
                            Icons.local_pharmacy_rounded,
                            size: 40,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'صيدليتي',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'نظام إدارة الصيدليات المتكامل',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (_autoLoggingIn) ...[
                          const Padding(
                            padding:
                                EdgeInsets.symmetric(vertical: AppSpacing.md),
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: AppSpacing.md),
                                Text('جارِ تسجيل الدخول...'),
                              ],
                            ),
                          ),
                        ] else ...[
                          TextField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'الاسم',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm + 4),
                          TextField(
                            controller: _code,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'الرمز',
                              prefixIcon: Icon(Icons.password_outlined),
                            ),
                            onSubmitted: (_) => _submitNameAndCode(),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submitNameAndCode,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.md),
                              ),
                              child: const Text('دخول'),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm),
                              child: Text('أو', style: theme.textTheme.bodySmall),
                            ),
                            const Expanded(child: Divider()),
                          ]),
                          const SizedBox(height: AppSpacing.sm + 4),
                          TextField(
                            controller: _barcode,
                            decoration: const InputDecoration(
                              labelText: 'باركود الدخول',
                              hintText: 'امسح أو أدخل الكود',
                              prefixIcon: Icon(Icons.qr_code_2_rounded),
                            ),
                            onSubmitted: (_) => _submitBarcode(),
                          ),
                          if (kIsWeb ||
                              LocalWebServerService.instance.isRunning) ...[
                            const SizedBox(height: AppSpacing.sm + 4),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: () =>
                                    showNetworkLoginQrDialog(context),
                                icon: const Icon(Icons.qr_code_scanner_rounded),
                                label: const Text('مسح بكاميرا الهاتف'),
                              ),
                            ),
                          ],
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm + 4,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: AppRadius.mdRadius,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Color(0xFFB91C1C), size: 18),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Color(0xFFB91C1C),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
