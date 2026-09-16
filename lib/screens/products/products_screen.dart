import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../data/drug_reference.dart';
import '../../data/id_gen.dart';
import '../../models/operations.dart';
import '../../models/product.dart';
import '../../services/auth_service.dart';
import '../../services/ocr/ocr_service.dart';
import '../../utils/arabic.dart';
import '../../utils/pharmacy_scope.dart';
import '../../widgets/product_thumbnail.dart';
import '../pos/barcode_scanner_screen.dart';
import '../../widgets/sale_shortcut_action.dart';

/// Direct catalog management — add/edit/restock/delete products with a
/// photo, independent of the purchases flow (which only ever *creates*
/// products implicitly). This was the one clearly missing screen: every
/// other flow assumed products already existed.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final auth = context.watch<AuthService>();
    final canEdit = auth.can((p) => p.edit);
    final canViewCost = auth.can((p) => p.viewCost);
    final products = data.products.items
        .where((p) => matchesPharmacy(p.pharmacyId, auth.currentPharmacyId))
        .where((p) =>
            arabicContains(p.name, _search) ||
            (p.nameEn?.toLowerCase().contains(_search.trim().toLowerCase()) ?? false) ||
            (p.barcode?.contains(_search) ?? false))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(title: const Text('المنتجات'), actions: const [SaleShortcutAction()]),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _productDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('إضافة منتج'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'بحث بالاسم أو الباركود',
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text('لا توجد منتجات — أضف واحداً'))
                : ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = products[i];
                      return ListTile(
                        leading: ProductThumbnail(product: p),
                        title: Text(
                          (p.nameEn?.trim().isNotEmpty ?? false) ? '${p.name}  •  ${p.nameEn}' : p.name,
                        ),
                        subtitle: Text(
                          (p.location?.trim().isNotEmpty ?? false)
                              ? '${canViewCost ? 'شراء ${p.purchasePrice.toStringAsFixed(0)} • ' : ''}بيع ${p.salePrice.toStringAsFixed(0)} • 📍 ${p.location}'
                              : '${canViewCost ? 'شراء ${p.purchasePrice.toStringAsFixed(0)} • ' : ''}بيع ${p.salePrice.toStringAsFixed(0)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (p.quantity <= 0)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Chip(
                                  label: Text('نفدت', style: TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: Color(0xFFFCEBEB),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text('${p.quantity} ${p.unit.labelAr}'),
                              ),
                            IconButton(
                              tooltip: 'إضافة كمية (دفعة جديدة)',
                              icon: const Icon(Icons.add_box_outlined),
                              onPressed: canEdit ? () => _restockDialog(context, p) : null,
                            ),
                            if (canEdit) ...[
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _productDialog(context, existing: p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteProduct(context, data, p),
                              ),
                            ],
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

  Future<void> _deleteProduct(BuildContext context, AppData data, Product p) async {
    final hasHistory = data.movements.items.any((m) => m.productId == p.id) ||
        data.sales.items.any((s) => s.items.any((it) => it.productId == p.id)) ||
        data.purchases.items.any((pu) => pu.items.any((it) => it.productId == p.id));

    if (hasHistory) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('لا يمكن الحذف'),
          content: Text(
            'لهذا المنتج سجل مبيعات أو مشتريات سابق — حذفه يخرب أرقام الأرباح والتقارير القديمة.\n'
            'بإمكانك تصفير كميته بدلاً من حذفه (تعديل ← الكمية).',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المنتج؟'),
        content: Text('سيتم حذف "${p.name}" نهائياً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirm == true) {
      for (final b in data.batches.items.where((b) => b.productId == p.id).toList()) {
        await data.batches.delete(b.id);
      }
      await data.products.delete(p.id);
    }
  }

  Future<void> _restockDialog(BuildContext context, Product p) async {
    final data = context.read<AppData>();
    final qty = TextEditingController(text: '1');
    final giftQty = TextEditingController();
    final batchNumber = TextEditingController();
    DateTime? expiry;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('إضافة كمية: ${p.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qty,
                decoration: const InputDecoration(labelText: 'الكمية'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: giftQty,
                decoration: const InputDecoration(
                  labelText: 'كمية الهدية (اختياري)',
                  helperText: 'وحدات إضافية مجانية من المورد — تنضاف للمخزون بدون كلفة',
                  prefixIcon: Icon(Icons.card_giftcard_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: batchNumber,
                decoration: const InputDecoration(labelText: 'رقم الدفعة (اختياري)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: expiry ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => expiry = picked);
                },
                child: Text(expiry == null
                    ? 'تاريخ الإكسباير (اختياري)'
                    : '${expiry!.year}/${expiry!.month}/${expiry!.day}'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final v = int.tryParse(qty.text) ?? 0;
                final gift = int.tryParse(giftQty.text) ?? 0;
                if (v <= 0 && gift <= 0) return;
                final total = v + gift;
                await data.batches.upsert(Batch(
                  id: newId(),
                  productId: p.id,
                  quantity: total,
                  batchNumber: batchNumber.text.trim().isEmpty ? null : batchNumber.text.trim(),
                  expiryDate: expiry,
                ));
                await data.products.upsert(p.copyWith(quantity: p.quantity + total));
                await data.movements.upsert(StockMovement(
                  id: newId(),
                  productId: p.id,
                  name: p.name,
                  type: StockMovementType.stockIn,
                  quantity: total,
                  note: gift > 0 ? 'إضافة كمية يدوية (منها $gift هدية)' : 'إضافة كمية يدوية',
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

  Future<void> _productDialog(BuildContext context, {Product? existing}) async {
    final data = context.read<AppData>();
    final name = TextEditingController(text: existing?.name ?? '');
    final nameEn = TextEditingController(text: existing?.nameEn ?? '');
    final barcode = TextEditingController(text: existing?.barcode ?? '');
    final location = TextEditingController(text: existing?.location ?? '');
    final treats = TextEditingController(text: existing?.treats ?? '');
    String? shelfId = existing?.shelfId;
    final purchasePrice = TextEditingController(text: existing?.purchasePrice.toStringAsFixed(0) ?? '');
    final salePrice = TextEditingController(text: existing?.salePrice.toStringAsFixed(0) ?? '');
    final lowStock = TextEditingController(text: '${existing?.lowStockThreshold ?? 10}');
    final expiryDays = TextEditingController(text: '${existing?.expiryAlertDays ?? 60}');
    final initialQty = TextEditingController(text: '0');
    final initialGiftQty = TextEditingController();
    final batchNumber = TextEditingController();
    DateTime? initialExpiry;
    ProductUnit unit = existing?.unit ?? ProductUnit.piece;
    String? supplierId = existing?.supplierId;
    String? imageBase64 = existing?.image;
    bool ocrRunning = false;

    /// Best-effort: tries to fill in whatever's still empty from the
    /// product's own photo (name/English name, then the drug-database
    /// match for "treats") — never overwrites something already typed,
    /// since the photo's guess is a starting point, not an override.
    Future<void> runOcr(String imagePath, void Function(void Function()) setState) async {
      if (!OcrService.isSupported) return;
      setState(() => ocrRunning = true);
      final text = await OcrService.recognizeRawText(imagePath);
      final guess = text == null ? null : guessProductName(text);
      setState(() {
        ocrRunning = false;
        if (guess != null && guess.isNotEmpty) {
          if (name.text.trim().isEmpty) name.text = guess;
          if (nameEn.text.trim().isEmpty) nameEn.text = guess;
          if (treats.text.trim().isEmpty) {
            final q = guess.toLowerCase();
            final match = drugDatabase.where((d) =>
                d.nameEn.toLowerCase().contains(q) ||
                q.contains(d.nameEn.toLowerCase().split(' ').first.split('(').first));
            if (match.isNotEmpty) treats.text = match.first.treatsAr;
          }
        }
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(guess == null
            ? 'ما تكدر تقرأ الكتابة بالصورة بوضوح — أدخل الاسم يدوياً'
            : 'تم التعرف على الاسم من الصورة — راجعه قبل الحفظ'),
      ));
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'إضافة منتج' : 'تعديل منتج'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: () async {
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
                        final picker = ImagePicker();
                        // Higher resolution than before (was 480/70) since
                        // this photo now also feeds OCR below — a label's
                        // print is often too small to read reliably at the
                        // old size.
                        final file = await picker.pickImage(
                          source: source,
                          maxWidth: 900,
                          imageQuality: 80,
                        );
                        if (file == null) return;
                        final bytes = await file.readAsBytes();
                        setState(() => imageBase64 = base64Encode(bytes));
                        await runOcr(file.path, setState);
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundImage:
                                imageBase64 != null ? MemoryImage(base64Decode(imageBase64!)) : null,
                            child: imageBase64 == null
                                ? const Icon(Icons.add_a_photo_outlined, size: 28)
                                : null,
                          ),
                          if (ocrRunning)
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.45),
                              ),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (OcrService.isSupported)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'تصوير المادة يحاول يقرأ اسمها تلقائياً من الصورة',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المادة (عربي)')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameEn,
                    decoration: const InputDecoration(labelText: 'الاسم بالإنكليزي (اختياري)'),
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: treats,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'الأمراض/الحالات اللي يعالجها (اختياري)',
                      helperText: 'مساعد سريع، مو مرجع طبي نهائي — راجعها قبل الاعتماد عليها',
                      suffixIcon: IconButton(
                        tooltip: 'عبّي تلقائياً من قاعدة الأدوية الشائعة',
                        icon: const Icon(Icons.auto_awesome),
                        onPressed: () {
                          final query = (nameEn.text.trim().isNotEmpty ? nameEn.text : name.text).trim();
                          if (query.isEmpty) return;
                          final q = query.toLowerCase();
                          final match = drugDatabase.where((d) =>
                              d.nameEn.toLowerCase().contains(q) ||
                              q.contains(d.nameEn.toLowerCase().split(' ').first.split('(').first) ||
                              arabicContains(d.nameAr, name.text));
                          if (match.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ما لكيت هذا الدواء بقاعدة البيانات المحلية — أكتبها يدوياً')),
                            );
                            return;
                          }
                          setState(() => treats.text = match.first.treatsAr);
                        },
                      ),
                    ),
                  ),
                  TextField(
                    controller: barcode,
                    decoration: InputDecoration(
                      labelText: 'الباركود',
                      helperText: existing == null
                          ? 'امسح باركود المادة — إذا كانت مسجّلة عندك تُملأ بياناتها تلقائياً'
                          : null,
                      suffixIcon: (kIsWeb ||
                              defaultTargetPlatform == TargetPlatform.android ||
                              defaultTargetPlatform == TargetPlatform.iOS)
                          ? IconButton(
                              tooltip: 'مسح بالكاميرا',
                              icon: const Icon(Icons.camera_alt_outlined),
                              onPressed: () async {
                                final code = await Navigator.of(context).push<String>(
                                  MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
                                );
                                if (code == null) return;
                                barcode.text = code;
                                if (existing != null) return;
                                final match = data.products.items.where((p) => p.barcode == code);
                                if (match.isEmpty) return;
                                final found = match.first;
                                setState(() {
                                  name.text = found.name;
                                  nameEn.text = found.nameEn ?? '';
                                  purchasePrice.text = found.purchasePrice.toStringAsFixed(0);
                                  salePrice.text = found.salePrice.toStringAsFixed(0);
                                  lowStock.text = '${found.lowStockThreshold}';
                                  expiryDays.text = '${found.expiryAlertDays}';
                                  unit = found.unit;
                                  supplierId = found.supplierId;
                                  imageBase64 = found.image;
                                  location.text = found.location ?? '';
                                  shelfId = found.shelfId;
                                  treats.text = found.treats ?? '';
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('تم العثور على "${found.name}" — تم تعبئة بياناتها، أضف الكمية الجديدة')),
                                );
                              },
                            )
                          : null,
                    ),
                    onSubmitted: existing != null
                        ? null
                        : (value) {
                            final match = data.products.items.where((p) => p.barcode == value.trim());
                            if (match.isEmpty) return;
                            final found = match.first;
                            setState(() {
                              name.text = found.name;
                              nameEn.text = found.nameEn ?? '';
                              purchasePrice.text = found.purchasePrice.toStringAsFixed(0);
                              salePrice.text = found.salePrice.toStringAsFixed(0);
                              lowStock.text = '${found.lowStockThreshold}';
                              expiryDays.text = '${found.expiryAlertDays}';
                              unit = found.unit;
                              supplierId = found.supplierId;
                              imageBase64 = found.image;
                              location.text = found.location ?? '';
                              shelfId = found.shelfId;
                              treats.text = found.treats ?? '';
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('تم العثور على "${found.name}" — تم تعبئة بياناتها، أضف الكمية الجديدة')),
                            );
                          },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: location,
                    decoration: const InputDecoration(
                      labelText: 'مكان المادة بالصيدلية (اختياري)',
                      helperText: 'مثال: رف 3 - قسم الأدوية الباردة (الرقم يحدد مكانها بخارطة الصيدلية)',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: purchasePrice,
                          decoration: const InputDecoration(labelText: 'سعر الشراء'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: salePrice,
                          decoration: const InputDecoration(labelText: 'سعر البيع'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ProductUnit>(
                    value: unit,
                    decoration: const InputDecoration(labelText: 'الوحدة'),
                    items: ProductUnit.values
                        .map((u) => DropdownMenuItem(value: u, child: Text(u.labelAr)))
                        .toList(),
                    onChanged: (v) => setState(() => unit = v ?? unit),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: supplierId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'المورد (اختياري)'),
                    items: data.suppliers.items
                        .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                        .toList(),
                    onChanged: (v) => setState(() => supplierId = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: lowStock,
                          decoration: const InputDecoration(labelText: 'حد التنبيه للنفاد'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: expiryDays,
                          decoration: const InputDecoration(labelText: 'تنبيه الإكسباير (يوم)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  if (existing == null) ...[
                    const Divider(),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text('الدفعة الأولى (اختياري)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: initialQty,
                            decoration: const InputDecoration(labelText: 'الكمية'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: initialGiftQty,
                            decoration: const InputDecoration(labelText: 'كمية الهدية'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: batchNumber,
                            decoration: const InputDecoration(labelText: 'رقم الدفعة'),
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initialExpiry ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => initialExpiry = picked);
                      },
                      child: Text(initialExpiry == null
                          ? 'تاريخ الإكسباير'
                          : '${initialExpiry!.year}/${initialExpiry!.month}/${initialExpiry!.day}'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final enteredQty = int.tryParse(initialQty.text) ?? 0;
                final giftQty = int.tryParse(initialGiftQty.text) ?? 0;
                final qty = enteredQty + giftQty;

                final product = Product(
                  id: existing?.id ?? newId(),
                  name: name.text.trim(),
                  nameEn: nameEn.text.trim().isEmpty ? null : nameEn.text.trim(),
                  barcode: barcode.text.trim().isEmpty ? null : barcode.text.trim(),
                  location: location.text.trim().isEmpty ? null : location.text.trim(),
                  treats: treats.text.trim().isEmpty ? null : treats.text.trim(),
                  shelfId: shelfId,
                  purchasePrice: double.tryParse(purchasePrice.text) ?? 0,
                  salePrice: double.tryParse(salePrice.text) ?? 0,
                  unit: unit,
                  quantity: existing?.quantity ?? (qty > 0 ? qty : 0),
                  lowStockThreshold: int.tryParse(lowStock.text) ?? 10,
                  expiryAlertDays: int.tryParse(expiryDays.text) ?? 60,
                  supplierId: supplierId,
                  pharmacyId: existing?.pharmacyId ?? context.read<AuthService>().currentPharmacyId,
                  image: imageBase64,
                );
                await data.products.upsert(product);

                if (existing == null && qty > 0) {
                  await data.batches.upsert(Batch(
                    id: newId(),
                    productId: product.id,
                    quantity: qty,
                    batchNumber: batchNumber.text.trim().isEmpty ? null : batchNumber.text.trim(),
                    expiryDate: initialExpiry,
                  ));
                  await data.movements.upsert(StockMovement(
                    id: newId(),
                    productId: product.id,
                    name: product.name,
                    type: StockMovementType.stockIn,
                    quantity: qty,
                    note: giftQty > 0 ? 'رصيد افتتاحي (منها $giftQty هدية)' : 'رصيد افتتاحي',
                  ));
                }

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
