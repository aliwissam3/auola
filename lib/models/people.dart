/// Fine-grained permission flags an admin grants to an employee.
class EmployeePermissions {
  EmployeePermissions({
    this.reports = false,
    this.debts = false,
    this.lists = false,
    this.sales = true,
    this.viewCost = false,
    this.viewProfit = false,
    this.edit = false,
  });

  bool reports;
  bool debts;
  bool lists;
  bool sales;
  bool viewCost;
  bool viewProfit;
  bool edit;

  EmployeePermissions copyWith({
    bool? reports,
    bool? debts,
    bool? lists,
    bool? sales,
    bool? viewCost,
    bool? viewProfit,
    bool? edit,
  }) {
    return EmployeePermissions(
      reports: reports ?? this.reports,
      debts: debts ?? this.debts,
      lists: lists ?? this.lists,
      sales: sales ?? this.sales,
      viewCost: viewCost ?? this.viewCost,
      viewProfit: viewProfit ?? this.viewProfit,
      edit: edit ?? this.edit,
    );
  }

  Map<String, dynamic> toJson() => {
        'reports': reports,
        'debts': debts,
        'lists': lists,
        'sales': sales,
        'viewCost': viewCost,
        'viewProfit': viewProfit,
        'edit': edit,
      };

  factory EmployeePermissions.fromJson(Map<String, dynamic>? j) {
    if (j == null) return EmployeePermissions();
    return EmployeePermissions(
      reports: j['reports'] as bool? ?? false,
      debts: j['debts'] as bool? ?? false,
      lists: j['lists'] as bool? ?? false,
      sales: j['sales'] as bool? ?? true,
      viewCost: j['viewCost'] as bool? ?? false,
      viewProfit: j['viewProfit'] as bool? ?? false,
      edit: j['edit'] as bool? ?? false,
    );
  }
}

class Employee {
  Employee({
    required this.id,
    required this.name,
    this.phone = '',
    this.password = '',
    this.barcode,
    this.isAdmin = false,
    EmployeePermissions? permissions,
    this.active = true,
    this.pharmacyId,
  }) : permissions = permissions ?? EmployeePermissions();

  final String id;
  String name;
  String phone;
  String password;
  String? barcode;
  bool isAdmin;
  EmployeePermissions permissions;
  bool active;
  /// Which pharmacy this employee belongs to — their login only ever
  /// shows that pharmacy's data. Null means "not yet assigned" (legacy
  /// employees from before multi-pharmacy support existed).
  String? pharmacyId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'password': password,
        'barcode': barcode,
        'isAdmin': isAdmin,
        'permissions': permissions.toJson(),
        'active': active,
        'pharmacyId': pharmacyId,
      };

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String? ?? '',
        password: j['password'] as String? ?? '',
        barcode: j['barcode'] as String?,
        isAdmin: j['isAdmin'] as bool? ?? false,
        permissions: EmployeePermissions.fromJson(
          j['permissions'] as Map<String, dynamic>?,
        ),
        active: j['active'] as bool? ?? true,
        pharmacyId: j['pharmacyId'] as String?,
      );
}

/// A "مراجع" — a customer who can buy on credit (دين).
class Customer {
  Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.creditLimit = 0,
    this.locked = false,
    this.dueDate,
    this.pharmacyId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  String phone;
  double creditLimit;
  bool locked;
  DateTime? dueDate;
  String? pharmacyId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'creditLimit': creditLimit,
        'locked': locked,
        'dueDate': dueDate?.toIso8601String(),
        'pharmacyId': pharmacyId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String? ?? '',
        creditLimit: (j['creditLimit'] as num?)?.toDouble() ?? 0,
        locked: j['locked'] as bool? ?? false,
        dueDate: j['dueDate'] != null
            ? DateTime.tryParse(j['dueDate'] as String)
            : null,
        pharmacyId: j['pharmacyId'] as String?,
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
      );
}

/// A supplier / warehouse (مذخر).
class Supplier {
  Supplier({required this.id, required this.name, this.phone = ''});

  final String id;
  String name;
  String phone;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone};

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String? ?? '',
      );
}

/// A sales representative (مندوب), tied to a supplier/warehouse (the
/// place he actually delivers through) and separately to the company
/// whose products he represents — two different things: a rep from
/// "شركة فايزر" might deliver through "مذخر الرشيد", and another rep from
/// a different company could deliver through that same warehouse.
class Rep {
  Rep({
    required this.id,
    required this.name,
    this.phone = '',
    this.company = '',
    this.supplierId,
  });

  final String id;
  String name;
  String phone;
  String company;
  String? supplierId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'company': company,
        'supplierId': supplierId,
      };

  factory Rep.fromJson(Map<String, dynamic> j) => Rep(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String? ?? '',
        company: j['company'] as String? ?? '',
        supplierId: j['supplierId'] as String?,
      );
}

/// One branch/pharmacy location, for multi-pharmacy setups.
class Pharmacy {
  Pharmacy({required this.id, required this.name, this.address = ''});

  final String id;
  String name;
  String address;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
      };

  factory Pharmacy.fromJson(Map<String, dynamic> j) => Pharmacy(
        id: j['id'] as String,
        name: j['name'] as String,
        address: j['address'] as String? ?? '',
      );
}
