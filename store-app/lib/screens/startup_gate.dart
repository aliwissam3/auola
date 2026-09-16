import 'package:flutter/material.dart';

import '../config/supabase_config.dart';
import '../services/backend_service.dart';
import 'bootstrap_admin_screen.dart';
import 'login_screen.dart';

enum _StartupState { loading, notConfigured, error, readyForLogin, readyForBootstrap }

/// Runs before anything else: signs this device into the shared Supabase
/// session and checks whether the store has been set up yet (i.e. whether
/// any employee exists), then routes to the right first screen.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  _StartupState _state = _StartupState.loading;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!SupabaseConfig.isConfigured) {
      setState(() => _state = _StartupState.notConfigured);
      return;
    }
    setState(() => _state = _StartupState.loading);
    try {
      await BackendService.instance.ensureSignedIn();
      final exists = await BackendService.instance.employeesExist();
      if (!mounted) return;
      setState(() => _state = exists ? _StartupState.readyForLogin : _StartupState.readyForBootstrap);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _StartupState.error;
        _errorMessage = 'تعذر الاتصال بالخادم. تحقق من اتصال الإنترنت ثم حاول مجدداً.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _StartupState.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case _StartupState.notConfigured:
        return _MessageScreen(
          icon: Icons.settings_suggest_outlined,
          title: 'إعداد الاتصال بالخادم غير مكتمل',
          message:
              'افتح lib/config/supabase_config.dart وضع رابط مشروع Supabase ومفتاح anon الخاص بك '
              '(راجع README.md لخطوات الإعداد الكاملة)، ثم أعد تشغيل التطبيق.',
        );
      case _StartupState.error:
        return _MessageScreen(
          icon: Icons.wifi_off,
          title: 'تعذر الاتصال',
          message: _errorMessage ?? '',
          onRetry: _init,
        );
      case _StartupState.readyForBootstrap:
        return const BootstrapAdminScreen();
      case _StartupState.readyForLogin:
        return const LoginScreen();
    }
  }
}

class _MessageScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const _MessageScreen({required this.icon, required this.title, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: Colors.orange),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                if (onRetry != null) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
