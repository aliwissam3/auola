import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../data/id_gen.dart';
import '../../models/operations.dart';
import '../../models/product.dart';
import '../../models/sales.dart';
import '../../widgets/sale_shortcut_action.dart';
import 'sale_return_sheet.dart';

class ListsScreen extends StatelessWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('كل القوائم'),
          actions: const [SaleShortcutAction()],
          bottom: const TabBar(tabs: [
            Tab(text: 'قوائم البيع'),
            Tab(text: 'قوائم الشراء'),
            Tab(text: 'أدوية بين الصيدليات'),
            Tab(text: 'قوائمي'),
          ]),
        ),
        body: const TabBarView(children: [
          _SalesListTab(),
          _PurchaseListTab(),
          _CrossPharmacyTab(),
          _CustomListsTab(),
        ]),
      ),
    );
  }
}

class _SalesListTab extends StatelessWidget {
  const _SalesListTab();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final sales = List.of(data.sales.items)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final manualLists = List.of(data.customLists.items.where((l) => l.kind == 'sale'))
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-sale-list',
        onPressed: () => _addManualListDialog(context, kind: 'sale'),
        icon: const Icon(Icons.add),
        label: const Text('قائمة بيع جديدة'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          if (sales.isEmpty && manualLists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('لا توجد فواتير أو قوائم بيع بعد — أضف واحدة')),
            ),
          for (final s in sales) ...[
            Builder(builder: (context) {
              final customer = s.customerId != null ? data.customers.byId(s.customerId!) : null;
              return ListTile(
                leading: Icon(
                  s.paymentType == PaymentType.credit ? Icons.receipt_long : Icons.point_of_sale,
                ),
                title: Text('${s.items.length} مادة — ${s.total.toStringAsFixed(0)} د.ع'),
                subtitle: Text(
                  '${s.paymentType.labelAr}${customer != null ? ' • ${customer.name}' : ''} • ${s.createdAt.year}/${s.createdAt.month}/${s.createdAt.day}',
                ),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.assignment_return_outlined, size: 18),
                  label: const Text('راجع'),
                  onPressed: s.items.isEmpty ? null : () => showSaleReturnSheet(context, s),
                ),
              );
            }),
            const Divider(height: 1),
          ],
          if (manualLists.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('قوائم بيع يدوية', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            for (final l in manualLists) _ManualListTile(list: l),
          ],
        ],
      ),
    );
  }
}

class _PurchaseListTab extends StatelessWidget {
  const _PurchaseListTab();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final purchases = List.of(data.purchases.items)
      ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    final manualLists = List.of(data.customLists.items.where((l) => l.kind == 'purchase'))
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-purchase-list',
        onPressed: () => _addManualListDialog(context, kind: 'purchase'),
        icon: const Icon(Icons.add),
        label: const Text('قائمة شراء جديدة'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          if (purchases.isEmpty && manualLists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('لا توجد فواتير أو قوائم شراء بعد — أضف واحدة')),
            ),
          for (final p in purchases) ...[
            Builder(builder: (context) {
              final supplier = data.suppliers.byId(p.supplierId);
              return ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text('${supplier?.name ?? '—'} — ${p.total.toStringAsFixed(0)} د.ع'),
                subtitle: Text(
                  '${p.items.length} مادة • ${p.purchaseDate.year}/${p.purchaseDate.month}/${p.purchaseDate.day}',
                ),
                trailing: Text(
                  p.remaining > 0 ? 'متبقي ${p.remaining.toStringAsFixed(0)}' : 'مسدد بالكامل',
                  style: TextStyle(color: p.remaining > 0 ? Colors.red : Colors.green, fontSize: 12),
                ),
              );
            }),
            const Divider(height: 1),
          ],
          if (manualLists.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('قوائم شراء يدوية', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            for (final l in manualLists) _ManualListTile(list: l),
          ],
        ],
      ),
    );
  }
}

Future<void> _addManualListDialog(BuildContext context, {required String kind}) async {
  final data = context.read<AppData>();
  final title = TextEditingController();
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(kind == 'sale' ? 'قائمة بيع جديدة' : 'قائمة شراء جديدة'),
      content: TextField(
        controller: title,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'اسم القائمة'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () async {
            if (title.text.trim().isEmpty) return;
            await data.customLists.upsert(CustomList(id: newId(), title: title.text.trim(), kind: kind));
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('إنشاء'),
        ),
      ],
    ),
  );
}

