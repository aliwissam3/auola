import 'product.dart';

enum PaymentType { cash, master, credit }

extension PaymentTypeLabel on PaymentType {
  String get labelAr {
    switch (this) {
      case PaymentType.cash:
        return 'نقدي';
      case PaymentType.master:
        return 'ماستر';
      case PaymentType.credit:
        return 'دين';
    }
  }

  static PaymentType fromName(String name) => PaymentType.values.firstWhere(
        (e) => e.name == name,
        orElse: () => PaymentType.cash,
      );
}

/// One product line inside a sale invoice / cart.
class SaleItem {
  SaleItem({
    required this.productId,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.price,
    this.purchasePrice = 0,
    this.discount = 0,
    this.isPartial = false,
  });

  final String productId;
  final String name;
  ProductUnit unit;
  double quantity;
  double price;
  double purchasePrice;

  /// Absolute currency amount subtracted (positive) or added (negative,
  /// i.e. a markup) from the line total.
  double discount;

  /// Partial sale of a strip/packet (e.g. selling loose pills from a strip).
  bool isPartial;

  double get lineTotal => (price * quantity) - discount;
  double get lineProfit => (price - purchasePrice) * quantity - discount;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'unit': unit.name,
        'quantity': quantity,
        'price': price,
        'purchasePrice': purchasePrice,
        'discount': discount,
        'isPartial': isPartial,
      };

  factory SaleItem.fromJson(Map<String, dynamic> j) => SaleItem(
        productId: j['productId'] as String,
        name: j['name'] as String,
        unit: ProductUnitLabel.fromName(j['unit'] as String? ?? 'piece'),
        quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
        price: (j['price'] as num?)?.toDouble() ?? 0,
        purchasePrice: (j['purchasePrice'] as num?)?.toDouble() ?? 0,
        discount: (j['discount'] as num?)?.toDouble() ?? 0,
        isPartial: j['isPartial'] as bool? ?? false,
      );
}

/// A completed (checked-out) sale invoice.
class SaleInvoice {
  SaleInvoice({
    required this.id,
    required this.employeeId,
    required this.items,
    this.customerId,
    this.paymentType = PaymentType.cash,
    this.paidAmount = 0,
    this.notes = '',
    this.substituteNote,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String employeeId;
  final List<SaleItem> items;
  String? customerId;
  PaymentType paymentType;
  double paidAmount;
  String notes;

  /// Free-text note describing an "استبدال علاج" (medicine swap) used to
  /// settle a price difference on this invoice.
  String? substituteNote;
  final DateTime createdAt;

  double get total => items.fold(0.0, (sum, it) => sum + it.lineTotal);
  double get profit => items.fold(0.0, (sum, it) => sum + it.lineProfit);
  double get remaining => total - paidAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'items': items.map((e) => e.toJson()).toList(),
        'customerId': customerId,
        'paymentType': paymentType.name,
        'paidAmount': paidAmount,
        'notes': notes,
        'substituteNote': substituteNote,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SaleInvoice.fromJson(Map<String, dynamic> j) => SaleInvoice(
        id: j['id'] as String,
        employeeId: j['employeeId'] as String,
        items: (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => SaleItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        customerId: j['customerId'] as String?,
        paymentType:
            PaymentTypeLabel.fromName(j['paymentType'] as String? ?? 'cash'),
        paidAmount: (j['paidAmount'] as num?)?.toDouble() ?? 0,
        notes: j['notes'] as String? ?? '',
        substituteNote: j['substituteNote'] as String?,
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
      );
}
