import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../data/id_gen.dart';
import '../../models/operations.dart';
import '../../models/product.dart';
import '../../widgets/sale_shortcut_action.dart';

class ReturnsScreen extends StatelessWidget {
  const ReturnsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final items = List.of(data.returns.items)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(title: const Text('المواد المعادة للمذخر'), actions: const [SaleShortcutAction()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _itemDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('إضافة مادة معادة'),
      ),
      body: items.isEmpty
          ? const Center(child: Text('لا توجد مواد معادة بعد'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = items[i];
                final supplier = r.supplierId == null ? null : data.suppliers.byId(r.supplierId!);
                final details = [
                  'الكمية: ${r.quantity}',
                  if (supplier != null) 'المذخر: ${supplier.name}',
                  if (r.reason.isNotEmpty) r.reason,
                ].join(' • ');
                return ListTile(
                  leading: const Icon(Icons.keyboard_return, color: Colors.orange),
                  title: Text(r.name),
                  subtitle: Text(details),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _itemDialog(context, existing: r),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => data.returns.delete(r.id),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _itemDialog(BuildContext context, {ReturnItem? existing}) async {
    final data = context.read<AppData>();
    Product? product = existing == null ? null : data.products.byId(existing.productId);
    String? supplierId = existing?.supplierId ?? product?.supplierId;
    final qty = TextEditingController(text: existing?.quantity.toString() ?? '1');
    final reason = TextEditingController(text: existing?.reason ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'إضافة مادة معادة' : 'تعديل المادة المعادة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                value: product,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المادة'),
                items: data.products.items
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                // Picking the item defaults the warehouse/company to
                // wherever it was originally purchased from, since a
                // return is meant to go back to that same place - still
                // changeable below for the rare case it should go
                // elsewhere.
                onChanged: (p) => setState(() {
                  product = p;
                  supplierId ??= p?.supplierId;
                }),
              ),
              DropdownButtonFormField<String>(
                value: supplierId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المذخر / الشركة المعاد لها'),
                items: data.suppliers.items
                    .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                    .toList(),
                onChanged: (v) => setState(() => supplierId = v),
              ),
              TextField(
                controller: qty,
                decoration: const InputDecoration(labelText: 'الكمية'),
                keyboardType: TextInputType.number,
              ),
              TextField(controller: reason, decoration: const InputDecoration(labelText: 'السبب')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (product == null) return;
                await data.returns.upsert(ReturnItem(
                  id: existing?.id ?? newId(),
                  productId: product!.id,
                  name: product!.name,
                  quantity: int.tryParse(qty.text) ?? 1,
                  reason: reason.text.trim(),
                  supplierId: supplierId,
                  createdAt: existing?.createdAt,
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
