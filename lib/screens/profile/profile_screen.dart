import 'dart:html' as html;

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import '../../services/store_account_service.dart';
import '../../services/subscription_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../pos/barcode_scanner_screen.dart';

/// Pharmacy name, owner name, and the subscription's status/renewal -
/// the subscription itself is enforced app-wide by [SubscriptionService]
/// and the lockout screen, this is just where it's managed.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _pharmacyName = TextEditingController(
      text: context.read<SubscriptionService>().pharmacyName);
  late final _ownerName = TextEditingController(
      text: context.read<SubscriptionService>().ownerName);
  final _renewalCode = TextEditingController();
  String? _renewError;

  /// Entered once and done, per the pharmacist's own request — this
  /// screen no longer sits open as an editable form by default. Starts
  /// in edit mode only the very first time (nothing saved yet); every
  /// later visit shows a plain read-only summary until the pencil icon
  /// is pressed on purpose.
  late bool _editingProfile = _pharmacyName.text.trim().isEmpty &&
      _ownerName.text.trim().isEmpty;

  Future<void> _saveProfile() async {
    await context.read<SubscriptionService>().saveProfile(
          pharmacyName: _pharmacyName.text.trim(),
          ownerName: _ownerName.text.trim(),
        );
    if (!mounted) return;
    setState(() => _editingProfile = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ بيانات الملف الشخصي')),
    );
  }

  Future<void> _renew() async {
    final ok = await context.read<SubscriptionService>().applyRenewalCode(_renewalCode.text);
    if (!mounted) return;
    if (ok) {
      setState(() => _renewError = null);
      _renewalCode.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تجديد الاشتراك بنجاح')),
      );
    } else {
      setState(() => _renewError = 'كود التجديد غير صحيح');
    }
  }

  Future<void> _copyStoreId() async {
    final id = StoreAccountService.instance.storeId;
    if (id == null) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ رقم الحساب')),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج من حساب الصيدلية'),
        content: const Text(
          'راح تحتاج تسجل الدخول برقم الهاتف والرمز مرة ثانية للرجوع. الاستمرار؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تسجيل الخروج')),
        ],
      ),
    );
    if (confirmed != true) return;
    await StoreAccountService.instance.signOut();
    // Simplest way to guarantee every screen/repo forgets the old
    // pharmacy's data rather than trying to tear down 20+ live Supabase
    // realtime subscriptions and in-memory repositories by hand.
    if (kIsWeb) html.window.location.reload();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;
    _renewalCode.text = code;
    await _renew();
  }

  @override
  void dispose() {
    _pharmacyName.dispose();
    _ownerName.dispose();
    _renewalCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppPaletteColors>();
    final primary = ext?.primary ?? theme.colorScheme.primary;
    final sub = context.watch<SubscriptionService>();
    final isMobile = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final expired = sub.isExpired;
    final remaining = sub.daysRemaining;
    final statusColor = expired ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.local_pharmacy_rounded, color: primary, size: 40),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  sub.pharmacyName.isEmpty ? 'صيدليتي' : sub.pharmacyName,
                  style: theme.textTheme.titleLarge,
                ),
                if (sub.ownerName.isNotEmpty)
                  Text(
                    sub.ownerName,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: 'بيانات الصيدلية',
            icon: Icons.storefront_outlined,
            trailing: _editingProfile
                ? null
                : IconButton(
                    tooltip: 'تعديل',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => setState(() => _editingProfile = true),
                  ),
            children: _editingProfile
                ? [
                    TextField(
                      controller: _pharmacyName,
                      decoration: const InputDecoration(
                        labelText: 'اسم الصيدلية',
                        prefixIcon: Icon(Icons.local_pharmacy_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _ownerName,
                      decoration: const InputDecoration(
                        labelText: 'اسم صاحب الصيدلية',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveProfile,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('حفظ'),
                      ),
                    ),
                  ]
                : [
                    _ReadOnlyRow(
                      icon: Icons.local_pharmacy_outlined,
                      label: 'اسم الصيدلية',
                      value: _pharmacyName.text,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ReadOnlyRow(
                      icon: Icons.person_outline_rounded,
                      label: 'اسم صاحب الصيدلية',
                      value: _ownerName.text,
                    ),
                  ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'الاشتراك',
            icon: Icons.workspace_premium_outlined,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.mdRadius,
                  border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          expired ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                          color: statusColor,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          expired ? 'الاشتراك منتهي' : 'الاشتراك فعّال',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: statusColor),
                        ),
                      ],
                    ),
                    if (sub.expiry != null) ...[
                      const SizedBox(height: 6),
                      Text('تاريخ الانتهاء: ${sub.expiry!.year}/${sub.expiry!.month}/${sub.expiry!.day}'),
                    ],
                    if (!expired) Text('متبقي: $remaining يوم'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _renewalCode,
                decoration: InputDecoration(
                  labelText: 'كود تجديد الاشتراك',
                  prefixIcon: const Icon(Icons.qr_code_2_rounded),
                  suffixIcon: isMobile
                      ? IconButton(
                          tooltip: 'مسح بالكاميرا',
                          icon: const Icon(Icons.camera_alt_outlined),
                          onPressed: _scan,
                        )
                      : null,
                ),
                onSubmitted: (_) => _renew(),
              ),
              if (_renewError != null) ...[
                const SizedBox(height: 6),
                Text(_renewError!, style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _renew,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تجديد الاشتراك'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'حساب الصيدلية',
            icon: Icons.account_circle_outlined,
            children: [
              _ReadOnlyRow(
                icon: Icons.phone_outlined,
                label: 'رقم الهاتف',
                value: StoreAccountService.instance.phone ?? '',
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _ReadOnlyRow(
                      icon: Icons.tag,
                      label: 'رقم الحساب',
                      value: StoreAccountService.instance.storeId ?? '',
                    ),
                  ),
                  IconButton(
                    tooltip: 'نسخ',
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    onPressed: _copyStoreId,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('تسجيل الخروج'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A titled, shadowed card grouping related fields — the same "floating
/// card" language used across the rest of the app (dashboard stats,
/// the subscription lock screen) instead of bare text under a heading.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppPaletteColors>();
    final primary = ext?.primary ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: AppRadius.lgRadius,
        boxShadow: AppShadows.card(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

/// A label/value pair shown once the pharmacy/owner name has already
/// been entered and saved — a plain summary instead of an always-open
/// editable field, until "تعديل" is pressed on purpose.
class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(
                value.isEmpty ? '—' : value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
