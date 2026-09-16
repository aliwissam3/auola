class Product {
  final String? id;
  final String name;
  final String category;
  final double buyPrice;
  final double sellPrice;
  final double quantity;
  final String unit;
  final double lowStockThreshold;
  final DateTime? createdAt;

  const Product({
    this.id,
    required this.name,
    this.category = 'عام',
    required this.buyPrice,
    required this.sellPrice,
    required this.quantity,
    this.unit = 'قطعة',
    this.lowStockThreshold = 5,
    this.createdAt,
  });

  bool get isLowStock => quantity <= lowStockThreshold;

  double get profitPerUnit => sellPrice - buyPrice;

  Map<String, Object?> toMap() {
    return {
      'name': name,
      'category': category,
      'buy_price': buyPrice,
      'sell_price': sellPrice,
      'quantity': quantity,
      'unit': unit,
      'low_stock_threshold': lowStockThreshold,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String? ?? 'عام',
      buyPrice: (map['buy_price'] as num).toDouble(),
      sellPrice: (map['sell_price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String? ?? 'قطعة',
      lowStockThreshold: (map['low_stock_threshold'] as num?)?.toDouble() ?? 5,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
    );
  }
}
