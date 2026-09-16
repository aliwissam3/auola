import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../data/drug_reference.dart';
import '../../data/id_gen.dart';
import '../../models/operations.dart';
import '../../models/people.dart';
import '../../models/product.dart';
import '../../models/sales.dart';
import '../../services/auth_service.dart';
import '../../services/pos_cart_service.dart';
import '../../utils/arabic.dart';
import '../../utils/pharmacy_scope.dart';
import '../../widgets/product_thumbnail.dart';
import '../dashboard/dashboard_screen.dart'
    show dashboardCardCatalog, dashboardCardIcons, dashboardCardRoutes;
import '../returns/customer_returns_screen.dart';
import 'barcode_scanner_screen.dart';
import 'cart_tab.dart';
import 'substitute_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _search = TextEditingController();
  String _query = '';
  final _searchFocus = FocusNode();

  /// Quick-switch buttons to other app sections, configured from
  /// Settings — lets whoever's on the register jump straight to e.g.
  /// "الديون" or "التقارير" without backing out to the dashboard first.
  /// Filtered by the logged-in employee's own permissions, same as the
  /// dashboard's own cards, so a shortcut an admin picked never opens a
  /// screen this particular employee isn't allowed into.
  Widget _buildShortcutsRow(BuildContext context, AppData data) {
    final auth = context.watch<AuthService>();
    final catalogById = {for (final (id, label) in dashboardCardCatalog) id: label};
    final ids = data.sectionShortcuts.items
        .map((s) => s.id)
        .where((id) => catalogById.containsKey(id))
        .where((id) => _canOpenSection(auth, id))
        .toList();
    if (ids.isEmpty) {
      // Nothing configured yet - only the admin can do anything about
      // that, so only they see a pointer to where ("الإعدادات") rather
      // than every employee wondering why this row is just missing.
      if (!auth.isAdmin) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'ما فيه اختصارات بعد — أضفها من الإعدادات > اختصارات شاشة البيع',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: ids.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final id = ids[i];
            final route = dashboardCardRoutes[id];
            return ActionChip(
              avatar: Icon(dashboardCardIcons[id], size: 16),
              label: Text(catalogById[id]!),
              onPressed: route == null ? null : () => Navigator.pushNamed(context, route),
            );
          },
        ),
      ),
    );
  }

  bool _canOpenSection(AuthService auth, String id) {
    switch (id) {
      case 'debts':
        return auth.can((p) => p.debts);
      case 'lists':
        return auth.can((p) => p.lists);
      case 'reports':
        return auth.can((p) => p.reports);
      default:
        return true;
    }
  }

  void _pickProduct(PosCartService pos, Product p) {
    pos.current.addProduct(p);
    pos.touch();
    _search.clear();
    setState(() => _query = '');
    _searchFocus.requestFocus();
  }

  void _onBarcodeSubmit(PosCartService pos, String value) {
    final code = value.trim();
    if (code.isEmpty) return;
    final data = context.read<AppData>();
    final auth = context.read<AuthService>();
    final match = data.products.items
        .where((p) => p.barcode == code)
        .where((p) => matchesPharmacy(p.pharmacyId, auth.currentPharmacyId));
    if (match.isNotEmpty) {
      _pickProduct(pos, match.first);
    } else {
      _search.clear();
      setState(() => _query = '');
      _quickAddUnknownBarcode(pos, code);
    }
  }

  /// Opens the camera scanner (phones only) and feeds whatever it reads
  /// through the exact same path a physical USB scanner's Enter key
  /// would — same unknown-barcode quick-add flow, same everything.
  Future<void> _scanWithCamera(PosCartService pos) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;
    _onBarcodeSubmit(pos, code);
  }

  /// Opens a dialog to search for medicines by disease/condition instead
  /// of by name — matches against each product's own `treats` field
  /// first (what's actually tagged on your inventory), and separately
  /// suggests matching generics from the built-in drug reference so
  /// staff know what class of medicine to look for even if it isn't
  /// tagged yet.
  Future<void> _searchByDisease(PosCartService pos) async {
    final controller = TextEditingController();
    final data = context.read<AppData>();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final q = controller.text.trim();
          final inStock = q.isEmpty
              ? const <Product>[]
              : data.products.items
                  .where((p) => (p.treats?.isNotEmpty ?? false) && arabicContains(p.treats!, q))
                  .toList();
          final referenceMatches = q.isEmpty
              ? const <DrugReference>[]
              : drugDatabase.where((d) => arabicContains(d.treatsAr, q)).take(10).toList();
          return AlertDialog(
            title: const Text('بحث بالمرض أو الحالة'),
            content: SizedBox(
              width: 420,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'اكتب اسم المرض أو الحالة (مثال: صداع، ضغط، سكري)',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: q.isEmpty
                        ? const Center(child: Text('اكتب حتى يبدأ البحث', style: TextStyle(color: Colors.grey)))
                        : ListView(
                            children: [
                              if (inStock.isNotEmpty) ...[
                                const Align(
                                  alignment: Alignment.centerRight,
                                  child: Text('موجود بمخزونك', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                for (final p in inStock)
                                  ListTile(
                                    dense: true,
                                    leading: ProductThumbnail(product: p, radius: 16),
                                    title: Text(p.name),
                                    subtitle: Text(p.treats!, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    trailing: Text('${p.salePrice.toStringAsFixed(0)} د.ع'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _pickProduct(pos, p);
                                    },
                                  ),
                              ],
                              if (referenceMatches.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Align(
                                  alignment: Alignment.centerRight,
                                  child: Text('أدوية شائعة تعالج هذه الحالة (راجع إذا متوفرة عندك)',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                for (final d in referenceMatches)
                                  ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.medication_outlined),
                                    title: Text(d.nameAr),
                                    subtitle: Text('${d.nameEn} — ${d.treatsAr}',
                                        maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ),
                              ],
                              if (inStock.isEmpty && referenceMatches.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('ما لكيت نتائج مطابقة', style: TextStyle(color: Colors.grey)),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
          );
        },
      ),
    );
  }

  /// A barcode was scanned/typed but no product has it registered yet.
  /// Rather than just complaining and losing the scan, open a fast
  /// add-product form pre-filled with the scanned barcode so staff can
  /// fill in the name/price on the spot and the item goes straight into
  /// the cart — no need to leave the POS screen and use "المنتجات".
  Future<void> _quickAddUnknownBarcode(PosCartService pos, String code) async {
    final data = context.read<AppData>();
    final name = TextEditingController();
    final nameEn = TextEditingController();
    final salePrice = TextEditingController();
    final purchasePrice = TextEditingController();
    final qty = TextEditingController(text: '1');

    final product = await showDialog<Product>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('مادة جديدة — باركود غير مسجّل'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الباركود: $code', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'اسم المادة (عربي)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameEn,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'الاسم بالإنكليزي (اختياري)'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: purchasePrice,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'سعر الشراء'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: salePrice,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'سعر البيع'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الكمية المتوفرة الآن'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(
                  ctx,
                  Product(
                    id: newId(),
                    name: name.text.trim(),
                    nameEn: nameEn.text.trim().isEmpty ? null : nameEn.text.trim(),
                    barcode: code,
                    purchasePrice: double.tryParse(purchasePrice.text) ?? 0,
                    salePrice: double.tryParse(salePrice.text) ?? 0,
                    quantity: int.tryParse(qty.text) ?? 0,
                    pharmacyId: context.read<AuthService>().currentPharmacyId,
                  ),
                );
              },
              child: const Text('إضافة وبيع'),
            ),
          ],
        ),
      ),
    );

    if (product == null || !mounted) return;
    await data.products.upsert(product);
    if (product.quantity > 0) {
      await data.batches.upsert(Batch(id: newId(), productId: product.id, quantity: product.quantity));
    }
    if (!mounted) return;
    _pickProduct(pos, product);
  }

  Future<void> _checkout(PosCartService pos) async {
    final cart = pos.current;
    if (cart.items.isEmpty) return;
    final data = context.read<AppData>();
    final auth = context.read<AuthService>();

    // An insufficient-stock line blocks the *whole* sale rather than
    // silently clamping the shortfall to zero.
    final shortages = <String>[];
    for (final item in cart.items) {
      final product = data.products.byId(item.productId);
      if (product == null) continue;
      if (item.quantity > product.quantity) {
        shortages.add(
          '${product.name}: متوفر ${product.quantity}، مطلوب ${item.quantity.toStringAsFixed(0)}',
        );
      }
    }
    if (shortages.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('الكمية غير كافية'),
          content: Text('لا يمكن إتمام البيع:\n${shortages.join('\n')}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
          ],
        ),
      );
      return;
    }

    if (cart.paymentType == PaymentType.credit) {
      if (cart.customerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اختر المراجع لإتمام البيع بالدين')),
        );
        return;
      }
      final customer = data.customers.byId(cart.customerId!);
      if (customer != null && customer.locked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حساب ${customer.name} مقفل — لا يمكن البيع بالدين')),
        );
        return;
      }
      if (customer != null && customer.creditLimit > 0) {
        final currentBalance = data.customerBalance(customer.id);
        if (currentBalance + cart.total > customer.creditLimit) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('تجاوز سقف الدين'),
              content: Text(
                  'رصيد ${customer.name} الحالي ${currentBalance.toStringAsFixed(0)} د.ع وسيتجاوز السقف المسموح ${customer.creditLimit.toStringAsFixed(0)} د.ع. المتابعة؟'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('متابعة')),
              ],
            ),
          );
          if (!mounted || proceed != true) return;
        }
      }
    }

    final invoice = SaleInvoice(
      id: newId(),
      employeeId: auth.currentEmployee?.id ?? '',
      items: List.of(cart.items),
      customerId: cart.customerId,
      paymentType: cart.paymentType,
      paidAmount: cart.paymentType == PaymentType.credit
          ? cart.paidAmount
          : cart.total,
      notes: cart.notes,
      substituteNote: cart.substituteNote,
    );

    for (final item in cart.items) {
      final product = data.products.byId(item.productId);
      if (product == null) continue;

      // FEFO (first-expiry-first-out): consume from the soonest-to-expire
      // batches first (no-expiry batches last), so the near-expiry stock
      // shown on the Expiry screen actually goes down as it's sold.
      // Stock that predates batch tracking (e.g. no batch ever recorded)
      // has nothing to deduct from here and is covered by the direct
      // product.quantity reduction below either way.
      var remaining = item.quantity.round();
      final batches = data.batches.items
          .where((b) => b.productId == product.id && b.quantity > 0)
          .toList()
        ..sort((a, b) {
          if (a.expiryDate == null && b.expiryDate == null) return 0;
          if (a.expiryDate == null) return 1;
          if (b.expiryDate == null) return -1;
          return a.expiryDate!.compareTo(b.expiryDate!);
        });
      for (final batch in batches) {
        if (remaining <= 0) break;
        final take = remaining < batch.quantity ? remaining : batch.quantity;
        await data.batches.upsert(batch.copyWith(quantity: batch.quantity - take));
        remaining -= take;
      }

      final newQty = product.quantity - item.quantity.round();
      await data.products.upsert(product.copyWith(quantity: newQty < 0 ? 0 : newQty));
      await data.movements.upsert(StockMovement(
        id: newId(),
        productId: product.id,
        name: product.name,
        type: StockMovementType.stockOut,
        quantity: item.quantity.round(),
        note: 'بيع — فاتورة ${invoice.id}',
      ));
    }

    await data.sales.upsert(invoice);

    pos.replaceCurrent(CartTab(id: newId(), name: cart.name));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم إتمام البيع — الإجمالي ${invoice.total.toStringAsFixed(0)} د.ع'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Ranks products by total units sold across all sale history — used to
  /// surface "الأكثر مبيعاً" as one-tap quick picks before the cashier
  /// types anything, since a handful of items make up most day-to-day
  /// sales in a pharmacy (paracetamol, saline, etc).
  /// All of this pharmacy's products, sold-the-most first — so the
  /// browsable grid on the POS screen shows *everything* (not just a
  /// top-12 of previously-sold items), while still surfacing the
  /// familiar staples at the top for one-tap access.
  List<Product> _browsableProducts(AppData data, AuthService auth) {
    final soldQty = <String, double>{};
    for (final sale in data.sales.items) {
      for (final item in sale.items) {
        soldQty[item.productId] = (soldQty[item.productId] ?? 0) + item.quantity;
      }
    }
    final products = data.products.items
        .where((p) => matchesPharmacy(p.pharmacyId, auth.currentPharmacyId))
        .toList()
      ..sort((a, b) {
        final diff = (soldQty[b.id] ?? 0).compareTo(soldQty[a.id] ?? 0);
        if (diff != 0) return diff;
        return a.name.compareTo(b.name);
      });
    return products;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final auth = context.watch<AuthService>();
    final pos = context.watch<PosCartService>();
    final results = _query.trim().isEmpty
        ? const <Product>[]
        : data.products.items
            .where((p) => matchesPharmacy(p.pharmacyId, auth.currentPharmacyId))
            .where((p) =>
                arabicContains(p.name, _query) ||
                (p.nameEn?.toLowerCase().contains(_query.trim().toLowerCase()) ?? false) ||
                (p.barcode?.contains(_query) ?? false))
            .take(20)
            .toList();
    final browsableProducts = _browsableProducts(data, auth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('نقطة البيع'),
        actions: [
          IconButton(
            tooltip: 'مرتجع زبون',
            icon: const Icon(Icons.assignment_return_outlined),
            onPressed: () => showCustomerReturnDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(pos),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildShortcutsRow(context, data),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: _search,
                          focusNode: _searchFocus,
                          autofocus: true,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.qr_code_scanner),
                            labelText: 'باركود أو اسم المادة',
                            suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'بحث بالمرض/الحالة',
                                  icon: const Icon(Icons.medical_services_outlined),
                                  onPressed: () => _searchByDisease(pos),
                                ),
                                if (kIsWeb ||
                                    defaultTargetPlatform == TargetPlatform.android ||
                                    defaultTargetPlatform == TargetPlatform.iOS)
                                  IconButton(
                                    tooltip: 'مسح بالكاميرا',
                                    icon: const Icon(Icons.camera_alt_outlined),
                                    onPressed: () => _scanWithCamera(pos),
                                  ),
                              ],
                            ),
                          ),
                          onChanged: (v) => setState(() => _query = v),
                          onSubmitted: (v) => _onBarcodeSubmit(pos, v),
                        ),
                      ),
                      if (results.isNotEmpty)
                        SizedBox(
                          height: 160,
                          child: ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (_, i) {
                              final p = results[i];
                              return ListTile(
                                dense: true,
                                leading: ProductThumbnail(product: p, radius: 18),
                                title: Text(
                                  (p.nameEn?.trim().isNotEmpty ?? false) ? '${p.name}  •  ${p.nameEn}' : p.name,
                                ),
                                subtitle: Text(
                                  (p.location?.trim().isNotEmpty ?? false)
                                      ? 'مخزون: ${p.quantity} ${p.unit.labelAr} • ${p.salePrice.toStringAsFixed(0)} د.ع • 📍 ${p.location}'
                                      : 'مخزون: ${p.quantity} ${p.unit.labelAr} • ${p.salePrice.toStringAsFixed(0)} د.ع',
                                ),
                                onTap: () => _pickProduct(pos, p),
                              );
                            },
                          ),
                        )
                      else if (browsableProducts.isNotEmpty)
                        Expanded(
                          child: _BestSellersGrid(products: browsableProducts, onTap: (p) => _pickProduct(pos, p)),
                        ),
                      const Divider(height: 1),
                      Expanded(child: _buildCartItems(pos)),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(flex: 2, child: _buildPaymentPanel(data, pos, auth)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(PosCartService pos) {
    return Container(
      height: 48,
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: pos.carts.length,
              itemBuilder: (_, i) {
                final selected = i == pos.active;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: InputChip(
                    label: Text(pos.carts[i].name),
                    selected: selected,
                    onSelected: (_) => pos.setActive(i),
                    onDeleted: pos.carts.length > 1 ? () => pos.closeCart(i) : null,
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'فاتورة جديدة',
            icon: const Icon(Icons.add_box_outlined),
            onPressed: pos.addCart,
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems(PosCartService pos) {
    final cart = pos.current;
    final data = context.read<AppData>();
    if (cart.items.isEmpty) {
      return const Center(child: Text('السلة فارغة — ابحث عن مادة لإضافتها'));
    }
    return ListView.separated(
      itemCount: cart.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final item = cart.items[i];
        final location = data.products.byId(item.productId)?.location;
        return Padding(
          key: ValueKey(item),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.name, overflow: TextOverflow.ellipsis),
                    if (location != null && location.trim().isNotEmpty)
                      Text(
                        '📍 $location',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFFE0407A), fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 90,
                child: DropdownButton<ProductUnit>(
                  value: item.unit,
                  isDense: true,
                  isExpanded: true,
                  items: ProductUnit.values
                      .map((u) => DropdownMenuItem(
                          value: u, child: Text(u.labelAr, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (u) {
                    if (u != null) {
                      item.unit = u;
                      pos.touch();
                    }
                  },
                ),
              ),
              SizedBox(
                width: 96,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      onPressed: () {
                        if (item.quantity > 1) item.quantity -= 1;
                        pos.touch();
                      },
                    ),
                    Text(item.quantity.toStringAsFixed(0)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      onPressed: () {
                        item.quantity += 1;
                        pos.touch();
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 90,
                child: TextFormField(
                  initialValue: item.price.toStringAsFixed(0),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true, labelText: 'السعر'),
                  onChanged: (v) => item.price = double.tryParse(v) ?? item.price,
                ),
              ),
              SizedBox(
                width: 90,
                child: TextFormField(
                  initialValue: item.discount.toStringAsFixed(0),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true, labelText: 'خصم/زيادة'),
                  onChanged: (v) {
                    item.discount = double.tryParse(v) ?? item.discount;
                    pos.touch();
                  },
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  item.lineTotal.toStringAsFixed(0),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  cart.removeAt(i);
                  pos.touch();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addCustomerInline(PosCartService pos, AppData data) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('زبون جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'الهاتف (اختياري)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              final customer = Customer(
                id: newId(),
                name: name.text.trim(),
                phone: phone.text.trim(),
                pharmacyId: context.read<AuthService>().currentPharmacyId,
              );
              await data.customers.upsert(customer);
              pos.current.customerId = customer.id;
              pos.touch();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('إضافة واختيار'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentPanel(AppData data, PosCartService pos, AuthService auth) {
    final cart = pos.current;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المجموع الفرعي'),
                Text(cart.subtotal.toStringAsFixed(0)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الخصم/الزيادة'),
                Text(cart.totalDiscount.toStringAsFixed(0)),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(cart.total.toStringAsFixed(0),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('طريقة الدفع'),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<PaymentType>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                segments: PaymentType.values
                    .map((t) => ButtonSegment(
                          value: t,
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(t.labelAr, maxLines: 1, softWrap: false),
                          ),
                        ))
                    .toList(),
                selected: {cart.paymentType},
                onSelectionChanged: (s) {
                  cart.paymentType = s.first;
                  pos.touch();
                },
              ),
            ),
            if (cart.paymentType == PaymentType.credit) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: cart.customerId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'المراجع (الزبون)'),
                      items: data.customers.items
                          .where((c) => matchesPharmacy(c.pharmacyId, auth.currentPharmacyId))
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: (v) {
                        cart.customerId = v;
                        pos.touch();
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'زبون جديد',
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    onPressed: () => _addCustomerInline(pos, data),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: cart.paidAmount.toStringAsFixed(0),
                decoration: const InputDecoration(labelText: 'المبلغ المدفوع الآن'),
                keyboardType: TextInputType.number,
                onChanged: (v) => cart.paidAmount = double.tryParse(v) ?? 0,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              initialValue: cart.notes,
              decoration: const InputDecoration(labelText: 'ملاحظات الفاتورة'),
              maxLines: 2,
              onChanged: (v) => cart.notes = v,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: cart.items.isEmpty
                  ? null
                  : () => showSubstituteDialog(context, cart).then((_) => pos.touch()),
              icon: const Icon(Icons.sync_alt),
              label: const Text('استبدال علاج'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: cart.items.isEmpty ? null : () => _checkout(pos),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('إتمام البيع'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "الأكثر مبيعاً" — a grid of one-tap quick-add tiles shown on the POS
/// screen before the cashier types anything, built from actual sale
/// history so it's always the real most-sold items, not a fixed list.
class _BestSellersGrid extends StatelessWidget {
  const _BestSellersGrid({required this.products, required this.onTap});

  final List<Product> products;
  final void Function(Product) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text('المنتجات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: products.length,
            itemBuilder: (_, i) {
              final p = products[i];
              return _BestSellerTile(product: p, onTap: () => onTap(p));
            },
          ),
        ),
      ],
    );
  }
}

class _BestSellerTile extends StatefulWidget {
  const _BestSellerTile({required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  State<_BestSellerTile> createState() => _BestSellerTileState();
}

class _BestSellerTileState extends State<_BestSellerTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final outOfStock = p.quantity <= 0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: outOfStock ? 0.4 : 1,
                  child: ProductThumbnail(product: p, radius: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  p.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                Text(
                  outOfStock ? 'نفدت' : '${p.salePrice.toStringAsFixed(0)} د.ع',
                  style: TextStyle(
                    fontSize: 10,
                    color: outOfStock ? Colors.red : const Color(0xFF3A3A3A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
