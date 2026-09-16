import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../data/id_gen.dart';
import '../../models/operations.dart';
import '../../models/product.dart';
import '../../models/sales.dart';

/// "راجع" — return or exchange one line from an already-completed sale.
/// A pure return puts the quantity back on the shelf and shrinks the
/// invoice total; an exchange swaps it for a different product, puts the
/// old one back, takes the new one out, and adjusts the invoice total by
/// the price difference. Either way the invoice itself is the record —
/// no separate ledger to keep in sync.
Future<void> showSaleReturnSheet(BuildContext context, SaleInvoice sale) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SaleReturnSheet(sale: sale),
  );
}

class _SaleReturnSheet extends StatelessWidget {
  const _SaleReturnSheet({required this.sale});
  final SaleInvoice sale;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    // Re-read the live invoice each build in case an item was just
    // returned/exchanged and the list shrank.
    final live = data.sales.byId(sale.id) ?? sale;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('راجع من هذه الفاتورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Text('${live.total.toStringAsFixed(0)} د.ع',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE0407A))),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: live.items.isEmpty
                  ? const Center(child: Text('ما بقت مواد بهذه الفاتورة — كلها رجعت', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: live.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = live.items[i];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text('${item.quantity.toStringAsFixed(0)} ${item.unit.labelAr} × ${item.price.toStringAsFixed(0)} د.ع'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _returnItem(context, data, live, item),
                                child: const Text('إرجاع'),
                              ),
                              TextButton(
                                onPressed: () => _exchangeItem(context, data, live, item),
                                child: const Text('استبدال'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _returnItem(BuildContext context, AppData data, SaleInvoice sale, SaleItem item) async {
    final qtyController = TextEditingController(text: item.quantity.toStringAsFixed(0));
    final confirmed = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إرجاع: ${item.name}'),
        content: TextField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'الكمية المرجعة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(qtyController.text) ?? 0),
            child: const Text('تأكيد الإرجاع'),
          ),
        ],
      ),
    );
    if (confirmed == null || confirmed <= 0) return;
    final returnQty = confirmed > item.quantity ? item.quantity : confirmed;

    // Put the quantity back on the shelf.
    final product = data.products.byId(item.productId);
    if (product != null) {
      await data.products.upsert(product.copyWith(quantity: product.quantity + returnQty.round()));
      await data.movements.upsert(StockMovement(
        id: newId(),
        productId: product.id,
        name: product.name,
        type: StockMovementType.stockIn,
        quantity: returnQty.round(),
        note: 'راجع من فاتورة بيع',
      ));
    }

    // Shrink or remove the line, then persist the invoice.
    final updatedItems = List<SaleItem>.from(sale.items);
    final idx = updatedItems.indexWhere((it) => it.productId == item.productId && it.price == item.price);
    if (idx != -1) {
      final remaining = item.quantity - returnQty;
      if (remaining <= 0) {
        updatedItems.removeAt(idx);
      } else {
        updatedItems[idx] = SaleItem(
          productId: item.productId,
          name: item.name,
          unit: item.unit,
          quantity: remaining,
          price: item.price,
          purchasePrice: item.purchasePrice,
          discount: item.discount * (remaining / item.quantity),
          isPartial: item.isPartial,
        );
      }
    }
    final updatedSale = SaleInvoice(
      id: sale.id,
      employeeId: sale.employeeId,
      items: updatedItems,
      customerId: sale.customerId,
      paymentType: sale.paymentType,
      paidAmount: sale.paidAmount,
      notes: sale.notes,
      substituteNote: sale.substituteNote,
      createdAt: sale.createdAt,
    );
    await data.sales.upsert(updatedSale);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم الإرجاع — رجعت الكمية للمخزون وانخصمت من الفاتورة')),
    );
  }

  Future<void> _exchangeItem(BuildContext context, AppData data, SaleInvoice sale, SaleItem item) async {
    Product? replacement;
    final qtyController = TextEditingController(text: item.quantity.toStringAsFixed(0));

    final result = await showDialog<Product>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('استبدال: ${item.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                value: replacement,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المادة البديلة'),
                items: data.products.items
                    .where((p) => p.id != item.productId)
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: (p) => setState(() => replacement = p),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الكمية'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, replacement),
              child: const Text('تأكيد الاستبدال'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final newQty = double.tryParse(qtyController.text) ?? item.quantity;
    if (newQty <= 0) return;

    // Old item back to stock; new item taken out of stock.
    final oldProduct = data.products.byId(item.productId);
    if (oldProduct != null) {
      await data.products.upsert(oldProduct.copyWith(quantity: oldProduct.quantity + item.quantity.round()));
    }
    await data.products.upsert(result.copyWith(quantity: result.quantity - newQty.round()));
    await data.movements.upsert(StockMovement(
      id: newId(),
      productId: item.productId,
      name: item.name,
      type: StockMovementType.stockIn,
      quantity: item.quantity.round(),
      note: 'استبدال بفاتورة بيع',
    ));
    await data.movements.upsert(StockMovement(
      id: newId(),
      productId: result.id,
      name: result.name,
      type: StockMovementType.stockOut,
      quantity: newQty.round(),
      note: 'استبدال بفاتورة بيع',
    ));

    final updatedItems = List<SaleItem>.from(sale.items);
    final idx = updatedItems.indexWhere((it) => it.productId == item.productId && it.price == item.price);
    if (idx != -1) {
      updatedItems[idx] = SaleItem(
        productId: result.id,
        name: result.name,
        unit: result.unit,
        quantity: newQty,
        price: result.salePrice,
        purchasePrice: result.purchasePrice,
      );
    }
    final updatedSale = SaleInvoice(
      id: sale.id,
      employeeId: sale.employeeId,
      items: updatedItems,
      customerId: sale.customerId,
      paymentType: sale.paymentType,
      paidAmount: sale.paidAmount,
      notes: sale.notes,
      substituteNote: sale.substituteNote,
      createdAt: sale.createdAt,
    );
    await data.sales.upsert(updatedSale);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم الاستبدال — تعدّل المخزون والفاتورة تلقائياً')),
    );
  }
}
