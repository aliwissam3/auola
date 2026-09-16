import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import '../models/sale.dart';
import '../services/backend_service.dart';
import '../state/session.dart';

const _pageSize = 50;

class _CartLine {
  final Product product;
  double quantity;
  _CartLine({required this.product, required this.quantity});

  double get subtotal => product.sellPrice * quantity;
}

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'بيع جديد', icon: Icon(Icons.add_shopping_cart)),
            Tab(text: 'سجل المبيعات', icon: Icon(Icons.receipt_long)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [_NewSaleTab(), _SalesHistoryTab()],
          ),
        ),
      ],
    );
  }
}

class _NewSaleTab extends StatefulWidget {
  const _NewSaleTab();

  @override
  State<_NewSaleTab> createState() => _NewSaleTabState();
}

class _NewSaleTabState extends State<_NewSaleTab> {
  List<Product> _products = [];
  final List<_CartLine> _cart = [];
  final _customerController = TextEditingController();
  final _paidController = TextEditingController();
  String _search = '';
  bool _loading = true;
  bool _saving = false;
  String? _message;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _reloadProducts();
    _channel = BackendService.instance.watchTable('products', _reloadProducts);
  }

  @override
  void dispose() {
    if (_channel != null) BackendService.instance.unwatch(_channel!);
    _customerController.dispose();
    _paidController.dispose();
    super.dispose();
  }

  Future<void> _reloadProducts() async {
    setState(() => _loading = true);
    final products = await BackendService.instance.getProducts(search: _search, limit: _pageSize);
    if (!mounted) return;
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  double get _total => _cart.fold<double>(0, (sum, line) => sum + line.subtotal);

  void _addToCart(Product product) {
    setState(() {
      final existing = _cart.where((l) => l.product.id == product.id).toList();
      if (existing.isNotEmpty) {
        existing.first.quantity += 1;
      } else {
        _cart.add(_CartLine(product: product, quantity: 1));
      }
    });
  }

  void _changeQuantity(_CartLine line, double delta) {
    setState(() {
      line.quantity = (line.quantity + delta).clamp(1, double.infinity);
    });
  }

  void _removeLine(_CartLine line) {
    setState(() => _cart.remove(line));
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) {
      setState(() => _message = 'أضف منتجات إلى السلة أولاً');
      return;
    }
    for (final line in _cart) {
      if (line.quantity > line.product.quantity) {
        setState(() => _message = 'الكمية المتوفرة من "${line.product.name}" غير كافية');
        return;
      }
    }
    final total = _total;
    final paid = double.tryParse(_paidController.text) ?? total;
    final customerName = _customerController.text.trim();
    if (paid < total && customerName.isEmpty) {
      setState(() => _message = 'أدخل اسم الزبون عند وجود مبلغ غير مدفوع (دين)');
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });

    final session = context.read<AppSession>();
    final employee = session.employee!;

    final sale = Sale(
      employeeId: employee.id,
      employeeName: employee.name,
      customerName: customerName,
      date: DateTime.now(),
      totalAmount: total,
      paidAmount: paid > total ? total : paid,
    );
    final items = _cart
        .map((line) => SaleItem(
              productId: line.product.id!,
              productName: line.product.name,
              quantity: line.quantity,
              unitPrice: line.product.sellPrice,
              buyPriceAtSale: line.product.buyPrice,
            ))
        .toList();

    try {
      await BackendService.instance.createSale(sale: sale, items: items);
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _customerController.clear();
        _paidController.clear();
        _message = 'تم حفظ عملية البيع بنجاح';
      });
      _reloadProducts();
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _message = e.message);
      _reloadProducts();
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'تعذر إتمام البيع، تحقق من الاتصال وحاول مجدداً');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
      final productList = Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث عن منتج للإضافة...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                _search = v;
                _reloadProducts();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      final outOfStock = product.quantity <= 0;
                      return ListTile(
                        title: Text(product.name),
                        subtitle: Text('السعر: ${_fmt(product.sellPrice)} — متوفر: ${_fmt(product.quantity)} ${product.unit}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.teal),
                          onPressed: outOfStock ? null : () => _addToCart(product),
                        ),
                        enabled: !outOfStock,
                        onTap: outOfStock ? null : () => _addToCart(product),
                      );
                    },
                  ),
          ),
        ],
      );

      final cartPanel = Column(
        children: [
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('السلة فارغة، اختر منتجات من القائمة'))
                : ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final line = _cart[index];
                      return ListTile(
                        title: Text(line.product.name),
                        subtitle: Text('${_fmt(line.product.sellPrice)} × ${_fmt(line.quantity)} = ${_fmt(line.subtotal)}'),
                        leading: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _changeQuantity(line, -1),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => _changeQuantity(line, 1),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _removeLine(line),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('الإجمالي: ${_fmt(_total)}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                TextField(
                  controller: _customerController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الزبون (اختياري إلا عند وجود دين)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _paidController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'المبلغ المدفوع (اتركه فارغاً للدفع الكامل)',
                    hintText: _fmt(_total),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 8),
                  Text(_message!, style: TextStyle(color: _message!.contains('نجاح') ? Colors.green : Colors.red)),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _checkout,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(_saving ? 'جارٍ الحفظ...' : 'إتمام البيع'),
                ),
              ],
            ),
          ),
        ],
      );

      if (wide) {
        return Row(
          children: [
            Expanded(flex: 3, child: productList),
            const VerticalDivider(width: 1),
            Expanded(flex: 2, child: cartPanel),
          ],
        );
      }

      return Column(
        children: [
          Expanded(child: productList),
          const Divider(height: 1),
          SizedBox(height: 360, child: cartPanel),
        ],
      );
    });
  }
}

