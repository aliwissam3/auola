import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../models/product.dart';
import '../../models/sales.dart';
import 'cart_tab.dart';

/// "استبدال علاج" — swap a returned medicine for a replacement one and
/// automatically settle the price difference as an extra line on the same
/// invoice (positive = customer pays more, negative = refunded as a
/// discount).
Future<void> showSubstituteDialog(BuildContext context, CartTab cart) async {
  final data = context.read<AppData>();
  Product? oldProduct;
  Product? newProduct;
  double oldPrice = 0;
  double newPrice = 0;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final diff = newPrice - oldPrice;
        return AlertDialog(
          title: const Text('استبدال علاج'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('المادة المرتجعة (القديمة)'),
                const SizedBox(height: 6),
                _ProductPicker(
                  data: data,
                  selected: oldProduct,
                  onSelected: (p) => setState(() {
                    oldProduct = p;
                    oldPrice = p.salePrice;
                  }),
                ),
                const SizedBox(height: 16),
                const Text('المادة البديلة (الجديدة)'),
                const SizedBox(height: 6),
                _ProductPicker(
                  data: data,
                  selected: newProduct,
                  onSelected: (p) => setState(() {
                    newProduct = p;
                    newPrice = p.salePrice;
                  }),
                ),
                const SizedBox(height: 16),
                if (oldProduct != null && newProduct != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      diff == 0
                          ? 'لا يوجد فرق سعري'
                          : diff > 0
                              ? 'فرق يُضاف على الفاتورة: ${diff.toStringAsFixed(0)} د.ع'
                              : 'فرق يُخصم من الفاتورة: ${(-diff).toStringAsFixed(0)} د.ع',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: (oldProduct == null || newProduct == null)
                  ? null
                  : () {
                      final o = oldProduct!;
                      final n = newProduct!;
                      cart.items.removeWhere((it) => it.productId == o.id);
                      cart.items.add(SaleItem(
                        productId: n.id,
                        name: 'استبدال: ${o.name} ← ${n.name}',
                        unit: n.unit,
                        quantity: 1,
                        price: diff >= 0 ? diff : 0,
                        purchasePrice: 0,
                        discount: diff < 0 ? -diff : 0,
                      ));
                      cart.substituteNote =
                          'استبدال ${o.name} بـ ${n.name} (فرق ${diff.toStringAsFixed(0)} د.ع)';
                      Navigator.pop(ctx);
                    },
              child: const Text('تطبيق الاستبدال'),
            ),
          ],
        );
      },
    ),
  );
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({
    required this.data,
    required this.selected,
    required this.onSelected,
  });

  final AppData data;
  final Product? selected;
  final ValueChanged<Product> onSelected;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Product>(
      value: selected,
      isExpanded: true,
      items: data.products.items
          .map((p) => DropdownMenuItem(
                value: p,
                child: Text('${p.name} — ${p.salePrice.toStringAsFixed(0)} د.ع'),
              ))
          .toList(),
      onChanged: (p) {
        if (p != null) onSelected(p);
      },
      decoration: const InputDecoration(isDense: true),
    );
  }
}
