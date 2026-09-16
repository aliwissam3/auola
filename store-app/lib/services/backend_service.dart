import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer.dart';
import '../models/debt_transaction.dart';
import '../models/employee.dart';
import '../models/product.dart';
import '../models/sale.dart';

/// A friendly error message surfaced from a database rule (e.g. "you're not
/// an admin", "that code is taken", "not enough stock left").
class BackendException implements Exception {
  final String message;
  BackendException(this.message);
  @override
  String toString() => message;
}

class ReportSummary {
  final double totalSales;
  final double totalProfit;
  const ReportSummary({required this.totalSales, required this.totalProfit});
}

/// Talks to the single shared Supabase project every device (Android,
/// Windows, web) reads and writes through, so changes on one show up
/// everywhere else. All mutation-heavy or security-sensitive operations
/// (employee management, recording a sale, debt entries) call a Postgres
/// function on the server instead of writing to tables directly, which is
/// what keeps stock counts and debt totals correct even when two devices
/// act at the same moment.
class BackendService {
  BackendService._internal();
  static final BackendService instance = BackendService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  Future<T> _unwrapAsync<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (e) {
      throw BackendException(e.message);
    }
  }

  /// Signs this device into the shared anonymous session required by the
  /// row-level-security policies. Call once at startup.
  Future<void> ensureSignedIn() async {
    if (_client.auth.currentSession == null) {
      await _client.auth.signInAnonymously();
    }
  }

  RealtimeChannel watchTable(String table, void Function() onChange) {
    final channel = _client.channel('public:$table:${identityHashCode(onChange)}');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (payload) => onChange(),
        )
        .subscribe();
    return channel;
  }

  void unwatch(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }

  // ---------------- Employees / auth ----------------

  Future<bool> employeesExist() {
    return _unwrapAsync(() async {
      final result = await _client.rpc('employees_exist');
      return result as bool;
    });
  }

  Future<void> bootstrapFirstAdmin({required String name, required String code, required String password}) {
    return _unwrapAsync(() => _client.rpc('bootstrap_first_admin', params: {
          'p_name': name,
          'p_code': code,
          'p_password': password,
        }));
  }

  Future<Employee?> authenticate(String code, String password) {
    return _unwrapAsync(() async {
      final rows = await _client.rpc('login_employee', params: {'p_code': code, 'p_password': password}) as List;
      if (rows.isEmpty) return null;
      return Employee.fromMap(rows.first as Map<String, dynamic>);
    });
  }

  Future<List<Employee>> getEmployees(String actingEmployeeId) {
    return _unwrapAsync(() async {
      final rows =
          await _client.rpc('admin_list_employees', params: {'p_acting_employee_id': actingEmployeeId}) as List;
      return rows.map((r) => Employee.fromMap(r as Map<String, dynamic>)).toList();
    });
  }

  /// Returns the new/updated employee's id. Pass [password] only to set or
  /// change it; leave it null/empty to keep the existing one.
  Future<String> saveEmployee({
    required String actingEmployeeId,
    String? id,
    required String name,
    required String code,
    String? password,
    required String role,
    required bool active,
  }) {
    return _unwrapAsync(() async {
      final result = await _client.rpc('admin_save_employee', params: {
        'p_acting_employee_id': actingEmployeeId,
        'p_id': id,
        'p_name': name,
        'p_code': code,
        'p_password': (password == null || password.isEmpty) ? null : password,
        'p_role': role,
        'p_active': active,
      });
      return result as String;
    });
  }

  Future<void> deleteEmployee({required String actingEmployeeId, required String targetId}) {
    return _unwrapAsync(() => _client.rpc('admin_delete_employee', params: {
          'p_acting_employee_id': actingEmployeeId,
          'p_target_id': targetId,
        }));
  }

  // ---------------- Products ----------------

  Future<List<Product>> getProducts({String? search, int limit = 50, int offset = 0}) {
    return _unwrapAsync(() async {
      final builder = _client.from('products').select();
      final filtered = (search != null && search.isNotEmpty) ? builder.ilike('name', '%$search%') : builder;
      final rows = await filtered.order('name').range(offset, offset + limit - 1);
      return (rows as List).map((r) => Product.fromMap(r as Map<String, dynamic>)).toList();
    });
  }

  Future<void> saveProduct(Product product) {
    return _unwrapAsync(() async {
      if (product.id == null) {
        await _client.from('products').insert(product.toMap());
      } else {
        await _client.from('products').update(product.toMap()).eq('id', product.id!);
      }
    });
  }

  Future<void> deleteProduct(String id) {
    return _unwrapAsync(() => _client.from('products').delete().eq('id', id));
  }

  Future<List<Product>> getLowStockProducts({int limit = 50}) {
    return _unwrapAsync(() async {
      final rows = await _client.rpc('low_stock_products', params: {'p_limit': limit}) as List;
      return rows.map((r) => Product.fromMap(r as Map<String, dynamic>)).toList();
    });
  }

  // ---------------- Customers / debts ----------------

  Future<List<MapEntry<Customer, double>>> getCustomerBalances() {
    return _unwrapAsync(() async {
      final rows = await _client.from('customer_balances').select().order('balance', ascending: false);
      return (rows as List).map((r) {
        final map = r as Map<String, dynamic>;
        final customer = Customer(id: map['customer_id'] as String, name: map['name'] as String, phone: map['phone'] as String? ?? '');
        return MapEntry(customer, (map['balance'] as num).toDouble());
      }).toList();
    });
  }

  Future<double> getTotalOutstandingDebt() {
    return _unwrapAsync(() async {
      final result = await _client.rpc('total_outstanding_debt');
      return (result as num).toDouble();
    });
  }

  Future<void> addManualDebt({required String customerName, required double amount, String note = ''}) {
    return _unwrapAsync(() => _client.rpc('add_manual_debt', params: {
          'p_customer_name': customerName,
          'p_amount': amount,
          'p_note': note,
        }));
  }

  Future<void> addDebtPayment({required String customerId, required double amount, String note = ''}) {
    return _unwrapAsync(() => _client.rpc('add_debt_payment', params: {
          'p_customer_id': customerId,
          'p_amount': amount,
          'p_note': note,
        }));
  }

  Future<List<DebtTransaction>> getTransactionsForCustomer(String customerId) {
    return _unwrapAsync(() async {
      final rows = await _client
          .from('debt_transactions')
          .select()
          .eq('customer_id', customerId)
          .order('date', ascending: false);
      return (rows as List).map((r) => DebtTransaction.fromMap(r as Map<String, dynamic>)).toList();
    });
  }

  // ---------------- Sales ----------------

  Future<String> createSale({required Sale sale, required List<SaleItem> items}) {
    return _unwrapAsync(() async {
      final result = await _client.rpc('create_sale', params: {
        'p_employee_id': sale.employeeId,
        'p_employee_name': sale.employeeName,
        'p_customer_name': sale.customerName,
        'p_paid_amount': sale.paidAmount,
        'p_note': sale.note,
        'p_items': items.map((i) => i.toRpcItem()).toList(),
      });
      return result as String;
    });
  }

  Future<List<Sale>> getSales({DateTime? from, DateTime? to, int limit = 50, int offset = 0}) {
    return _unwrapAsync(() async {
      var builder = _client.from('sales').select();
      if (from != null) builder = builder.gte('date', from.toIso8601String());
      if (to != null) builder = builder.lte('date', to.toIso8601String());
      final rows = await builder.order('date', ascending: false).range(offset, offset + limit - 1);
      return (rows as List).map((r) => Sale.fromMap(r as Map<String, dynamic>)).toList();
    });
  }

  Future<List<SaleItem>> getSaleItems(String saleId) {
    return _unwrapAsync(() async {
      final rows = await _client.from('sale_items').select().eq('sale_id', saleId);
      return (rows as List).map((r) => SaleItem.fromMap(r as Map<String, dynamic>)).toList();
    });
  }

  // ---------------- Reports ----------------

  Future<ReportSummary> getReportSummary({DateTime? from, DateTime? to}) {
    return _unwrapAsync(() async {
      final rows = await _client.rpc('report_summary', params: {
        'p_from': from?.toIso8601String(),
        'p_to': to?.toIso8601String(),
      }) as List;
      final row = rows.first as Map<String, dynamic>;
      return ReportSummary(
        totalSales: (row['total_sales'] as num).toDouble(),
        totalProfit: (row['total_profit'] as num).toDouble(),
      );
    });
  }

  Future<List<MapEntry<String, double>>> getTopProducts({int limit = 5, DateTime? from, DateTime? to}) {
    return _unwrapAsync(() async {
      final rows = await _client.rpc('report_top_products', params: {
        'p_from': from?.toIso8601String(),
        'p_to': to?.toIso8601String(),
        'p_limit': limit,
      }) as List;
      return rows
          .map((r) => r as Map<String, dynamic>)
          .map((r) => MapEntry(r['product_name'] as String, (r['total_qty'] as num).toDouble()))
          .toList();
    });
  }
}
