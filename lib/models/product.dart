/// A dispensing unit a product can be sold/counted in.
enum ProductUnit { strip, pill, piece, packet }

extension ProductUnitLabel on ProductUnit {
  String get labelAr {
    switch (this) {
      case ProductUnit.strip:
        return 'شريط';
      case ProductUnit.pill:
        return 'حبة';
      case ProductUnit.piece:
        return 'قطعة';
      case ProductUnit.packet:
        return 'باكيت';
    }
  }

  static ProductUnit fromName(String name) => ProductUnit.values.firstWhere(
        (u) => u.name == name,
        orElse: () => ProductUnit.piece,
      );
}

/// One expiry batch of a product. A product can have several batches with
/// different expiry dates and quantities in stock at the same time.
class Batch {
  Batch({
    required this.id,
    required this.productId,
    required this.quantity,
    this.batchNumber,
    this.expiryDate,
  });

  final String id;
  final String productId;
  int quantity;
  String? batchNumber;
  DateTime? expiryDate;

  Batch copyWith({int? quantity, String? batchNumber, DateTime? expiryDate}) {
    return Batch(
      id: id,
      productId: productId,
      quantity: quantity ?? this.quantity,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'quantity': quantity,
        'batchNumber': batchNumber,
        'expiryDate': expiryDate?.toIso8601String(),
      };

  factory Batch.fromJson(Map<String, dynamic> j) => Batch(
        id: j['id'] as String,
        productId: j['productId'] as String,
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        batchNumber: j['batchNumber'] as String?,
        expiryDate: j['expiryDate'] != null
            ? DateTime.tryParse(j['expiryDate'] as String)
            : null,
      );
}

class Product {
  Product({
    required this.id,
    required this.name,
    this.nameEn,
    this.barcode,
    this.location,
    this.treats,
    this.shelfId,
    this.purchasePrice = 0,
    this.salePrice = 0,
    this.unit = ProductUnit.piece,
    this.quantity = 0,
    this.lowStockThreshold = 10,
    this.expiryAlertDays = 60,
    this.supplierId,
    this.pharmacyId,
    this.image,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;

  /// Optional English/Latin name for the same product — shown alongside
  /// the Arabic [name] wherever it's set, and included in search so
  /// staff can look a medicine up by either name.
  String? nameEn;
  String? barcode;
  /// Free-text shelf/aisle location inside the pharmacy (e.g. "رف 3 - قسم البرد").
  String? location;
  /// Links this product to a shape drawn on the free-form pharmacy map
  /// (see PharmacyShelf) — independent of the free-text [location] above.
  /// What conditions this medicine is generally used for — either typed
  /// by the pharmacist or filled from the built-in drug reference (see
  /// DrugReference). Free text, Arabic.
  String? treats;
  String? shelfId;
  double purchasePrice;
  double salePrice;
  ProductUnit unit;
  int quantity;
  int lowStockThreshold;
  int expiryAlertDays;
  String? supplierId;
  String? pharmacyId;

  /// Product photo, stored inline as a base64-encoded JPEG/PNG string —
  /// same approach the reference app used, avoids needing a separate
  /// file-storage layer for a purely local single-device app.
  String? image;
  final DateTime createdAt;

  bool get isLowStock => quantity <= lowStockThreshold;

  Product copyWith({
    String? name,
    String? nameEn,
    bool clearNameEn = false,
    String? location,
    bool clearLocation = false,
    String? shelfId,
    String? treats,
    bool clearTreats = false,
    bool clearShelfId = false,
    String? barcode,
    double? purchasePrice,
    double? salePrice,
    ProductUnit? unit,
    int? quantity,
    int? lowStockThreshold,
    int? expiryAlertDays,
    String? supplierId,
    String? pharmacyId,
    String? image,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      nameEn: clearNameEn ? null : (nameEn ?? this.nameEn),
      location: clearLocation ? null : (location ?? this.location),
      shelfId: clearShelfId ? null : (shelfId ?? this.shelfId),
      treats: clearTreats ? null : (treats ?? this.treats),
      barcode: barcode ?? this.barcode,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      expiryAlertDays: expiryAlertDays ?? this.expiryAlertDays,
      supplierId: supplierId ?? this.supplierId,
      pharmacyId: pharmacyId ?? this.pharmacyId,
      image: image ?? this.image,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nameEn': nameEn,
        'location': location,
        'shelfId': shelfId,
        'treats': treats,
        'barcode': barcode,
        'purchasePrice': purchasePrice,
        'salePrice': salePrice,
        'unit': unit.name,
        'quantity': quantity,
        'lowStockThreshold': lowStockThreshold,
        'expiryAlertDays': expiryAlertDays,
        'supplierId': supplierId,
        'pharmacyId': pharmacyId,
        'image': image,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String,
        name: j['name'] as String,
        nameEn: j['nameEn'] as String?,
        location: j['location'] as String?,
        shelfId: j['shelfId'] as String?,
        treats: j['treats'] as String?,
        barcode: j['barcode'] as String?,
        purchasePrice: (j['purchasePrice'] as num?)?.toDouble() ?? 0,
        salePrice: (j['salePrice'] as num?)?.toDouble() ?? 0,
        unit: ProductUnitLabel.fromName(j['unit'] as String? ?? 'piece'),
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        lowStockThreshold: (j['lowStockThreshold'] as num?)?.toInt() ?? 10,
        expiryAlertDays: (j['expiryAlertDays'] as num?)?.toInt() ?? 60,
        supplierId: j['supplierId'] as String?,
        pharmacyId: j['pharmacyId'] as String?,
        image: j['image'] as String?,
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
      );
}
