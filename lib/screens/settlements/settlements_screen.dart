import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../data/id_gen.dart';
import '../../models/operations.dart';
import '../../widgets/sale_shortcut_action.dart';

class SettlementsScreen extends StatelessWidget {
  const SettlementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التسديد والمصاريف'),
          actions: const [SaleShortcutAction()],
          bottom: const TabBar(tabs: [Tab(text: 'عمليات التسديد'), Tab(text: 'المصاريف')]),
        ),
        body: const TabBarView(children: [_SettlementsTab(), _ExpensesTab()]),
      ),
    );
  }
}

/// Only settlements *from reviewers/customers* live here - a supplier's
/// own settlements are managed from their own page (see
/// SupplierDetailScreen._payDialog), kept deliberately separate so a
/// warehouse payment is never mixed in with the pharmacy's customer
/// collections.
class _SettlementsTab extends StatelessWidget {
  const _SettlementsTab();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final rows = List.of(data.debtPayments.items)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSettlementDialog(context, data),
        icon: const Icon(Icons.add),
        label: const Text('إضافة تسديد'),
      ),
      body: rows.isEmpty
          ? const Center(child: Text('لا توجد عمليات تسديد بعد'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = rows[i];
                final customerName = data.customers.byId(p.customerId)?.name ?? '—';
                return ListTile(
                  leading: const Icon(Icons.arrow_downward, color: Colors.green),
                  title: Text('تسديد من مراجع — $customerName'),
                  subtitle: Text('${p.createdAt.year}/${p.createdAt.month}/${p.createdAt.day}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${p.amount.toStringAsFixed(0)} د.ع',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _editSettlementDialog(context, data, p.id, p.amount),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        onPressed: () => data.debtPayments.delete(p.id),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _addSettlementDialog(BuildContext context, AppData data) async {
    String? targetId;
    final amount = TextEditingController();
    final note = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('إضافة تسديد من مراجع'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: targetId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المراجع'),
                items: data.customers.items
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() => targetId = v),
              ),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المبلغ'),
              ),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amount.text) ?? 0;
                if (targetId == null || amt <= 0) return;
                await data.debtPayments.upsert(DebtPayment(
                  id: newId(),
                  customerId: targetId!,
                  amount: amt,
                  note: note.text.trim(),
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

  Future<void> _editSettlementDialog(
    BuildContext context,
    AppData data,
    String id,
    double currentAmount,
  ) async {
    final amount = TextEditingController(text: currentAmount.toStringAsFixed(0));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل مبلغ التسديد'),
        content: TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'المبلغ'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amount.text);
              if (amt == null || amt <= 0) return;
              final p = data.debtPayments.byId(id);
              if (p != null) {
                p.amount = amt;
                await data.debtPayments.upsert(p);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _ExpensesTab extends StatelessWidget {
  const _ExpensesTab();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final expenses = List.of(data.expenses.items)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final total = expenses.fold(0.0, (s, e) => s + e.amount);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _expenseDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('إضافة مصروف'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('إجمالي المصاريف: ${total.toStringAsFixed(0)} د.ع',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            child: expenses.isEmpty
                ? const Center(child: Text('لا توجد مصاريف مسجلة'))
                : ListView.separated(
                    itemCount: expenses.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = expenses[i];
                      final showCategory = e.category.isNotEmpty && e.category != 'عام';
                      return ListTile(
                        leading: Icon(
                          Icons.receipt_outlined,
                          color: e.isFixed ? Colors.blueGrey : Colors.orange,
                        ),
                        title: Text(e.title),
                        subtitle: Text(
                          '${e.createdAt.year}/${e.createdAt.month}/${e.createdAt.day}'
                          ' • ${e.isFixed ? 'ثابت' : 'متغير'}'
                          '${showCategory ? ' • ${e.category}' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${e.amount.toStringAsFixed(0)} د.ع'),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _expenseDialog(context, existing: e),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () => data.expenses.delete(e.id),
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

  Future<void> _expenseDialog(BuildContext context, {Expense? existing}) async {
    final data = context.read<AppData>();
    final title = TextEditingController(text: existing?.title ?? '');
    final amount = TextEditingController(text: existing?.amount.toStringAsFixed(0) ?? '');
    final category = TextEditingController(text: existing?.category ?? 'عام');
    var isFixed = existing?.isFixed ?? false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'إضافة مصروف' : 'تعديل المصروف'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'الوصف')),
              TextField(
                controller: amount,
                decoration: const InputDecoration(labelText: 'المبلغ'),
                keyboardType: TextInputType.number,
              ),
              TextField(controller: category, decoration: const InputDecoration(labelText: 'التصنيف')),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('مصروف ثابت')),
                  ButtonSegment(value: false, label: Text('مصروف متغير')),
                ],
                selected: {isFixed},
                onSelectionChanged: (s) => setState(() => isFixed = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amount.text) ?? 0;
                if (title.text.trim().isEmpty || amt <= 0) return;
                await data.expenses.upsert(Expense(
                  id: existing?.id ?? newId(),
                  title: title.text.trim(),
                  amount: amt,
                  category: category.text.trim().isEmpty ? 'عام' : category.text.trim(),
                  isFixed: isFixed,
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
