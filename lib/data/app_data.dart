import 'package:flutter/foundation.dart';
import '../models/attendance.dart';
import '../models/card_visibility.dart';
import '../models/operations.dart';
import '../models/people.dart';
import '../models/product.dart';
import '../models/section_shortcut.dart';
import '../models/purchases.dart';
import '../models/sales.dart';
import '../models/supplier_list.dart';
import 'id_gen.dart';
import 'supabase_repository.dart';

/// Aggregates every local "table" the app needs and offers a few derived
/// queries (balances, low-stock, expiring batches) that span more than one
/// repository. Registered once in main.dart and shared via
/// ChangeNotifierProvider.
///
/// Extends ChangeNotifier and forwards every repository's own
/// notifyListeners() into its own — a screen calling context.watch<AppData>()
/// then correctly rebuilds on ANY table change, exactly as every screen in
/// this app already assumes. Without this, AppData had no way to notify
/// anything on its own (a plain object isn't Listenable), and screens only
/// ever appeared to update when some unrelated main.dart-level rebuild
/// happened to also touch them — a manually-maintained list that had
/// already drifted out of sync with the repositories below (several,
/// including attendance, were missing from it entirely), silently breaking
/// updates in whatever screen relied on exactly those tables.
class AppData extends ChangeNotifier {
  AppData() {
    for (final repo in _all) {
      repo.addListener(notifyListeners);
    }
  }

  @override
  void dispose() {
    for (final repo in _all) {
      repo.removeListener(notifyListeners);
    }
    super.dispose();
  }

  final products = SupabaseRepository<Product>(
    boxKey: 'products',
    toJson: (p) => p.toJson(),
    fromJson: Product.fromJson,
    idOf: (p) => p.id,
  );

  final batches = SupabaseRepository<Batch>(
    boxKey: 'batches',
    toJson: (b) => b.toJson(),
    fromJson: Batch.fromJson,
    idOf: (b) => b.id,
  );

  final employees = SupabaseRepository<Employee>(
    boxKey: 'employees',
    toJson: (e) => e.toJson(),
    fromJson: Employee.fromJson,
    idOf: (e) => e.id,
  );

  final customers = SupabaseRepository<Customer>(
    boxKey: 'customers',
    toJson: (c) => c.toJson(),
    fromJson: Customer.fromJson,
    idOf: (c) => c.id,
  );

  final suppliers = SupabaseRepository<Supplier>(
    boxKey: 'suppliers',
    toJson: (s) => s.toJson(),
    fromJson: Supplier.fromJson,
    idOf: (s) => s.id,
  );

  final reps = SupabaseRepository<Rep>(
    boxKey: 'reps',
    toJson: (r) => r.toJson(),
    fromJson: Rep.fromJson,
    idOf: (r) => r.id,
  );

  final pharmacies = SupabaseRepository<Pharmacy>(
    boxKey: 'pharmacies',
    toJson: (p) => p.toJson(),
    fromJson: Pharmacy.fromJson,
    idOf: (p) => p.id,
  );

  final sales = SupabaseRepository<SaleInvoice>(
    boxKey: 'sales',
    toJson: (s) => s.toJson(),
    fromJson: SaleInvoice.fromJson,
    idOf: (s) => s.id,
  );

  final purchases = SupabaseRepository<Purchase>(
    boxKey: 'purchases',
    toJson: (p) => p.toJson(),
    fromJson: Purchase.fromJson,
    idOf: (p) => p.id,
  );

  final debtPayments = SupabaseRepository<DebtPayment>(
    boxKey: 'debt_payments',
    toJson: (d) => d.toJson(),
    fromJson: DebtPayment.fromJson,
    idOf: (d) => d.id,
  );

  final supplierPayments = SupabaseRepository<SupplierPayment>(
    boxKey: 'supplier_payments',
    toJson: (d) => d.toJson(),
    fromJson: SupplierPayment.fromJson,
    idOf: (d) => d.id,
  );

  final deficits = SupabaseRepository<DeficitItem>(
    boxKey: 'deficits',
    toJson: (d) => d.toJson(),
    fromJson: DeficitItem.fromJson,
    idOf: (d) => d.id,
  );

