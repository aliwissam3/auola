import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/subscription_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../pos/barcode_scanner_screen.dart';

/// Blocks the entire app - shown instead of the login screen - the
/// moment the subscription expires. Nothing past this screen (not even
/// the normal name/code login) is reachable until a valid renewal code
/// is entered or scanned.
class SubscriptionLockScreen extends StatefulWidget {
  const SubscriptionLockScreen({super.key});

  @override
  State<SubscriptionLockScreen> createState() => _SubscriptionLockScreenState();
}

class _SubscriptionLockScreenState extends State<SubscriptionLockScreen> {
  final _code = TextEditingController();
  String? _error;

  Future<void> _submit() async {
    final sub = context.read<SubscriptionService>();
    final ok = await sub.applyRenewalCode(_code.text);
    if (!mounted) return;
    if (ok) {
      setState(() => _error = null);
    } else {
      setState(() => _error = 'كود التجديد غير صحيح');
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;
    _code.text = code;
    await _submit();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppPaletteColors>();
    final primary = ext?.primary ?? theme.colorScheme.primary;
    final isMobile = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                borderRadius: AppRadius.xlRadius,
                boxShadow: AppShadows.raised(),
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
                        color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                        borderRadius: AppRadius.lgRadius,
                      ),
                      child: const Icon(Icons.lock_clock_rounded, size: 40, color: Color(0xFFDC2626)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('انتهى الاشتراك', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'انتهت مدة اشتراك هذا التطبيق. أدخل أو امسح كود التجديد للمتابعة.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _code,
                      decoration: InputDecoration(
                        labelText: 'كود التجديد',
                        prefixIcon: const Icon(Icons.qr_code_2_rounded),
                        suffixIcon: isMobile
                            ? IconButton(
                                icon: const Icon(Icons.camera_alt_outlined),
                                onPressed: _scan,
                              )
                            : null,
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        ),
                        child: const Text('تجديد الاشتراك'),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'للحصول على كود التجديد تواصل مع مزوّد التطبيق.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
