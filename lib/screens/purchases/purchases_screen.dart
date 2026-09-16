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
import '../../services/ocr/ocr_service.dart';
import '../../widgets/sale_shortcut_action.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _DraftLine {
  _DraftLine({required this.name, this.quantity = 1, this.unitCost = 0, this.expiryDate})
      : nameController = TextEditingController(text: name),
        costController = TextEditingController(text: unitCost == 0 ? '' : unitCost.toStringAsFixed(0));
  String name;
  int quantity;
  double unitCost;
  DateTime? expiryDate;
  final TextEditingController nameController;
  final TextEditingController costController;
  /// Set once the typed name matches an existing product — used to show
  /// its current stock/price right away instead of only merging silently
  /// at save time.
  Product? matched;
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  String? _supplierId;
  String? _repId;
  DateTime _purchaseDate = DateTime.now();
  String? _receiptImagePath;
  final List<_DraftLine> _lines = [];
  double _paidAmount = 0;
  bool _processingOcr = false;
  String? _rawOcrText;

  Future<void> _captureReceipt(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      setState(() {
        _receiptImagePath = file.path;
        _processingOcr = OcrService.isSupported;
      });

      if (!OcrService.isSupported) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'استخراج البيانات آلياً (OCR) متاح على أندرويد و iOS فقط — أدخل بيانات القسيمة يدوياً بالأسفل.'),
        ));
        return;
      }

      final ocr = await OcrService.recognizeReceipt(file.path);
      if (!mounted) return;
      setState(() {
        _processingOcr = false;
        if (ocr != null) {
          _rawOcrText = ocr.rawText;
          for (final l in ocr.lines) {
            _lines.add(_DraftLine(name: l.name, quantity: l.quantity, unitCost: l.unitCost));
          }
        }
      });
      if (ocr == null || ocr.lines.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذّر استخراج بيانات واضحة — راجع/أدخل السطور يدوياً.'),
        ));
      }
    } catch (e) {
      setState(() => _processingOcr = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر التقاط الصورة: $e')),
      );
    }
  }

  /// A separate, simpler flow from the OCR receipt capture above: just
  /// snap the supplier's invoice and file it under that supplier
  /// automatically (same photo library used by "القائمة" on the
  /// supplier's own page) — no line-item extraction, just a filed photo.
  Future<void> _captureInvoicePhoto(BuildContext context) async {
    final supplierId = _supplierId;
    if (supplierId == null) return;
    final data = context.read<AppData>();
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('التقاط صورة الفاتورة'),
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

    final now = DateTime.now();
    await data.supplierLists.upsert(SupplierList(
      id: newId(),
      supplierId: supplierId,
      name: 'فاتورة ${now.year}/${now.month}/${now.day}',
      imageBase64: base64Encode(bytes),
    ));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('انحفظت صورة الفاتورة تحت هذا المورد')),
    );
  }

  void _addEmptyLine() {
    setState(() => _lines.add(_DraftLine(name: '')));
  }

  double get _total => _lines.fold(0.0, (s, l) => s + (l.quantity * l.unitCost));

  Future<void> _save() async {
    final data = context.read<AppData>();
    if (_supplierId == null || _lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المورد وأضف مادة واحدة على الأقل')),
      );
      return;
    }

    final items = <PurchaseItem>[];
    for (final line in _lines) {
      if (line.name.trim().isEmpty || line.quantity <= 0) continue;

      final matches = data.products.items.where(
        (p) => p.name.trim().toLowerCase() == line.name.trim().toLowerCase(),
      );
      Product product;
      if (matches.isNotEmpty) {
        product = matches.first;
        await data.products.upsert(product.copyWith(
          quantity: product.quantity + line.quantity,
          purchasePrice: line.unitCost,
          supplierId: product.supplierId ?? _supplierId,
        ));
      } else {
        product = Product(
          id: newId(),
          name: line.name.trim(),
          purchasePrice: line.unitCost,
          salePrice: (line.unitCost * 1.2).roundToDouble(),
          quantity: line.quantity,
          supplierId: _supplierId,
        );
        await data.products.upsert(product);
      }

      await data.batches.upsert(Batch(
        id: newId(),
        productId: product.id,
        quantity: line.quantity,
        expiryDate: line.expiryDate,
      ));

      await data.movements.upsert(StockMovement(
        id: newId(),
        productId: product.id,
        name: product.name,
        type: StockMovementType.stockIn,
        quantity: line.quantity,
        note: 'شراء من مورد',
      ));

      items.add(PurchaseItem(
        productId: product.id,
        name: product.name,
        quantity: line.quantity,
        unitCost: line.unitCost,
        expiryDate: line.expiryDate,
      ));
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد سطور صالحة للحفظ')),
      );
      return;
    }

    await data.purchases.upsert(Purchase(
      id: newId(),
      supplierId: _supplierId!,
      repId: _repId,
      items: items,
      paidAmount: _paidAmount,
      receiptImagePath: _receiptImagePath,
      purchaseDate: _purchaseDate,
    ));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم حفظ فاتورة الشراء — الإجمالي ${_total.toStringAsFixed(0)} د.ع')),
    );
    setState(() {
      _lines.clear();
      _receiptImagePath = null;
      _rawOcrText = null;
      _paidAmount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final reps = data.reps.items.where((r) => r.supplierId == _supplierId).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('المشتريات وقسائم المندوبين'), actions: const [SaleShortcutAction()]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('التقاط قسيمة الشراء (OCR)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _processingOcr
                              ? null
                              : () => _captureReceipt(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('التقاط صورة'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _processingOcr
                              ? null
                              : () => _captureReceipt(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('اختيار من الملفات'),
                        ),
                        if (_processingOcr)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                    if (_receiptImagePath != null) ...[
                      const SizedBox(height: 8),
                      Text('الصورة: $_receiptImagePath',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF4A4A4A), fontWeight: FontWeight.w600)),
                    ],
                    if (_rawOcrText != null) ...[
                      const SizedBox(height: 8),
                      ExpansionTile(
                        title: const Text('النص المستخرج من الصورة',
                            style: TextStyle(fontSize: 13)),
                        childrenPadding: const EdgeInsets.all(8),
                        children: [
                          Text(_rawOcrText!, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                    if (!OcrService.isSupported) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'الاستخراج الآلي (OCR) مفعّل على أندرويد و iOS. على ويندوز/الويب أدخل السطور يدوياً بعد إرفاق الصورة.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('بيانات فاتورة الشراء',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _supplierId,
                            decoration: const InputDecoration(labelText: 'المورد / المذخر'),
                            items: data.suppliers.items
                                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                                .toList(),
                            onChanged: (v) => setState(() {
                              _supplierId = v;
                              _repId = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _repId,
                            decoration: const InputDecoration(labelText: 'المندوب (اختياري)'),
                            items: reps
                                .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                                .toList(),
                            onChanged: (v) => setState(() => _repId = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _supplierId == null ? null : () => _captureInvoicePhoto(context),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('الفاتورة'),
                        ),
                        if (_supplierId == null) ...[
                          const SizedBox(width: 8),
                          const Text('اختر المورد أول', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.date_range_outlined),
                            label: Text(
                                'تاريخ الشراء: ${_purchaseDate.year}/${_purchaseDate.month}/${_purchaseDate.day}'),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _purchaseDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) setState(() => _purchaseDate = picked);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(labelText: 'المبلغ المدفوع الآن'),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => _paidAmount = double.tryParse(v) ?? 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المواد', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _addEmptyLine,
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة مادة'),
                        ),
                      ],
                    ),
                    ..._lines.asMap().entries.map((e) => _buildLine(e.key, e.value)),
                    if (_lines.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('لا توجد مواد بعد — التقط قسيمة أو أضف يدوياً'),
                      ),
                    const Divider(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('الإجمالي: ${_total.toStringAsFixed(0)} د.ع',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ فاتورة الشراء'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLine(int index, _DraftLine line) {
    final data = context.read<AppData>();
    return Padding(
      key: ValueKey(line),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Autocomplete<Product>(
                  displayStringForOption: (p) => p.name,
                  initialValue: TextEditingValue(text: line.name),
                  optionsBuilder: (textValue) {
                    final q = textValue.text.trim().toLowerCase();
                    if (q.isEmpty) return const Iterable<Product>.empty();
                    return data.products.items.where((p) => p.name.toLowerCase().contains(q)).take(20);
                  },
                  onSelected: (p) {
                    setState(() {
                      line.name = p.name;
                      line.matched = p;
                      line.costController.text = p.purchasePrice.toStringAsFixed(0);
                      line.unitCost = p.purchasePrice;
                    });
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(labelText: 'اسم المادة', isDense: true),
                      onChanged: (v) {
                        line.name = v;
                        final match = data.products.items.where(
                          (p) => p.name.trim().toLowerCase() == v.trim().toLowerCase(),
                        );
                        setState(() {
                          if (match.isNotEmpty) {
                            line.matched = match.first;
                            if (line.costController.text.trim().isEmpty) {
                              line.costController.text = match.first.purchasePrice.toStringAsFixed(0);
                              line.unitCost = match.first.purchasePrice;
                            }
                          } else {
                            line.matched = null;
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: line.quantity.toString(),
                  decoration: const InputDecoration(labelText: 'الكمية الجديدة', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => line.quantity = int.tryParse(v) ?? line.quantity,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: line.costController,
                  decoration: const InputDecoration(labelText: 'سعر الشراء', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => line.unitCost = double.tryParse(v) ?? line.unitCost,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 130,
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: line.expiryDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => line.expiryDate = picked);
                  },
                  child: Text(
                    line.expiryDate == null
                        ? 'تاريخ الإكسباير'
                        : '${line.expiryDate!.year}/${line.expiryDate!.month}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => setState(() => _lines.removeAt(index)),
              ),
            ],
          ),
          if (line.matched != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Text(
                'مادة موجودة — المخزون الحالي: ${line.matched!.quantity} ${line.matched!.unit.labelAr} • '
                'الكمية الجديدة تنضاف فوك الموجود',
                style: const TextStyle(fontSize: 11, color: Color(0xFF0B6B4F), fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
