import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../data/id_gen.dart';
import '../../models/people.dart';
import '../../services/auth_service.dart';
import '../../widgets/sale_shortcut_action.dart';
import 'supplier_detail_screen.dart';

class RepsScreen extends StatelessWidget {
  const RepsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المندوبين والمذخر'),
          actions: const [SaleShortcutAction()],
          bottom: const TabBar(tabs: [Tab(text: 'المذاخر / الموردين'), Tab(text: 'المندوبين')]),
        ),
        body: const TabBarView(children: [_SuppliersTab(), _RepsTab()]),
      ),
    );
  }
}

class _SuppliersTab extends StatelessWidget {
  const _SuppliersTab();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final auth = context.watch<AuthService>();
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-supplier',
        onPressed: () => _addSupplierDialog(context),
        child: const Icon(Icons.add),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: data.suppliers.items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final s = data.suppliers.items[i];
          final balance = data.supplierBalance(s.id);
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.store_outlined)),
            title: Text(s.name),
            subtitle: Text(s.phone.isEmpty ? 'بدون هاتف' : s.phone),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${balance.toStringAsFixed(0)} د.ع',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: balance > 0 ? Colors.red : Colors.green,
                  ),
                ),
                if (auth.isAdmin)
                  IconButton(
                    tooltip: 'حذف المذخر',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(
                      context,
                      title: 'حذف المذخر',
                      message: 'هل تريد حذف "${s.name}"؟',
                      onConfirm: () => data.suppliers.delete(s.id),
                    ),
                  ),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SupplierDetailScreen(supplierId: s.id)),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addSupplierDialog(BuildContext context) async {
    final data = context.read<AppData>();
    final name = TextEditingController();
    final phone = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مذخر / مورد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'الهاتف')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await data.suppliers
                  .upsert(Supplier(id: newId(), name: name.text.trim(), phone: phone.text.trim()));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _RepsTab extends StatelessWidget {
  const _RepsTab();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final auth = context.watch<AuthService>();
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-rep',
        onPressed: () => _addRepDialog(context),
        child: const Icon(Icons.add),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: data.reps.items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final r = data.reps.items[i];
          final supplier = data.suppliers.byId(r.supplierId ?? '');
          final details = [
            r.phone.isEmpty ? 'بدون هاتف' : r.phone,
            if (r.company.isNotEmpty) r.company,
            supplier?.name ?? 'بدون مذخر',
          ].join(' • ');
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
            title: Text(r.name),
            subtitle: Text(details),
            trailing: auth.isAdmin
                ? IconButton(
                    tooltip: 'حذف المندوب',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(
                      context,
                      title: 'حذف المندوب',
                      message: 'هل تريد حذف "${r.name}"؟',
                      onConfirm: () => data.reps.delete(r.id),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  Future<void> _addRepDialog(BuildContext context) async {
    final data = context.read<AppData>();
    final name = TextEditingController();
    final phone = TextEditingController();
    final company = TextEditingController();
    String? supplierId;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('إضافة مندوب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'الهاتف')),
              TextField(controller: company, decoration: const InputDecoration(labelText: 'الشركة')),
              DropdownButtonFormField<String>(
                value: supplierId,
                decoration: const InputDecoration(labelText: 'المذخر'),
                items: data.suppliers.items
                    .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                    .toList(),
                onChanged: (v) => setState(() => supplierId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                await data.reps.upsert(Rep(
                  id: newId(),
                  name: name.text.trim(),
                  phone: phone.text.trim(),
                  company: company.text.trim(),
                  supplierId: supplierId,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirms before an irreversible delete, then shows a SnackBar once it
/// actually ran — so pressing the button always gives a clear, visible
/// result instead of a row that only silently may or may not have gone.
Future<void> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  required Future<void> Function() onConfirm,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await onConfirm();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('تم الحذف')),
  );
}