  final returns = SupabaseRepository<ReturnItem>(
    boxKey: 'returns',
    toJson: (r) => r.toJson(),
    fromJson: ReturnItem.fromJson,
    idOf: (r) => r.id,
  );

  /// Products customers brought back (راجعة من الزبون) — kept separate
  /// from [returns], which is stock going back to the *supplier*.
  final customerReturns = SupabaseRepository<CustomerReturn>(
    boxKey: 'customer_returns',
    toJson: (r) => r.toJson(),
    fromJson: CustomerReturn.fromJson,
    idOf: (r) => r.id,
  );

  /// Photographed purchase lists/invoices, filed per supplier.
  final supplierLists = SupabaseRepository<SupplierList>(
    boxKey: 'supplier_lists',
    toJson: (l) => l.toJson(),
    fromJson: SupplierList.fromJson,
    idOf: (l) => l.id,
  );

  final movements = SupabaseRepository<StockMovement>(
    boxKey: 'movements',
    toJson: (m) => m.toJson(),
    fromJson: StockMovement.fromJson,
    idOf: (m) => m.id,
  );

  final expenses = SupabaseRepository<Expense>(
    boxKey: 'expenses',
    toJson: (e) => e.toJson(),
    fromJson: Expense.fromJson,
    idOf: (e) => e.id,
  );

  final entries = SupabaseRepository<EntryLog>(
    boxKey: 'entries',
    toJson: (e) => e.toJson(),
    fromJson: EntryLog.fromJson,
    idOf: (e) => e.id,
  );

  final customLists = SupabaseRepository<CustomList>(
    boxKey: 'custom_lists',
    toJson: (l) => l.toJson(),
    fromJson: CustomList.fromJson,
    idOf: (l) => l.id,
  );

  final attendance = SupabaseRepository<AttendanceRecord>(
    boxKey: 'attendance',
    toJson: (a) => a.toJson(),
    fromJson: AttendanceRecord.fromJson,
    idOf: (a) => a.id,
  );

  /// Which dashboard cards an admin has turned off — synced so the
  final cardVisibility = SupabaseRepository<CardVisibility>(
    boxKey: 'card_visibility',
    toJson: (c) => c.toJson(),
    fromJson: CardVisibility.fromJson,
    idOf: (c) => c.id,
  );

  bool isCardHidden(String cardId) =>
      cardVisibility.items.where((c) => c.id == cardId).any((c) => c.hidden);

  /// App sections (dashboard card ids) picked as one-tap quick-switch
  /// buttons shown on the POS screen — see [SectionShortcut].
  final sectionShortcuts = SupabaseRepository<SectionShortcut>(
    boxKey: 'section_shortcuts',
    toJson: (s) => s.toJson(),
    fromJson: SectionShortcut.fromJson,
    idOf: (s) => s.id,
  );

  bool isSectionShortcut(String cardId) =>
      sectionShortcuts.items.any((s) => s.id == cardId);

  List<SupabaseRepository> get _all => [
        products,
        batches,
        employees,
        customers,
        suppliers,
        reps,
        pharmacies,
        sales,
        purchases,
        debtPayments,
        supplierPayments,
        deficits,
        returns,
        customerReturns,
        supplierLists,
        movements,
        expenses,
        entries,
        customLists,
        attendance,
        cardVisibility,
        sectionShortcuts,
      ];

  Future<void> init() async {
    // Loaded in parallel, not one at a time: each repo's own network
    // call is already bounded by its own timeout (see
    // SupabaseRepository.load), but 21 repositories awaited sequentially
    // would still multiply that into minutes of hang on a fully offline
    // machine — this app must reach its first screen in a few seconds
    // regardless of network state.
    await Future.wait(_all.map((repo) => repo.load()));
    await _seedDemoData();
  }

  /// Manually pulls every table fresh from Supabase right now — the
  /// dashboard's refresh button calls this, as a fallback for whenever
  /// realtime sync hasn't reflected a change made from another device
  /// yet (e.g. a sale made from a phone that logged in over the LAN-QR
  /// feature).
  Future<void> refreshAll() => Future.wait(_all.map((repo) => repo.refresh()));

