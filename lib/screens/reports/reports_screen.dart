import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../models/sales.dart';
import '../../services/auth_service.dart';
import '../../utils/pharmacy_scope.dart';
import '../../widgets/sale_shortcut_action.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );
  String? _employeeFilter; // null = كل الموظفين

  bool _inRange(DateTime d) {
    final start = DateTime(_range.start.year, _range.start.month, _range.start.day);
    final end = DateTime(_range.end.year, _range.end.month, _range.end.day, 23, 59, 59);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final auth = context.watch<AuthService>();
    final canViewCost = auth.can((p) => p.viewCost);
    final canViewProfit = auth.can((p) => p.viewProfit);

    final salesInRange = data.sales.items
        .where((s) => matchesPharmacy(data.employees.byId(s.employeeId)?.pharmacyId, auth.currentPharmacyId))
        .where((s) => _inRange(s.createdAt))
        .toList();
    final purchasesInRange = data.purchases.items.where((p) => _inRange(p.purchaseDate)).toList();
    final newDebtInRange = salesInRange
        .where((s) => s.paymentType == PaymentType.credit)
        .fold(0.0, (sum, s) => sum + s.total);
    final paidInRange = data.debtPayments.items
        .where((p) => _inRange(p.createdAt))
        .fold(0.0, (sum, p) => sum + p.amount);
    final customersInRange = salesInRange
        .where((s) => s.customerId != null)
        .map((s) => s.customerId)
        .toSet()
        .length;
    final totalSales = salesInRange.fold(0.0, (sum, s) => sum + s.total);
    final totalPurchases = purchasesInRange.fold(0.0, (sum, p) => sum + p.total);
    final totalProfit = salesInRange.fold(0.0, (sum, s) => sum + s.profit);
    final profitPct = totalSales == 0 ? 0.0 : (totalProfit / totalSales) * 100;

    final inventoryValue = data.products.items
        .where((p) => matchesPharmacy(p.pharmacyId, auth.currentPharmacyId))
        .fold(0.0, (sum, p) => sum + (p.quantity * p.purchasePrice));
    final itemCount = data.products.items
        .where((p) => matchesPharmacy(p.pharmacyId, auth.currentPharmacyId))
        .length;
    final totalSupplierDebt = data.suppliers.items
        .fold(0.0, (sum, s) => sum + data.supplierBalance(s.id));
    final netValue = inventoryValue - totalSupplierDebt;

    // Per-employee sales breakdown for the same date range as everything
    // above — "all employees" (null) or one specific employee's numbers.
    final employeesForFilter = data.employees.items
        .where((e) => e.active)
        .where((e) => matchesPharmacy(e.pharmacyId, auth.currentPharmacyId))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final employeeSales = _employeeFilter == null
        ? salesInRange
        : salesInRange.where((s) => s.employeeId == _employeeFilter).toList();
    final employeeSalesTotal = employeeSales.fold(0.0, (sum, s) => sum + s.total);
    final employeeInvoiceCount = employeeSales.length;
    final employeeItemsSold = employeeSales.fold<int>(
      0,
      (sum, s) => sum + s.items.fold<int>(0, (isum, it) => isum + it.quantity.round()),
    );
    final employeeProfit = employeeSales.fold(0.0, (sum, s) => sum + s.profit);

    return Scaffold(
      appBar: AppBar(title: const Text('التقارير'), actions: const [SaleShortcutAction()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('اليوم'),
                onPressed: () {
                  final now = DateTime.now();
                  setState(() => _range = DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now));
                },
              ),
              ActionChip(
                label: const Text('أمس'),
                onPressed: () {
                  final y = DateTime.now().subtract(const Duration(days: 1));
                  setState(() => _range = DateTimeRange(start: DateTime(y.year, y.month, y.day), end: DateTime(y.year, y.month, y.day, 23, 59, 59)));
                },
              ),
              ActionChip(
                label: const Text('هذا الشهر'),
                onPressed: () {
                  final now = DateTime.now();
                  setState(() => _range = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now));
                },
              ),
              ActionChip(
                label: const Text('هذه السنة'),
                onPressed: () {
                  final now = DateTime.now();
                  setState(() => _range = DateTimeRange(start: DateTime(now.year, 1, 1), end: now));
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              '${_range.start.year}/${_range.start.month}/${_range.start.day} '
              '—  ${_range.end.year}/${_range.end.month}/${_range.end.day}',
            ),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                initialDateRange: _range,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _range = picked);
            },
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _ReportStat(label: 'مجموع المبيعات', value: totalSales, color: Colors.blue),
              _ReportStat(label: 'مجموع المشتريات', value: totalPurchases, color: Colors.purple),
              if (canViewProfit)
                _ReportStat(
                  label: 'الربح (${profitPct.toStringAsFixed(1)}%)',
                  value: totalProfit,
                  color: Colors.green,
                ),
              _ReportStat(label: 'دين جديد بالفترة', value: newDebtInRange, color: Colors.red),
              _ReportStat(label: 'تسديد بالفترة', value: paidInRange, color: Colors.green),
              _ReportStat(
                label: 'عدد المراجعين',
                value: customersInRange.toDouble(),
                color: Colors.orange,
                isCount: true,
              ),
              _ReportStat(
                label: 'عدد فواتير البيع',
                value: salesInRange.length.toDouble(),
                color: Colors.teal,
                isCount: true,
              ),
            ],
          ),
          const Divider(height: 40),
          const Text('مبيعات الموظفين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('اختر موظفاً لعرض مبيعاته بالفترة المحددة أعلاه، أو اتركه على "كل الموظفين"',
              style: TextStyle(fontSize: 12, color: Color(0xFF4A4A4A), fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _employeeFilter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'الموظف', prefixIcon: Icon(Icons.badge_outlined)),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('كل الموظفين')),
              ...employeesForFilter.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name))),
            ],
            onChanged: (v) => setState(() => _employeeFilter = v),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _ReportStat(label: 'مجموع المبيعات', value: employeeSalesTotal, color: Colors.pink),
              if (canViewProfit)
                _ReportStat(label: 'الربح', value: employeeProfit, color: Colors.green),
              _ReportStat(
                label: 'عدد الفواتير',
                value: employeeInvoiceCount.toDouble(),
                color: Colors.indigo,
                isCount: true,
              ),
              _ReportStat(
                label: 'عدد القطع المباعة',
                value: employeeItemsSold.toDouble(),
                color: Colors.brown,
                isCount: true,
              ),
            ],
          ),
          const Divider(height: 40),
          Text(canViewCost ? 'الجرد الكلي' : 'الجرد الكلي (بدون تفاصيل الكلفة)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                if (canViewCost) ...[
                  _kv('المبلغ الكلي لجرد المخزون', '${inventoryValue.toStringAsFixed(0)} د.ع'),
                  const Divider(),
                ],
                _kv('عدد الأيتمات', '$itemCount'),
                if (canViewCost) ...[
                  const Divider(),
                  _kv('مجموع ديون المذاخر الكلي', '${totalSupplierDebt.toStringAsFixed(0)} د.ع'),
                  const Divider(),
                  _kv(
                    'الفرق (الجرد - الديون)',
                    '${netValue.toStringAsFixed(0)} د.ع',
                    color: netValue >= 0 ? Colors.green : Colors.red,
                    bold: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  const _ReportStat({
    required this.label,
    required this.value,
    required this.color,
    this.isCount = false,
  });

  final String label;
  final double value;
  final Color color;
  final bool isCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(height: 4),
          Text(
            isCount ? value.toStringAsFixed(0) : '${value.toStringAsFixed(0)} د.ع',
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
