import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../data/id_gen.dart';
import '../../models/operations.dart';
import '../../models/product.dart';
import '../../utils/arabic.dart';
import '../../widgets/sale_shortcut_action.dart';

class DeficitsScreen extends StatefulWidget {
  const DeficitsScreen({super.key});

  @override
  State<DeficitsScreen> createState() => _DeficitsScreenState();
}

class _DeficitsScreenState extends State<DeficitsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final lowStock = data.lowStockProducts;
    final wide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(title: const Text('النقوصات'), actions: const [SaleShortcutAction()]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'بحث بالباركود أو الاسم',
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'إضافة مادة جديدة',
                  icon: const Icon(Icons.add),
                  onPressed: () => _addDialog(context, initialName: _search),
                ),
              ],
            ),
          ),
          if (lowStock.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _showLowStockDialog(context, data),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تنبيه: ${lowStock.length} مادة اقتربت كميتها من النفاد — اضغط للعرض',
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: DeficitStatus.values
                        .map((s) => Expanded(
                              child: _DeficitColumn(status: s, search: _search),
                            ))
                        .toList(),
                  )
                : ListView(
                    children: DeficitStatus.values
                        .map((s) => SizedBox(
                              height: 320,
                              child: _DeficitColumn(status: s, search: _search),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  void _showLowStockDialog(BuildContext context, AppData data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مواد اقتربت من النفاد'),
        content: SizedBox(
          width: 380,
          child: ListView(
            shrinkWrap: true,
            children: data.lowStockProducts
                .map((p) => ListTile(
                      title: Text(p.name),
                      trailing: Text('${p.quantity} ${p.unit.labelAr}',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  static Future<void> _addDialog(BuildContext context, {String initialName = ''}) async {
    final data = context.read<AppData>();
    final name = TextEditingController(text: initialName);
    final requestedBy = TextEditingController();
    var status = DeficitStatus.missing;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('إضافة نقص'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المادة')),
              TextField(
                controller: requestedBy,
                decoration: const InputDecoration(labelText: 'طلب من (اسم المراجع/الموظف)'),
              ),
              DropdownButtonFormField<DeficitStatus>(
                value: status,
                items: DeficitStatus.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.labelAr)))
                    .toList(),
                onChanged: (v) => setState(() => status = v ?? status),
                decoration: const InputDecoration(labelText: 'الحالة'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                await data.deficits.upsert(DeficitItem(
                  id: newId(),
                  name: name.text.trim(),
                  status: status,
                  requestedBy: requestedBy.text.trim(),
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

class _DeficitColumn extends StatelessWidget {
  const _DeficitColumn({required this.status, required this.search});
  final DeficitStatus status;
  final String search;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final items = data.deficits.items
        .where((d) => d.status == status && arabicContains(d.name, search))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              '${status.labelAr} (${items.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('لا توجد مواد', style: TextStyle(fontSize: 12)))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final d = items[i];
                      return ListTile(
                        dense: true,
                        title: Text(d.name),
                        subtitle: d.requestedBy.isEmpty ? null : Text('طلب: ${d.requestedBy}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy_outlined, size: 18),
                              tooltip: 'نسخ إلى قسم آخر',
                              onPressed: () => _copyMenu(context, data, d),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () => data.deficits.delete(d.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyMenu(BuildContext context, AppData data, DeficitItem item) async {
    final target = await showMenu<DeficitStatus>(
      context: context,
      position: const RelativeRect.fromLTRB(200, 200, 0, 0),
      items: DeficitStatus.values
          .map((s) => PopupMenuItem(value: s, child: Text('نسخ إلى: ${s.labelAr}')))
          .toList(),
    );
    if (target == null) return;
    await data.deficits.upsert(DeficitItem(
      id: newId(),
      name: item.name,
      status: target,
      requestedBy: item.requestedBy,
      note: item.note,
    ));
  }
}
