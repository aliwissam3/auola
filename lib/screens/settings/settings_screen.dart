import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../models/card_visibility.dart';
import '../../models/section_shortcut.dart';
import '../../screens/dashboard/dashboard_screen.dart' show dashboardCardCatalog, dashboardCardIcons;
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final auth = context.watch<AuthService>();
    final settings = context.watch<SettingsService>();

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('هوية الألوان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('اختر باقة الألوان المفضّلة — يُحفظ اختيارك تلقائياً',
              style: TextStyle(fontSize: 12, color: Color(0xFF4A4A4A), fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: AppPalette.all.map((p) {
              final selected = themeProvider.palette.id == p.id;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => themeProvider.setPalette(p.id),
                child: Container(
                  decoration: BoxDecoration(
                    color: p.dark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? p.accent : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _swatch(p.primary),
                          _swatch(p.accent),
                          _swatch(p.light),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        p.nameAr,
                        style: TextStyle(
                          color: p.isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle, color: p.accent, size: 18),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const Divider(height: 40),
          const Text('تنبيه الإكسباير القريب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('نبّهني بالمواد التي ستنتهي صلاحيتها خلال هذه المدة (بالأيام)',
              style: TextStyle(fontSize: 12, color: Color(0xFF4A4A4A), fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _ExpiryThresholdTile(settings: settings),
          const Divider(height: 40),
          const Text('اسم وكلمة مرور الأدمن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('بيانات دخولك كأدمن — غيّرها من هنا بدل ما ترجع للمبرمج',
              style: TextStyle(fontSize: 12, color: Color(0xFF4A4A4A), fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (auth.isAdmin && auth.currentEmployee != null)
            _AdminCredentialsTile(auth: auth)
          else
            const Text('هذه الميزة متاحة للأدمن فقط', style: TextStyle(color: Color(0xFF4A4A4A), fontWeight: FontWeight.w600)),
          const Divider(height: 40),
          const Text('خانات لوحة التحكم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('عطّل أي خانة ما تحتاجها — تختفي من الداشبورد لكل الموظفين حتى ترجعها',
              style: TextStyle(fontSize: 12, color: Color(0xFF4A4A4A), fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (auth.isAdmin)
            const _CardVisibilityList()
          else
            const Text('هذه الميزة متاحة للأدمن فقط', style: TextStyle(color: Color(0xFF4A4A4A), fontWeight: FontWeight.w600)),
          const Divider(height: 40),
          const Text('اختصارات شاشة البيع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('اختر الشاشات التي تريدها كأزرار سريعة تظهر بشاشة البيع، للتنقل بينها بضغطة وحدة',
              style: TextStyle(fontSize: 12, color: Color(0xFF4A4A4A), fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          const _SectionShortcutsList(),
        ],
      ),
    );
  }

  Widget _swatch(Color c) => Container(
        width: 18,
        height: 18,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}

class _ExpiryThresholdTile extends StatefulWidget {
  const _ExpiryThresholdTile({required this.settings});
  final SettingsService settings;

  @override
  State<_ExpiryThresholdTile> createState() => _ExpiryThresholdTileState();
}

class _ExpiryThresholdTileState extends State<_ExpiryThresholdTile> {
  late final _days = TextEditingController(text: '${widget.settings.expiryAlertDays}');

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _days,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'عدد الأيام'),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () async {
            final v = int.tryParse(_days.text);
            if (v == null || v <= 0) return;
            await widget.settings.setExpiryAlertDays(v);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تحديث مدة التنبيه')),
            );
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _AdminCredentialsTile extends StatefulWidget {
  const _AdminCredentialsTile({required this.auth});
  final AuthService auth;

  @override
  State<_AdminCredentialsTile> createState() => _AdminCredentialsTileState();
}

class _AdminCredentialsTileState extends State<_AdminCredentialsTile> {
  late final _name = TextEditingController(text: widget.auth.currentEmployee?.name ?? '');
  late final _password = TextEditingController(text: widget.auth.currentEmployee?.password ?? '');

  @override
  Widget build(BuildContext context) {
    final data = context.read<AppData>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'اسم المستخدم'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              final employee = widget.auth.currentEmployee;
              if (employee == null) return;
              final newName = _name.text.trim();
              final newPassword = _password.text;
              if (newName.isEmpty || newPassword.isEmpty) return;
              employee.name = newName;
              employee.password = newPassword;
              await data.employees.upsert(employee);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تحديث بيانات الدخول — استخدمها بالمرة الجاية')),
              );
            },
            child: const Text('حفظ'),
          ),
        ),
      ],
    );
  }
}

class _CardVisibilityList extends StatelessWidget {
  const _CardVisibilityList();

  @override
  Widget build(BuildContext context) {
    final data = context.read<AppData>();
    // AppData itself isn't a ChangeNotifier, so context.watch<AppData>()
    // never rebuilds this widget on its own — the app only ever seemed
    // to reflect a change here because SOME other listened value forced
    // a full-app rebuild first. Listening directly to the one repository
    // this list actually reads/writes guarantees it updates the instant
    // a switch is toggled, regardless of what else is or isn't rebuilding
    // elsewhere in the tree.
    return ListenableBuilder(
      listenable: data.cardVisibility,
      builder: (context, _) => Column(
        children: [
          for (final (id, label) in dashboardCardCatalog)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              value: !data.isCardHidden(id),
              onChanged: (visible) async {
                final existing = data.cardVisibility.items.where((c) => c.id == id).firstOrNull;
                if (existing != null) {
                  existing.hidden = !visible;
                  await data.cardVisibility.upsert(existing);
                } else {
                  await data.cardVisibility.upsert(CardVisibility(id: id, hidden: !visible));
                }
              },
            ),
        ],
      ),
    );
  }
}

class _SectionShortcutsList extends StatelessWidget {
  const _SectionShortcutsList();

  @override
  Widget build(BuildContext context) {
    final data = context.read<AppData>();
    // Same reasoning as _CardVisibilityList above: listen directly to
    // the repository this list reads/writes so a toggle is reflected
    // immediately, not only when something else happens to force a
    // wider rebuild.
    return ListenableBuilder(
      listenable: data.sectionShortcuts,
      builder: (context, _) => Column(
        children: [
          for (final (id, label) in dashboardCardCatalog)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              secondary: Icon(dashboardCardIcons[id]),
              title: Text(label),
              value: data.isSectionShortcut(id),
              onChanged: (checked) {
                if (checked) {
                  data.sectionShortcuts.upsert(SectionShortcut(id: id));
                } else {
                  data.sectionShortcuts.delete(id);
                }
              },
            ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
