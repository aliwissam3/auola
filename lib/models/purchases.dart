class PurchaseItem {
  PurchaseItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitCost,
    this.expiryDate,
  });

  final String productId;
  final String name;
  int quantity;
  double unitCost;
  DateTime? expiryDate;

  double get lineTotal => quantity * unitCost;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'quantity': quantity,
        'unitCost': unitCost,
        'expiryDate': expiryDate?.toIso8601String(),
      };

  factory PurchaseItem.fromJson(Map<String, dynamic> j) => PurchaseItem(
        productId: j['productId'] as String,
        name: j['name'] as String,
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        unitCost: (j['unitCost'] as num?)?.toDouble() ?? 0,
        expiryDate: j['expiryDate'] != null
            ? DateTime.tryParse(j['expiryDate'] as String)
            : null,
      );
}

/// A purchase invoice from a supplier/warehouse — optionally captured from
/// a photographed paper receipt via OCR (see OcrService).
class Purchase {
  Purchase({
    required this.id,
    required this.supplierId,
    required this.items,
    this.repId,
    this.paidAmount = 0,
    this.receiptImagePath,
    DateTime? purchaseDate,
  }) : purchaseDate = purchaseDate ?? DateTime.now();

  final String id;
  String supplierId;
  String? repId;
  final List<PurchaseItem> items;
  double paidAmount;
  String? receiptImagePath;
  final DateTime purchaseDate;

  double get total => items.fold(0.0, (sum, it) => sum + it.lineTotal);
  double get remaining => total - paidAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'supplierId': supplierId,
        'repId': repId,
        'items': items.map((e) => e.toJson()).toList(),
        'paidAmount': paidAmount,
        'receiptImagePath': receiptImagePath,
        'purchaseDate': purchaseDate.toIso8601String(),
      };

  factory Purchase.fromJson(Map<String, dynamic> j) => Purchase(
        id: j['id'] as String,
        supplierId: j['supplierId'] as String,
        repId: j['repId'] as String?,
        items: (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PurchaseItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        paidAmount: (j['paidAmount'] as num?)?.toDouble() ?? 0,
        receiptImagePath: j['receiptImagePath'] as String?,
        purchaseDate: j['purchaseDate'] != null
            ? DateTime.tryParse(j['purchaseDate'] as String)
            : null,
      );
}
