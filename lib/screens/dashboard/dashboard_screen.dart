import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_status.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/status_badge.dart';
import '../login/login_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final data = context.watch<AppData>();
    final emp = auth.currentEmployee;

    final deficitCount = data.deficits.items.length;
    final expiringCount = data.expiringBatches().length;
    final ext = Theme.of(context).extension<AppPaletteColors>();
    final primary = ext?.primary ?? Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        actions: [
          // Reflects whether the last real attempt to reach the cloud
          // (startup connect, or any table load/save since) actually
          // succeeded — not a hardcoded "متصل", so a session that's
          // silently failing to sync (e.g. a phone that never actually
          // connected to Supabase) is visible instead of looking fine.
          ListenableBuilder(
            listenable: ConnectivityStatus.instance,
            builder: (context, _) => StatusBadge(
              label: ConnectivityStatus.instance.isConnected ? 'متصل' : 'غير متصل',
              tone: ConnectivityStatus.instance.isConnected
                  ? AppStatusTone.success
                  : AppStatusTone.danger,
              icon: Icons.circle,
              dense: true,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'تحديث البيانات',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              // Pulls every table fresh from the cloud rather than just
              // re-broadcasting whatever's already local — the fallback
              // for a sale/change made on another device (e.g. a phone
              // logged in over the LAN-QR feature) that hasn't shown up
              // here yet through realtime sync on its own.
              await data.refreshAll();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تحديث البيانات')),
              );
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'المزيد',
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
            onSelected: (route) {
              if (route == 'logout') {
                auth.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              } else {
                Navigator.pushNamed(context, route);
              }
            },
            itemBuilder: (_) => [
              if (emp?.isAdmin == true)
                const PopupMenuItem(
                  value: '/pharmacies',
                  child: ListTile(
                    leading: Icon(Icons.store_mall_directory_outlined),
                    title: Text('الصيدليات'),
                  ),
                ),
              if (emp?.isAdmin == true)
                const PopupMenuItem(
                  value: '/employees',
                  child: ListTile(
                    leading: Icon(Icons.badge_outlined),
                    title: Text('الموظفين'),
                  ),
                ),
              if (emp?.isAdmin == true)
                const PopupMenuItem(
                  value: '/settings',
                  child: ListTile(
                    leading: Icon(Icons.settings_outlined),
                    title: Text('الإعدادات'),
                  ),
                ),
              const PopupMenuItem(
                value: '/profile',
                child: ListTile(
                  leading: Icon(Icons.badge_outlined),
                  title: Text('الملف الشخصي'),
                ),
              ),
              if (emp?.isAdmin == true) const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout_rounded),
                  title: Text('تسجيل الخروج'),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/pos'),
        icon: const Icon(Icons.point_of_sale_rounded),
        label: const Text('فاتورة بيع جديدة'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: primary.withValues(alpha: 0.12),
                  child: Icon(Icons.person_rounded, color: primary),
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أهلاً بك 👋',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        emp?.name ?? 'مستخدم',
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (emp?.isAdmin == true)
                  const StatusBadge(
                    label: 'أدمن',
                    tone: AppStatusTone.info,
                    icon: Icons.verified_rounded,
                  ),
              ],
            ),
          ),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              crossAxisCount: _crossAxisCount(context),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.1,
              children: [
                for (final card
                    in _cards(context, auth, deficitCount, expiringCount))
                  if (!data.isCardHidden(card.id)) card.widget,
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Every dashboard card with a stable [id] (used for the admin's show/
  /// hide toggle in Settings — see [CardVisibility]) alongside the actual
  /// widget. Permission-gated cards (debts/lists/reports) are simply
  /// left out of the list entirely when the employee lacks that
  /// permission, same as before.
  List<_CardSpec> _cards(BuildContext context, AuthService auth,
      int deficitCount, int expiringCount) {
    return [
      _CardSpec(
        'products',
        DashboardCard(
          title: 'المنتجات',
          icon: Icons.medication_outlined,
          subtitle: 'إضافة • تعديل • كمية جديدة',
          onTap: () => Navigator.pushNamed(context, '/products'),
        ),
      ),
      _CardSpec(
        'attendance',
        DashboardCard(
          title: 'الحضور والانصراف',
          icon: Icons.access_time_outlined,
          subtitle: 'دخول وخروج الموظفين بنقرة',
          onTap: () => Navigator.pushNamed(context, '/attendance'),
        ),
      ),
      if (auth.can((p) => p.debts))
        _CardSpec(
          'debts',
          DashboardCard(
            title: 'ديون المراجعين',
            icon: Icons.receipt_long_outlined,
            onTap: () => Navigator.pushNamed(context, '/debts'),
          ),
        ),
      _CardSpec(
        'deficits',
        DashboardCard(
          title: 'النقوصات',
          icon: Icons.remove_shopping_cart_outlined,
          badgeCount: deficitCount,
          onTap: () => Navigator.pushNamed(context, '/deficits'),
        ),
      ),
      _CardSpec(
        'expiry',
        DashboardCard(
          title: 'الإكسباير القريب',
          icon: Icons.event_busy_outlined,
          badgeCount: expiringCount,
          onTap: () => Navigator.pushNamed(context, '/expiry'),
        ),
      ),
      _CardSpec(
        'reps',
        DashboardCard(
          title: 'المندوبين والمذخر',
          icon: Icons.local_shipping_outlined,
          onTap: () => Navigator.pushNamed(context, '/reps'),
        ),
      ),
      if (auth.can((p) => p.lists))
        _CardSpec(
          'lists',
          DashboardCard(
            title: 'كل القوائم',
            icon: Icons.list_alt_outlined,
            subtitle: 'بيع • شراء • بين الصيدليات',
            onTap: () => Navigator.pushNamed(context, '/lists'),
          ),
        ),
      _CardSpec(
        'returns',
        DashboardCard(
          title: 'المواد المعدة للاسترجاع',
          icon: Icons.keyboard_return_outlined,
          subtitle: 'للمذخر/المورد',
          onTap: () => Navigator.pushNamed(context, '/returns'),
        ),
      ),
      _CardSpec(
        'customer_returns',
        DashboardCard(
          title: 'الراجعة من الزبائن',
          icon: Icons.assignment_return_outlined,
          subtitle: 'يرجع للمخزون تلقائياً',
          onTap: () => Navigator.pushNamed(context, '/customer-returns'),
        ),
      ),
      _CardSpec(
        'movement',
        DashboardCard(
          title: 'حركة مادة',
          icon: Icons.swap_vert_circle_outlined,
          onTap: () => Navigator.pushNamed(context, '/movement'),
        ),
      ),
      _CardSpec(
        'settlements',
        DashboardCard(
          title: 'التسديد والمصاريف',
          icon: Icons.payments_outlined,
          onTap: () => Navigator.pushNamed(context, '/settlements'),
        ),
      ),
      _CardSpec(
        'entries',
        DashboardCard(
          title: 'الدخولات',
          icon: Icons.login_outlined,
          onTap: () => Navigator.pushNamed(context, '/entries'),
        ),
      ),
      _CardSpec(
        'purchases',
        DashboardCard(
          title: 'المشتريات',
          icon: Icons.camera_alt_outlined,
          subtitle: 'قسائم المندوبين + OCR',
          onTap: () => Navigator.pushNamed(context, '/purchases'),
        ),
      ),
      if (auth.can((p) => p.reports))
        _CardSpec(
          'reports',
          DashboardCard(
            title: 'التقارير',
            icon: Icons.insert_chart_outlined,
            subtitle: 'مبيعات • مشتريات • جرد',
            onTap: () => Navigator.pushNamed(context, '/reports'),
          ),
        ),
    ];
  }

  int _crossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 5;
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }
}

