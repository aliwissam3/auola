import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/customer.dart';
import '../models/debt_transaction.dart';
import '../models/employee.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../utils/password_utils.dart';

class DbHelper {
  DbHelper._internal();
  static final DbHelper instance = DbHelper._internal();

  Database? _db;

  /// Must be called once before any database access, from main().
  static void initPlatform() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // Android/iOS/macOS use the default sqflite plugin factory as-is.
  }

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    // App-support storage (not Documents): private to this app and doesn't
    // depend on user-configurable folders that may not exist on every machine.
    final dir = await getApplicationSupportDirectory();
    final path = join(dir.path, 'store_app.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'عام',
        buy_price REAL NOT NULL,
        sell_price REAL NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL DEFAULT 'قطعة',
        low_stock_threshold REAL NOT NULL DEFAULT 5,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        employee_name TEXT NOT NULL,
        customer_name TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL,
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (employee_id) REFERENCES employees (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        buy_price_at_sale REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE debt_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        sale_id INTEGER,
        FOREIGN KEY (customer_id) REFERENCES customers (id),
        FOREIGN KEY (sale_id) REFERENCES sales (id)
      )
    ''');

    // Default admin account so the app is usable on first launch.
    // Login code: 1111 / password: 1111 -- change this from Settings after first login.
    await db.insert('employees', {
      'name': 'المدير',
      'code': '1111',
      'password_hash': hashPassword('1111'),
      'role': 'admin',
      'active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ---------------- Employees ----------------

  Future<List<Employee>> getEmployees() async {
    final db = await database;
    final rows = await db.query('employees', orderBy: 'name COLLATE NOCASE');
    return rows.map(Employee.fromMap).toList();
  }

  Future<Employee?> findByCode(String code) async {
    final db = await database;
    final rows = await db.query('employees', where: 'code = ?', whereArgs: [code], limit: 1);
    if (rows.isEmpty) return null;
    return Employee.fromMap(rows.first);
  }

  Future<Employee?> authenticate(String code, String password) async {
    final employee = await findByCode(code);
    if (employee == null || !employee.active) return null;
    if (!verifyPassword(password, employee.passwordHash)) return null;
    return employee;
  }

  /// Throws [StateError] if the code is already taken by another employee.
  Future<int> saveEmployee(Employee employee, {String? newPassword}) async {
    final db = await database;
    final existing = await findByCode(employee.code);
    if (existing != null && existing.id != employee.id) {
      throw StateError('الرمز مستخدم مسبقاً من قبل موظف آخر');
    }
    final passwordHash = newPassword != null && newPassword.isNotEmpty
        ? hashPassword(newPassword)
        : employee.passwordHash;
    final map = employee.copyWith(passwordHash: passwordHash).toMap();
    if (employee.id == null) {
      map.remove('id');
      return db.insert('employees', map);
    } else {
      await db.update('employees', map, where: 'id = ?', whereArgs: [employee.id]);
      return employee.id!;
    }
  }

  Future<int> countAdmins({int? excludingId}) async {
    final db = await database;
    final rows = await db.query(
      'employees',
      where: excludingId == null ? "role = 'admin' AND active = 1" : "role = 'admin' AND active = 1 AND id != ?",
      whereArgs: excludingId == null ? null : [excludingId],
    );
    return rows.length;
  }

  Future<void> deleteEmployee(int id) async {
    final db = await database;
    await db.delete('employees', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- Products ----------------

  Future<List<Product>> getProducts({String? search}) async {
    final db = await database;
    final rows = await db.query(
      'products',
      where: search != null && search.isNotEmpty ? 'name LIKE ? OR category LIKE ?' : null,
      whereArgs: search != null && search.isNotEmpty ? ['%$search%', '%$search%'] : null,
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> getProduct(int id) async {
    final db = await database;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<int> saveProduct(Product product) async {
    final db = await database;
    final map = product.toMap();
    if (product.id == null) {
      map.remove('id');
      return db.insert('products', map);
    } else {
      await db.update('products', map, where: 'id = ?', whereArgs: [product.id]);
      return product.id!;
    }
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Product>> getLowStockProducts() async {
    final products = await getProducts();
    return products.where((p) => p.isLowStock).toList();
  }

  // ---------------- Customers ----------------

  Future<List<Customer>> getCustomers({String? search}) async {
    final db = await database;
    final rows = await db.query(
      'customers',
      where: search != null && search.isNotEmpty ? 'name LIKE ?' : null,
      whereArgs: search != null && search.isNotEmpty ? ['%$search%'] : null,
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer> _findOrCreateCustomer(DatabaseExecutor txn, String name) async {
    final rows = await txn.query('customers', where: 'name = ?', whereArgs: [name], limit: 1);
    if (rows.isNotEmpty) return Customer.fromMap(rows.first);
    final id = await txn.insert('customers', Customer(name: name, createdAt: DateTime.now()).toMap()..remove('id'));
    return Customer(id: id, name: name, createdAt: DateTime.now());
  }

  Future<int> addManualDebt({
    required String customerName,
    required double amount,
    String note = '',
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final customer = await _findOrCreateCustomer(txn, customerName);
      return txn.insert(
        'debt_transactions',
        DebtTransaction(
          customerId: customer.id!,
          type: 'charge',
          amount: amount,
          date: DateTime.now(),
          note: note,
        ).toMap()..remove('id'),
      );
    });
  }

  Future<int> addDebtPayment({
    required int customerId,
    required double amount,
    String note = '',
  }) async {
    final db = await database;
    return db.insert(
      'debt_transactions',
      DebtTransaction(
        customerId: customerId,
        type: 'payment',
        amount: amount,
        date: DateTime.now(),
        note: note,
      ).toMap()..remove('id'),
    );
  }

  Future<List<DebtTransaction>> getTransactionsForCustomer(int customerId) async {
    final db = await database;
    final rows = await db.query(
      'debt_transactions',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC',
    );
    return rows.map(DebtTransaction.fromMap).toList();
  }

  /// Returns customer -> outstanding balance (charges - payments), only customers with a non-zero balance.
  Future<List<MapEntry<Customer, double>>> getCustomerBalances() async {
    final db = await database;
    final customers = await getCustomers();
    final result = <MapEntry<Customer, double>>[];
    for (final customer in customers) {
      final chargeRows = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total FROM debt_transactions WHERE customer_id = ? AND type = 'charge'",
        [customer.id],
      );
      final paymentRows = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total FROM debt_transactions WHERE customer_id = ? AND type = 'payment'",
        [customer.id],
      );
      final charges = (chargeRows.first['total'] as num).toDouble();
      final payments = (paymentRows.first['total'] as num).toDouble();
      final balance = charges - payments;
      if (balance.abs() > 0.0001) {
        result.add(MapEntry(customer, balance));
      }
    }
    result.sort((a, b) => b.value.compareTo(a.value));
    return result;
  }

  Future<double> getTotalOutstandingDebt() async {
    final balances = await getCustomerBalances();
    return balances.fold<double>(0.0, (sum, e) => sum + e.value);
  }

  // ---------------- Sales ----------------

  Future<int> createSale({
    required Sale sale,
    required List<SaleItem> items,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final saleId = await txn.insert('sales', sale.toMap()..remove('id'));

      for (final item in items) {
        await txn.insert(
          'sale_items',
          item.toMap()
            ..remove('id')
            ..['sale_id'] = saleId,
        );
        // Decrement stock.
        final productRows = await txn.query('products', where: 'id = ?', whereArgs: [item.productId], limit: 1);
        if (productRows.isNotEmpty) {
          final currentQty = (productRows.first['quantity'] as num).toDouble();
          await txn.update(
            'products',
            {'quantity': currentQty - item.quantity},
            where: 'id = ?',
            whereArgs: [item.productId],
          );
        }
      }

      final debtAmount = sale.totalAmount - sale.paidAmount;
      if (debtAmount > 0.0001) {
        final customerName = sale.customerName.trim().isEmpty ? 'زبون بدون اسم' : sale.customerName.trim();
        final customer = await _findOrCreateCustomer(txn, customerName);
        await txn.insert(
          'debt_transactions',
          DebtTransaction(
            customerId: customer.id!,
            type: 'charge',
            amount: debtAmount,
            date: sale.date,
            note: 'دين من عملية بيع',
            saleId: saleId,
          ).toMap()..remove('id'),
        );
      }

      return saleId;
    });
  }

  Future<List<Sale>> getSales({DateTime? from, DateTime? to}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('date <= ?');
      args.add(to.toIso8601String());
    }
    final rows = await db.query(
      'sales',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC',
    );
    return rows.map(Sale.fromMap).toList();
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final db = await database;
    final rows = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
    return rows.map(SaleItem.fromMap).toList();
  }

  // ---------------- Reports ----------------

  Future<double> getTotalSales({DateTime? from, DateTime? to}) async {
    final sales = await getSales(from: from, to: to);
    return sales.fold<double>(0.0, (sum, s) => sum + s.totalAmount);
  }

  Future<double> getTotalProfit({DateTime? from, DateTime? to}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('s.date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('s.date <= ?');
      args.add(to.toIso8601String());
    }
    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM((si.unit_price - si.buy_price_at_sale) * si.quantity), 0) as profit
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      $whereClause
    ''', args);
    return (rows.first['profit'] as num).toDouble();
  }

  Future<List<MapEntry<String, double>>> getTopProducts({int limit = 5, DateTime? from, DateTime? to}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('s.date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('s.date <= ?');
      args.add(to.toIso8601String());
    }
    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT si.product_name as name, SUM(si.quantity) as qty
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      $whereClause
      GROUP BY si.product_name
      ORDER BY qty DESC
      LIMIT ?
    ''', [...args, limit]);
    return rows.map((r) => MapEntry(r['name'] as String, (r['qty'] as num).toDouble())).toList();
  }
}
