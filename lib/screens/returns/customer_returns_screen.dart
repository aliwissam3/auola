import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../data/id_gen.dart';
import '../../models/operations.dart';
import '../../models/people.dart';
import '../../models/product.dart';
import '../../widgets/sale_shortcut_action.dart';

/// Products a *customer* brought back to the pharmacy — separate from
/// "المواد المعادة للمذخر" (stock the pharmacy sends back to its own
/// supplier). Recording one here puts the quantity back into inventory
/// automatically, since the medicine physically came back to the shelf.
class CustomerReturnsScreen extends StatelessWidget {
  const CustomerReturnsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final items = List.of(data.customerReturns.items)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(title: const Text('المواد الراجعة من الزبائن'), actions: const [SaleShortcutAction()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCustomerReturnDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('تسجيل راجعة'),
      ),
      body: items.isEmpty
          ? const Center(child: Text('ما في مواد راجعة من الزبائن بعد'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = items[i];
                return ListTile(
                  leading: const Icon(Icons.assignment_return_outlined, color: Colors.teal),
                  title: Text(r.name),
                  subtitle: Text(
                    'الكمية: ${r.quantity}'
                    '${r.customerName != null ? ' • الزبون: ${r.customerName}' : ''}'
                    '${r.reason.isNotEmpty ? ' • ${r.reason}' : ''}'
                    '${r.refundAmount > 0 ? ' • استرجاع ${r.refundAmount.toStringAsFixed(0)} د.ع' : ''}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => data.customerReturns.delete(r.id),
                  ),
                );
              },
            ),
    );
  }

}

/// Opens the "record a customer return" dialog on its own, so a cashier
/// can log one directly from the POS/sales screen mid-sale, without
/// navigating away to the dedicated "المواد الراجعة من الزبائن" screen.
Future<void> showCustomerReturnDialog(BuildContext context) async {
    final data = context.read<AppData>();
    Product? product;
    Customer? customer;
    final qty = TextEditingController(text: '1');
    final reason = TextEditingController();
    final refund = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('تسجيل مادة راجعة من زبون'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Product>(
                    value: product,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'المادة'),
                    items: data.products.items
                        .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                        .toList(),
                    onChanged: (p) => setState(() => product = p),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Customer?>(
                    value: customer,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الزبون (اختياري)'),
                    items: [
                      const DropdownMenuItem<Customer?>(value: null, child: Text('بدون تحديد')),
                      ...data.customers.items
                          .map((c) => DropdownMenuItem<Customer?>(value: c, child: Text(c.name))),
                    ],
                    onChanged: (c) => setState(() => customer = c),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: qty,
                    decoration: const InputDecoration(labelText: 'الكمية الراجعة'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: refund,
                    decoration: const InputDecoration(labelText: 'المبلغ المسترجع للزبون (اختياري)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: reason, decoration: const InputDecoration(labelText: 'السبب (اختياري)')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final p = product;
                if (p == null) return;
                final returnedQty = int.tryParse(qty.text) ?? 0;
                if (returnedQty <= 0) return;

                await data.customerReturns.upsert(CustomerReturn(
                  id: newId(),
                  productId: p.id,
                  name: p.name,
                  quantity: returnedQty,
                  customerId: customer?.id,
                  customerName: customer?.name,
                  reason: reason.text.trim(),
                  refundAmount: double.tryParse(refund.text) ?? 0,
                ));

                // The medicine physically came back — put it back on the
                // shelf. A dedicated batch keeps this distinguishable in
                // stock history from a normal purchase.
                await data.products.upsert(p.copyWith(quantity: p.quantity + returnedQty));
                await data.batches.upsert(Batch(id: newId(), productId: p.id, quantity: returnedQty));

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ وإرجاع للمخزون'),
            ),
          ],
        ),
      ),
    );
  }
