class SaleItem {
  final int? id;
  final int? saleId;
  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double buyPriceAtSale;

  const SaleItem({
    this.id,
    this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.buyPriceAtSale,
  });

  double get subtotal => quantity * unitPrice;
  double get profit => quantity * (unitPrice - buyPriceAtSale);

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'buy_price_at_sale': buyPriceAtSale,
    };
  }

  factory SaleItem.fromMap(Map<String, Object?> map) {
    return SaleItem(
      id: map['id'] as int?,
      saleId: map['sale_id'] as int?,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      buyPriceAtSale: (map['buy_price_at_sale'] as num).toDouble(),
    );
  }
}

class Sale {
  final int? id;
  final int employeeId;
  final String employeeName;
  final String customerName;
  final DateTime date;
  final double totalAmount;
  final double paidAmount;
  final String note;
  final List<SaleItem> items;

  const Sale({
    this.id,
    required this.employeeId,
    required this.employeeName,
    this.customerName = '',
    required this.date,
    required this.totalAmount,
    required this.paidAmount,
    this.note = '',
    this.items = const [],
  });

  double get debtAmount => (totalAmount - paidAmount).clamp(0, double.infinity);
  bool get isFullyPaid => debtAmount <= 0.0001;
  double get totalProfit => items.fold<double>(0, (sum, item) => sum + item.profit);

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'customer_name': customerName,
      'date': date.toIso8601String(),
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'note': note,
    };
  }

  factory Sale.fromMap(Map<String, Object?> map) {
    return Sale(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as int,
      employeeName: map['employee_name'] as String,
      customerName: map['customer_name'] as String? ?? '',
      date: DateTime.parse(map['date'] as String),
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num).toDouble(),
      note: map['note'] as String? ?? '',
    );
  }
}