  Future<void> _seedDemoData() async {
    if (employees.items.isEmpty) {
      await employees.upsert(Employee(
        id: newId(),
        name: 'المدير',
        phone: '07700000000',
        password: 'admin123',
        barcode: 'EMP-ADMIN',
        isAdmin: true,
        permissions: EmployeePermissions(
          reports: true,
          debts: true,
          lists: true,
          sales: true,
          viewCost: true,
          viewProfit: true,
          edit: true,
        ),
      ));
    }

    if (pharmacies.items.isEmpty) {
      await pharmacies.upsert(Pharmacy(id: newId(), name: 'الصيدلية الرئيسية'));
    }

    if (suppliers.items.isEmpty) {
      await suppliers.upsertAll([
        Supplier(id: newId(), name: 'مذخر بغداد الطبي', phone: '07901111111'),
        Supplier(id: newId(), name: 'مذخر الرافدين', phone: '07902222222'),
      ]);
    }

    if (products.items.isEmpty) {
      await products.upsertAll([
        Product(
          id: newId(),
          name: 'بنادول اكسترا',
          barcode: '6291041500213',
          purchasePrice: 1000,
          salePrice: 1500,
          unit: ProductUnit.strip,
          quantity: 40,
          lowStockThreshold: 10,
        ),
        Product(
          id: newId(),
          name: 'اوجمنتين 1 غم',
          barcode: '6291041500220',
          purchasePrice: 3500,
          salePrice: 5000,
          unit: ProductUnit.packet,
          quantity: 5,
          lowStockThreshold: 8,
        ),
        Product(
          id: newId(),
          name: 'فيتامين سي فوار',
          barcode: '6291041500237',
          purchasePrice: 2000,
          salePrice: 3000,
          unit: ProductUnit.piece,
          quantity: 25,
          lowStockThreshold: 10,
        ),
      ]);
    }

    if (customers.items.isEmpty) {
      await customers.upsert(Customer(
        id: newId(),
        name: 'صيدلية الأمل (جملة)',
        phone: '07903333333',
        creditLimit: 500000,
      ));
    }
  }

  // ---------------- Derived queries ----------------

  double customerBalance(String customerId) {
    final invoicesDebt = sales.items
        .where((s) => s.customerId == customerId && s.paymentType == PaymentType.credit)
        .fold(0.0, (sum, s) => sum + s.remaining);
    final paid = debtPayments.items
        .where((p) => p.customerId == customerId)
        .fold(0.0, (sum, p) => sum + p.amount);
    return invoicesDebt - paid;
  }

  double supplierBalance(String supplierId) {
    final purchasesDebt = purchases.items
        .where((p) => p.supplierId == supplierId)
        .fold(0.0, (sum, p) => sum + p.remaining);
    final paid = supplierPayments.items
        .where((p) => p.supplierId == supplierId)
        .fold(0.0, (sum, p) => sum + p.amount + p.discountAmount);
    return purchasesDebt - paid;
  }

  List<Product> get lowStockProducts =>
      products.items.where((p) => p.isLowStock).toList();

  /// Batches expiring within [withinDays] days from now (defaults to each
  /// product's own alert window when [withinDays] is null).
  List<Batch> expiringBatches({int? withinDays, int? year, int? month}) {
    final now = DateTime.now();
    final hasExplicitFilter = withinDays != null || year != null || month != null;
    return batches.items.where((b) {
      final exp = b.expiryDate;
      if (exp == null || b.quantity <= 0) return false;
      if (year != null && exp.year != year) return false;
      if (month != null && exp.month != month) return false;
      if (withinDays != null) return exp.difference(now).inDays <= withinDays;
      if (hasExplicitFilter) return true;
      final product = products.byId(b.productId);
      final alertDays = product?.expiryAlertDays ?? 60;
      return exp.difference(now).inDays <= alertDays;
    }).toList()
      ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
  }

  int get deficitCount => deficits.items.length;
}
