import 'package:flutter/material.dart';

import '../db/db_helper.dart';
import '../models/product.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final products = await DbHelper.instance.getProducts(search: _search);
    if (!mounted) return;
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  Future<void> _openEditor({Product? product}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductEditorDialog(product: product),
    );
    if (saved == true) _reload();
  }

  Future<void> _confirmDelete(Product product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف المنتج "${product.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DbHelper.instance.deleteProduct(product.id!);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة منتج'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث عن منتج...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                _search = value;
                _reload();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(child: Text('لا توجد منتجات بعد'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: product.isLowStock ? Colors.red.shade100 : Colors.teal.shade100,
                                child: Icon(
                                  Icons.inventory_2,
                                  color: product.isLowStock ? Colors.red : Colors.teal,
                                ),
                              ),
                              title: Text(product.name),
                              subtitle: Text(
                                '${product.category} • الكمية: ${_fmt(product.quantity)} ${product.unit}\n'
                                'شراء: ${_fmt(product.buyPrice)} — بيع: ${_fmt(product.sellPrice)}',
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _openEditor(product: product),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _confirmDelete(product),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

String _fmt(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

class _ProductEditorDialog extends StatefulWidget {
  final Product? product;
  const _ProductEditorDialog({this.product});

  @override
  State<_ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<_ProductEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _buyPrice;
  late final TextEditingController _sellPrice;
  late final TextEditingController _quantity;
  late final TextEditingController _unit;
  late final TextEditingController _lowStock;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _category = TextEditingController(text: p?.category ?? 'عام');
    _buyPrice = TextEditingController(text: p != null ? _fmt(p.buyPrice) : '');
    _sellPrice = TextEditingController(text: p != null ? _fmt(p.sellPrice) : '');
    _quantity = TextEditingController(text: p != null ? _fmt(p.quantity) : '');
    _unit = TextEditingController(text: p?.unit ?? 'قطعة');
    _lowStock = TextEditingController(text: p != null ? _fmt(p.lowStockThreshold) : '5');
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _buyPrice.dispose();
    _sellPrice.dispose();
    _quantity.dispose();
    _unit.dispose();
    _lowStock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final product = Product(
        id: widget.product?.id,
        name: _name.text.trim(),
        category: _category.text.trim().isEmpty ? 'عام' : _category.text.trim(),
        buyPrice: double.parse(_buyPrice.text),
        sellPrice: double.parse(_sellPrice.text),
        quantity: double.parse(_quantity.text),
        unit: _unit.text.trim().isEmpty ? 'قطعة' : _unit.text.trim(),
        lowStockThreshold: double.tryParse(_lowStock.text) ?? 5,
        createdAt: widget.product?.createdAt ?? DateTime.now(),
      );
      await DbHelper.instance.saveProduct(product);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = 'حدث خطأ أثناء الحفظ');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _requiredValidator(String? v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null;

  String? _numberValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'مطلوب';
    if (double.tryParse(v) == null) return 'رقم غير صحيح';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'إضافة منتج' : 'تعديل منتج'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'اسم المنتج'),
                  validator: _requiredValidator,
                ),
                TextFormField(
                  controller: _category,
                  decoration: const InputDecoration(labelText: 'التصنيف'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _buyPrice,
                        decoration: const InputDecoration(labelText: 'سعر الشراء'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _numberValidator,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _sellPrice,
                        decoration: const InputDecoration(labelText: 'سعر البيع'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _numberValidator,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantity,
                        decoration: const InputDecoration(labelText: 'الكمية'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _numberValidator,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _unit,
                        decoration: const InputDecoration(labelText: 'وحدة القياس'),
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _lowStock,
                  decoration: const InputDecoration(labelText: 'حد التنبيه لنفاد المخزون'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
