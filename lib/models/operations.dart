/// A free-form, user-created checklist (e.g. a to-buy note) shown
/// alongside the auto-generated sales/purchase lists.
/// [kind] separates plain personal checklists ("custom", the default —
/// shown under "قوائمي") from manually-added sale/purchase lists (shown
/// under their own tabs alongside the auto-generated invoice lists),
/// without needing three separate models for what's otherwise identical
/// data.
class CustomList {
  CustomList({
    required this.id,
    required this.title,
    List<String>? items,
    DateTime? createdAt,
    this.kind = 'custom',
  })  : items = items ?? [],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String title;
  List<String> items;
  final DateTime createdAt;
  final String kind;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'items': items,
        'createdAt': createdAt.toIso8601String(),
        'kind': kind,
      };

  factory CustomList.fromJson(Map<String, dynamic> j) => CustomList(
        id: j['id'] as String,
        title: j['title'] as String,
        items: (j['items'] as List? ?? []).map((e) => e.toString()).toList(),
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
        kind: j['kind'] as String? ?? 'custom',
      );
}

/// A payment a customer makes against their debt (تسديد دين مراجع).
class DebtPayment {
  DebtPayment({
    required this.id,
    required this.customerId,
    required this.amount,
    this.note = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String customerId;
  double amount;
  String note;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'amount': amount,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DebtPayment.fromJson(Map<String, dynamic> j) => DebtPayment(
        id: j['id'] as String,
        customerId: j['customerId'] as String,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        note: j['note'] as String? ?? '',
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
      );
}

/// A payment made to a supplier/warehouse (تسديد دين مذخر).
class SupplierPayment {
  SupplierPayment({
    required this.id,
    required this.supplierId,
    required this.amount,
    this.discountAmount = 0,
    this.isExternal = false,
    this.note = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String supplierId;
  double amount;

  /// A percentage discount the supplier gave, converted to a currency
  /// amount at the time of payment - reduces the balance owed just like
  /// [amount], with no extra cash actually changing hands for this part.
  double discountAmount;

  /// True when this payment came from money outside the pharmacy's own
  /// register (e.g. the owner paid the supplier personally) - kept out
  /// of the pharmacy's sales-income figures even though it still
  /// reduces the supplier balance.
  bool isExternal;
  String note;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'supplierId': supplierId,
        'amount': amount,
        'discountAmount': discountAmount,
        'isExternal': isExternal,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SupplierPayment.fromJson(Map<String, dynamic> j) => SupplierPayment(
        id: j['id'] as String,
        supplierId: j['supplierId'] as String,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        discountAmount: (j['discountAmount'] as num?)?.toDouble() ?? 0,
        isExternal: j['isExternal'] as bool? ?? false,
        note: j['note'] as String? ?? '',
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
      );
}

/// Status of a stock deficit / backorder line (النقوصات).
enum DeficitStatus { missing, notOrdered, prepared }

extension DeficitStatusLabel on DeficitStatus {
  String get labelAr {
    switch (this) {
      case DeficitStatus.missing:
        return 'مواد مفقودة';
      case DeficitStatus.notOrdered:
        return 'مواد لم تطلب';
      case DeficitStatus.prepared:
        return 'مواد مجهزة';
    }
  }

  static DeficitStatus fromName(String name) => DeficitStatus.values
      .firstWhere((e) => e.name == name, orElse: () => DeficitStatus.missing);
}

class DeficitItem {
  DeficitItem({
    required this.id,
    required this.name,
    this.status = DeficitStatus.missing,
    this.requestedBy = '',
    this.note = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  DeficitStatus status;
  String requestedBy;
  String note;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status.name,
        'requestedBy': requestedBy,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DeficitItem.fromJson(Map<String, dynamic> j) => DeficitItem(
        id: j['id'] as String,
        name: j['name'] as String,
        status: DeficitStatusLabel.fromName(j['status'] as String? ?? 'missing'),
        requestedBy: j['requestedBy'] as String? ?? '',
        note: j['note'] as String? ?? '',
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
      );
}

/// A product flagged for return to the supplier (مواد معدة للاسترجاع).
class ReturnItem {
  ReturnItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.quantity,
    this.reason = '',
    this.returned = false,
    this.supplierId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String productId;
  String name;
  int quantity;
  String reason;
  bool returned;
  /// The warehouse/company this item is going back to - so a return is
  /// always tied to where it originally came from.
  String? supplierId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'name': name,
        'quantity': quantity,
        'reason': reason,
        'returned': returned,
        'supplierId': supplierId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReturnItem.fromJson(Map<String, dynamic> j) => ReturnItem(
        id: j['id'] as String,
        productId: j['productId'] as String,
        name: j['name'] as String,
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        reason: j['reason'] as String? ?? '',
        returned: j['returned'] as bool? ?? false,
        supplierId: j['supplierId'] as String?,
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
      );
}

/// A product a customer brought back to the pharmacy (راجعة من الزبون) —
/// separate from [ReturnItem], which is stock the pharmacy sends back to
/// its *supplier*. Restocking (adding [quantity] back to inventory) is
/// the caller's job, same pattern as everywhere else in this app.
class CustomerReturn {
  CustomerReturn({
    required this.id,
    required this.productId,
    required this.name,
    required this.quantity,
    this.customerId,
    this.customerName,
    this.reason = '',
    this.refundAmount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String productId;
  String name;
  int quantity;
  String? customerId;
  String? customerName;
  String reason;
  double refundAmount;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'name': name,
        'quantity': quantity,
        'customerId': customerId,
        'customerName': customerName,
        'reason': reason,
        'refundAmount': refundAmount,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CustomerReturn.fromJson(Map<String, dynamic> j) => CustomerReturn(
        id: j['id'] as String,
        productId: j['productId'] as String,
        name: j['name'] as String,
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        customerId: j['customerId'] as String?,
        customerName: j['customerName'] as String?,
        reason: j['reason'] as String? ?? '',
        refundAmount: (j['refundAmount'] as num?)?.toDouble() ?? 0,
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
      );
}

enum StockMovementType { stockIn, stockOut, adjustment }

extension StockMovementTypeLabel on StockMovementType {
  String get labelAr {
    switch (this) {
      case StockMovementType.stockIn:
        return 'إدخال';
      case StockMovementType.stockOut:
        return 'إخراج';
      case StockMovementType.adjustment:
        return 'تعديل جرد';
    }
  }

  static StockMovementType fromName(String name) => StockMovementType.values
      .firstWhere((e) => e.name == name, orElse: () => StockMovementType.stockOut);
}

/// One movement (حركة مادة) affecting a product's stock — sale, purchase or
/// manual adjustment — used to build the "راكدة" (stagnant stock) and
/// purchase-history views.
class StockMovement {
  StockMovement({
    required this.id,
    required this.productId,
    required this.name,
    required this.type,
    required this.quantity,
    this.note = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String productId;
  String name;
  StockMovementType type;
  int quantity;
  String note;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'name': name,
        'type': type.name,
        'quantity': quantity,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StockMovement.fromJson(Map<String, dynamic> j) => StockMovement(
        id: j['id'] as String,
        productId: j['productId'] as String,
        name: j['name'] as String,
        type: StockMovementTypeLabel.fromName(j['type'] as String? ?? 'stockOut'),
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        note: j['note'] as String? ?? '',
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
      );
}

/// A general operating expense (مصروف) — rent, electricity, etc.
class Expense {
  Expense({
    required this.id,
    required this.title,
    required this.amount,
    this.category = 'عام',
    this.isFixed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String title;
  double amount;
  String category;
  /// Fixed (إيجار، رواتب...) vs. variable (يتغيّر شهر عن شهر) expense.
  bool isFixed;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'isFixed': isFixed,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        title: j['title'] as String,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        category: j['category'] as String? ?? 'عام',
        isFixed: j['isFixed'] as bool? ?? false,
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
      );
}

/// A login/shift record for the "الدخولات" attendance log.
class EntryLog {
  EntryLog({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory EntryLog.fromJson(Map<String, dynamic> j) => EntryLog(
        id: j['id'] as String,
        employeeId: j['employeeId'] as String,
        employeeName: j['employeeName'] as String? ?? '',
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
      );
}
