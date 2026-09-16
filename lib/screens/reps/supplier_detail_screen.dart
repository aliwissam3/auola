import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../data/id_gen.dart';
import '../../models/operations.dart';
import '../../models/product.dart';
import '../../models/purchases.dart';
import '../../models/supplier_list.dart';
import '../../widgets/sale_shortcut_action.dart';

/// A supplier/warehouse's own page: what they've supplied us (with
/// editable purchase prices), our running debt to them, and quick
/// actions to add to that debt or settle it.
class SupplierDetailScreen extends StatelessWidget {
  const SupplierDetailScreen({super.key, required this.supplierId});
  final String supplierId;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final supplier = data.suppliers.byId(supplierId);
    if (supplier == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('المورد')),
        body: const Center(child: Text('هذا المورد لم يعد موجوداً')),
      );
    }
    final balance = data.supplierBalance(supplierId);
    final products = data.products.items.where((p) => p.supplierId == supplierId).toList();

    return Scaffold(
      appBar: AppBar(title: Text(supplier.name), actions: const [SaleShortcutAction()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (balance > 0 ? Colors.red : Colors.green).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text('المبلغ المطلوب منّا'),
                const SizedBox(height: 4),
                Text('${balance.toStringAsFixed(0)} د.ع',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة إلى الدين'),
                  onPressed: () => _addDebtDialog(context, data),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('تسديد'),
                  onPressed: () => _payDialog(context, data),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('القائمة'),
                  onPressed: () => _addListDialog(context, data),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Text('القوائم المصوّرة (${data.supplierLists.items.where((l) => l.supplierId == supplierId).length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final lists = data.supplierLists.items.where((l) => l.supplierId == supplierId).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            if (lists.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('ما في قوائم مصوّرة بعد لهذا المورد'),
              );
            }
            return SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: lists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final l = lists[i];
                  return GestureDetector(
                    onTap: () => _viewListImage(context, l),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(l.imageBase64),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 80,
                          child: Text(l.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          }),
          const Divider(height: 32),
          Text('المواد المستوردة من هذا المورد (${products.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('لا توجد مواد مسجلة من هذا المورد بعد'),
            )
          else
            ...products.map((p) => Card(
                  child: ListTile(
                    title: Text(p.name),
                    subtitle: Text('المخزون: ${p.quantity} ${p.unit.labelAr}'),
                    trailing: Text('${p.purchasePrice.toStringAsFixed(0)} د.ع',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () => _editPriceDialog(context, data, p),
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _editPriceDialog(BuildContext context, AppData data, Product p) async {
    final price = TextEditingController(text: p.purchasePrice.toStringAsFixed(0));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل سعر شراء: ${p.name}'),
        content: TextField(
          controller: price,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'سعر الشراء'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final v = double.tryParse(price.text);
              if (v != null) {
                await data.products.upsert(p.copyWith(purchasePrice: v));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _addDebtDialog(BuildContext context, AppData data) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة إلى دين المورد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              final v = double.tryParse(amount.text) ?? 0;
              if (v <= 0) return;
              await data.purchases.upsert(Purchase(
                id: newId(),
                supplierId: supplierId,
                items: [
                  PurchaseItem(
                    productId: 'manual-debt',
                    name: note.text.trim().isEmpty ? 'دين يدوي' : note.text.trim(),
                    quantity: 1,
                    unitCost: v,
                  ),
                ],
                paidAmount: 0,
              ));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _payDialog(BuildContext context, AppData data) async {
    final balance = data.supplierBalance(supplierId);
    final amount = TextEditingController();
    final discountPercent = TextEditingController();
    final note = TextEditingController();
    var isExternal = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final pct = double.tryParse(discountPercent.text) ?? 0;
          final discountAmount = balance * (pct / 100);
          return AlertDialog(
            title: const Text('تسديد للمورد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الرصيد الحالي: ${balance.toStringAsFixed(0)} د.ع',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ المدفوع نقداً'),
                  onChanged: (_) => setState(() {}),
                ),
                TextField(
                  controller: discountPercent,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'نسبة خصم (%)',
                    helperText: 'خصم منحه المورد - يُخصم من الرصيد بدون دفع نقدي',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (pct > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('قيمة الخصم: ${discountAmount.toStringAsFixed(0)} د.ع',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0B6B4F))),
                  ),
                TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة')),
                CheckboxListTile(
                  value: isExternal,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('دفعة خارجية', style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                    'مدفوعة من خارج قاصة الصيدلية - تُستثنى من دخل المبيعات',
                    style: TextStyle(fontSize: 11),
                  ),
                  onChanged: (v) => setState(() => isExternal = v ?? false),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  final v = double.tryParse(amount.text) ?? 0;
                  if (v <= 0 && discountAmount <= 0) return;
                  await data.supplierPayments.upsert(SupplierPayment(
                    id: newId(),
                    supplierId: supplierId,
                    amount: v,
                    discountAmount: discountAmount,
                    isExternal: isExternal,
                    note: note.text.trim(),
                  ));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }
}

extension _SupplierListDialogs on SupplierDetailScreen {
  Future<void> _addListDialog(BuildContext context, AppData data) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('التقاط صورة بالكاميرا'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final imageBase64 = base64Encode(bytes);

    final now = DateTime.now();
    final defaultName = '${now.year}/${now.month}/${now.day}';
    final nameController = TextEditingController(text: defaultName);
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حفظ القائمة'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'اسم القائمة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (confirmed != true) return;

    await data.supplierLists.upsert(SupplierList(
      id: newId(),
      supplierId: supplierId,
      name: nameController.text.trim().isEmpty ? defaultName : nameController.text.trim(),
      imageBase64: imageBase64,
    ));
  }

  Future<void> _viewListImage(BuildContext context, SupplierList list) async {
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(list.name),
              automaticallyImplyLeading: false,
              actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))],
            ),
            Flexible(child: InteractiveViewer(child: Image.memory(base64Decode(list.imageBase64)))),
          ],
        ),
      ),
    );
  }
}
