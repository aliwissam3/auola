class Product {
  final int? id;
  final String name;
  final String category;
  final double buyPrice;
  final double sellPrice;
  final double quantity;
  final String unit;
  final double lowStockThreshold;
  final DateTime createdAt;

  const Product({
    this.id,
    required this.name,
    this.category = 'عام',
    required this.buyPrice,
    required this.sellPrice,
    required this.quantity,
    this.unit = 'قطعة',
    this.lowStockThreshold = 5,
    required this.createdAt,
  });

  bool get isLowStock => quantity <= lowStockThreshold;

  double get profitPerUnit => sellPrice - buyPrice;

  Product copyWith({
    int? id,
    String? name,
    String? category,
    double? buyPrice,
    double? sellPrice,
    double? quantity,
    String? unit,
    double? lowStockThreshold,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'buy_price': buyPrice,
      'sell_price': sellPrice,
      'quantity': quantity,
      'unit': unit,
      'low_stock_threshold': lowStockThreshold,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, Object?> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: map['category'] as String? ?? 'عام',
      buyPrice: (map['buy_price'] as num).toDouble(),
      sellPrice: (map['sell_price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String? ?? 'قطعة',
      lowStockThreshold: (map['low_stock_threshold'] as num?)?.toDouble() ?? 5,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