class _SalesHistoryTab extends StatefulWidget {
  const _SalesHistoryTab();

  @override
  State<_SalesHistoryTab> createState() => _SalesHistoryTabState();
}

class _SalesHistoryTabState extends State<_SalesHistoryTab> {
  final List<Sale> _sales = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _reload();
    _channel = BackendService.instance.watchTable('sales', _reload);
  }

  @override
  void dispose() {
    if (_channel != null) BackendService.instance.unwatch(_channel!);
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final sales = await BackendService.instance.getSales(limit: _pageSize);
    if (!mounted) return;
    setState(() {
      _sales
        ..clear()
        ..addAll(sales);
      _hasMore = sales.length == _pageSize;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final more = await BackendService.instance.getSales(limit: _pageSize, offset: _sales.length);
    if (!mounted) return;
    setState(() {
      _sales.addAll(more);
      _hasMore = more.length == _pageSize;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_sales.isEmpty) return const Center(child: Text('لا توجد عمليات بيع بعد'));

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        itemCount: _sales.length + 1,
        itemBuilder: (context, index) {
          if (index == _sales.length) {
            if (!_hasMore) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator()
                    : OutlinedButton(onPressed: _loadMore, child: const Text('تحميل المزيد')),
              ),
            );
          }
          final sale = _sales[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ExpansionTile(
              title: Text('${_fmt(sale.totalAmount)} — ${sale.customerName.isEmpty ? "زبون عادي" : sale.customerName}'),
              subtitle: Text(
                '${_formatDate(sale.date)} • البائع: ${sale.employeeName}'
                '${sale.debtAmount > 0 ? " • دين: ${_fmt(sale.debtAmount)}" : ""}',
              ),
              children: [
                FutureBuilder(
                  future: BackendService.instance.getSaleItems(sale.id!),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      );
                    }
                    final items = snapshot.data!;
                    return Column(
                      children: items
                          .map((item) => ListTile(
                                dense: true,
                                title: Text(item.productName),
                                subtitle: Text('${_fmt(item.unitPrice)} × ${_fmt(item.quantity)}'),
                                trailing: Text(_fmt(item.subtotal)),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _fmt(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