class _CardSpec {
  const _CardSpec(this.id, this.widget);
  final String id;
  final DashboardCard widget;
}

/// (id, Arabic label) for every dashboard card that CAN be hidden — used
/// by the Settings screen to build the show/hide checklist without
/// duplicating this list by hand there too.
const dashboardCardCatalog = <(String, String)>[
  ('products', 'المنتجات'),
  ('attendance', 'الحضور والانصراف'),
  ('debts', 'ديون المراجعين'),
  ('deficits', 'النقوصات'),
  ('expiry', 'الإكسباير القريب'),
  ('reps', 'المندوبين والمذخر'),
  ('lists', 'كل القوائم'),
  ('returns', 'المواد المعدة للاسترجاع'),
  ('customer_returns', 'الراجعة من الزبائن'),
  ('movement', 'حركة مادة'),
  ('settlements', 'التسديد والمصاريف'),
  ('entries', 'الدخولات'),
  ('purchases', 'المشتريات'),
  ('reports', 'التقارير'),
];

/// Where each dashboard card's id navigates to and which icon
/// represents it — kept alongside [dashboardCardCatalog] so the
/// "شاشة شراء اختصار" (section-shortcut) feature on the POS screen and
/// the dashboard grid always agree on both, without duplicating either
/// list by hand.
const dashboardCardRoutes = <String, String>{
  'products': '/products',
  'attendance': '/attendance',
  'debts': '/debts',
  'deficits': '/deficits',
  'expiry': '/expiry',
  'reps': '/reps',
  'lists': '/lists',
  'returns': '/returns',
  'customer_returns': '/customer-returns',
  'movement': '/movement',
  'settlements': '/settlements',
  'entries': '/entries',
  'purchases': '/purchases',
  'reports': '/reports',
};

const dashboardCardIcons = <String, IconData>{
  'products': Icons.medication_outlined,
  'attendance': Icons.access_time_outlined,
  'debts': Icons.receipt_long_outlined,
  'deficits': Icons.remove_shopping_cart_outlined,
  'expiry': Icons.event_busy_outlined,
  'reps': Icons.local_shipping_outlined,
  'lists': Icons.list_alt_outlined,
  'returns': Icons.keyboard_return_outlined,
  'customer_returns': Icons.assignment_return_outlined,
  'movement': Icons.swap_vert_circle_outlined,
  'settlements': Icons.payments_outlined,
  'entries': Icons.login_outlined,
  'purchases': Icons.camera_alt_outlined,
  'reports': Icons.insert_chart_outlined,
};
