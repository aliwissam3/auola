import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/people.dart';
import '../services/auth_service.dart';

/// Blocks a screen with a clear "no permission" message instead of a
/// blank/broken page when the logged-in employee lacks the permission
/// it needs — enforced here (not just by hiding the dashboard card that
/// links to it) so permission checks hold no matter how the screen was
/// reached.
class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    required this.check,
    required this.label,
    required this.child,
  });

  final bool Function(EmployeePermissions p) check;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (auth.can(check)) return child;
    return _denied(context, label);
  }

  static Widget _denied(BuildContext context, String label) {
    return Scaffold(
      appBar: AppBar(title: const Text('صلاحية مطلوبة')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'ليس لديك صلاحية للوصول إلى $label — راجع الأدمن لتفعيل هذه الصلاحية',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Same idea as [PermissionGate] but for screens only a full admin
/// account (isAdmin, not a specific permission flag) should reach —
/// employees management, settings, and the pharmacies list.
class AdminGate extends StatelessWidget {
  const AdminGate({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (auth.isAdmin) return child;
    return PermissionGate._denied(context, label);
  }
}