/// One manually-added list (sale/purchase/custom alike) — an expandable
/// title with its item rows and an inline add-item field, shared by all
/// three tabs so the "add a list" behavior is identical everywhere.
class _ManualListTile extends StatelessWidget {
  const _ManualListTile({required this.list});
  final CustomList list;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    return ExpansionTile(
      title: Text(list.title),
      subtitle: Text('${list.items.length} عنصر'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () => data.customLists.delete(list.id),
      ),
      children: [
        ...list.items.asMap().entries.map((e) => ListTile(
              dense: true,
              title: Text(e.value),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  list.items.removeAt(e.key);
                  data.customLists.upsert(list);
                },
              ),
            )),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _AddListItemField(
            onAdd: (text) {
              list.items.add(text);
              data.customLists.upsert(list);
            },
          ),
        ),
      ],
    );
  }
}

class _CrossPharmacyTab extends StatelessWidget {
  const _CrossPharmacyTab();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    if (data.pharmacies.items.length < 2) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'أضف أكثر من صيدلية واحدة من شاشة "الصيدليات" لعرض توفر الأدوية بينها',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Scaffold(
      body: ListView(
        children: data.pharmacies.items.map((ph) {
          final products = data.products.items.where((p) => p.pharmacyId == ph.id).toList();
          return ExpansionTile(
            title: Text(ph.name),
            subtitle: Text('${products.length} مادة'),
            children: [
              ...products.map((p) => ListTile(
                    title: Text(p.name),
                    subtitle: Text('بيع ${p.salePrice.toStringAsFixed(0)} د.ع'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${p.quantity} ${p.unit.labelAr}'),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _productDialog(context, data, ph.id, existing: p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          onPressed: () => data.products.delete(p.id),
                        ),
                      ],
                    ),
                  )),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text('إضافة مادة لـ ${ph.name}'),
                  onPressed: () => _productDialog(context, data, ph.id),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Future<void> _productDialog(BuildContext context, AppData data, String pharmacyId, {Product? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final quantity = TextEditingController(text: existing?.quantity.toString() ?? '0');
    final purchasePrice = TextEditingController(text: existing?.purchasePrice.toStringAsFixed(0) ?? '');
    final salePrice = TextEditingController(text: existing?.salePrice.toStringAsFixed(0) ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'إضافة مادة' : 'تعديل مادة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المادة')),
            TextField(
              controller: quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الكمية'),
            ),
            TextField(
              controller: purchasePrice,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'سعر الشراء'),
            ),
            TextField(
              controller: salePrice,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'سعر البيع'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await data.products.upsert(Product(
                id: existing?.id ?? newId(),
                name: name.text.trim(),
                quantity: int.tryParse(quantity.text) ?? 0,
                purchasePrice: double.tryParse(purchasePrice.text) ?? 0,
                salePrice: double.tryParse(salePrice.text) ?? 0,
                pharmacyId: pharmacyId,
              ));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

/// User-created free-form lists (e.g. a to-buy note) — the "أضيف قائمة
/// جديدة" corner action lives here as its own FAB, same pattern as the
/// suppliers/reps tabs on the reps screen.
class _CustomListsTab extends StatelessWidget {
  const _CustomListsTab();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final lists = List.of(data.customLists.items.where((l) => l.kind == 'custom'))
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addManualListDialog(context, kind: 'custom'),
        icon: const Icon(Icons.add),
        label: const Text('قائمة جديدة'),
      ),
      body: lists.isEmpty
          ? const Center(child: Text('لا توجد قوائم بعد — أضف واحدة'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: lists.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _ManualListTile(list: lists[i]),
            ),
    );
  }
}

class _AddListItemField extends StatefulWidget {
  const _AddListItemField({required this.onAdd});
  final ValueChanged<String> onAdd;

  @override
  State<_AddListItemField> createState() => _AddListItemFieldState();
}

class _AddListItemFieldState extends State<_AddListItemField> {
  final _controller = TextEditingController();

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(labelText: 'إضافة عنصر', isDense: true),
            onSubmitted: (_) => _submit(),
          ),
        ),
        IconButton(icon: const Icon(Icons.add), onPressed: _submit),
      ],
    );
  }
}
