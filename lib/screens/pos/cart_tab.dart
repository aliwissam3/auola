import '../../models/product.dart';
import '../../models/sales.dart';

/// A single open invoice inside the multi-cart POS screen. Purely
/// in-memory/UI state — it becomes a real [SaleInvoice] only once the
/// cashier hits "إتمام البيع".
class CartTab {
  CartTab({required this.id, required this.name});

  final String id;
  String name;
  final List<SaleItem> items = [];
  String? customerId;
  PaymentType paymentType = PaymentType.cash;
  double paidAmount = 0;
  String notes = '';
  String? substituteNote;

  double get subtotal => items.fold(0.0, (s, it) => s + (it.price * it.quantity));
  double get totalDiscount => items.fold(0.0, (s, it) => s + it.discount);
  double get total => items.fold(0.0, (s, it) => s + it.lineTotal);

  void addProduct(Product p) {
    final existing = items.where(
      (it) => it.productId == p.id && it.unit == p.unit && !it.isPartial,
    );
    if (existing.isNotEmpty) {
      existing.first.quantity += 1;
      return;
    }
    items.add(SaleItem(
      productId: p.id,
      name: p.name,
      unit: p.unit,
      quantity: 1,
      price: p.salePrice,
      purchasePrice: p.purchasePrice,
    ));
  }

  void removeAt(int index) => items.removeAt(index);
}
