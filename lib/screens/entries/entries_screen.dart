import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../models/people.dart';
import '../../models/sales.dart';
import '../../services/auth_service.dart';
import '../../utils/pharmacy_scope.dart';
import '../../widgets/sale_shortcut_action.dart';

enum _Period { today, month, year }

class EntriesScreen extends StatelessWidget {
  const EntriesScreen({super.key});

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final auth = context.watch<AuthService>();
    final employees = data.employees.items
        .where((e) => e.active)
        .where((e) => matchesPharmacy(e.pharmacyId, auth.currentPharmacyId))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final salesToday = data.sales.items.where((s) => _isToday(s.createdAt)).toList();
    final totalSalesToday = salesToday.fold(0.0, (sum, s) => sum + s.total);
    final totalDebtToday = salesToday
        .where((s) => s.paymentType == PaymentType.credit)
        .fold(0.0, (sum, s) => sum + s.total);

    return Scaffold(
      appBar: AppBar(title: const Text('الدخولات'), actions: const [SaleShortcutAction()]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'مبيعات اليوم',
                    value: '${totalSalesToday.toStringAsFixed(0)} د.ع',
                    color: const Color(0xFFE0407A),
                    icon: Icons.point_of_sale_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'دين اليوم',
                    value: '${totalDebtToday.toStringAsFixed(0)} د.ع',
                    color: Colors.orange,
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('اضغط اسم الموظف لتفاصيل مبيعاته بأي فترة تختارها',
                  style: TextStyle(fontSize: 12, color: Color(0xFF4A4A4A), fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: employees.isEmpty
                ? const Center(child: Text('ما في موظفين بعد'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: employees.length,
                    itemBuilder: (_, i) {
                      final e = employees[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(child: Icon(e.isAdmin ? Icons.admin_panel_settings : Icons.person)),
                          title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => _EmployeeSalesSheet(employee: e),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showInvoiceDetails(BuildContext context, SaleInvoice sale) async {
  final profitPct = sale.total == 0 ? 0.0 : (sale.profit / sale.total) * 100;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('تفاصيل الفاتورة'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${sale.createdAt.year}/${sale.createdAt.month}/${sale.createdAt.day} — ${sale.paymentType.labelAr}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const Divider(),
              ...sale.items.map((it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(it.name)),
                        Text('${it.quantity.toStringAsFixed(0)} × ${it.price.toStringAsFixed(0)}'),
                        const SizedBox(width: 8),
                        Text('${it.lineTotal.toStringAsFixed(0)} د.ع',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${sale.total.toStringAsFixed(0)} د.ع', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الربح'),
                  Text('${sale.profit.toStringAsFixed(0)} د.ع (${profitPct.toStringAsFixed(1)}%)',
                      style: const TextStyle(color: Color(0xFF0B6B4F), fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
      ],
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color, required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

/// Per-employee sales breakdown: total sold, cash vs debt, invoice count —
/// for whichever period (اليوم/الشهر/السنة) is picked.
class _EmployeeSalesSheet extends StatefulWidget {
  const _EmployeeSalesSheet({required this.employee});
  final Employee employee;

  @override
  State<_EmployeeSalesSheet> createState() => _EmployeeSalesSheetState();
}

class _EmployeeSalesSheetState extends State<_EmployeeSalesSheet> {
  _Period _period = _Period.today;

  bool _inPeriod(DateTime d) {
    final now = DateTime.now();
    switch (_period) {
      case _Period.today:
        return d.year == now.year && d.month == now.month && d.day == now.day;
      case _Period.month:
        return d.year == now.year && d.month == now.month;
      case _Period.year:
        return d.year == now.year;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final sales = data.sales.items
        .where((s) => s.employeeId == widget.employee.id)
        .where((s) => _inPeriod(s.createdAt))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totalSold = sales.fold(0.0, (sum, s) => sum + s.total);
    final cashSold = sales
        .where((s) => s.paymentType == PaymentType.cash || s.paymentType == PaymentType.master)
        .fold(0.0, (sum, s) => sum + s.total);
    final debtSold = sales
        .where((s) => s.paymentType == PaymentType.credit)
        .fold(0.0, (sum, s) => sum + s.total);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.employee.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            SegmentedButton<_Period>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Period.today, label: Text('اليوم')),
                ButtonSegment(value: _Period.month, label: Text('الشهر')),
                ButtonSegment(value: _Period.year, label: Text('السنة')),
              ],
              selected: {_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'إجمالي المبيعات',
                    value: '${totalSold.toStringAsFixed(0)} د.ع',
                    color: const Color(0xFFE0407A),
                    icon: Icons.point_of_sale_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'بيع كاش/ماستر',
                    value: '${cashSold.toStringAsFixed(0)} د.ع',
                    color: Colors.green,
                    icon: Icons.payments_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'بيع بالدين',
                    value: '${debtSold.toStringAsFixed(0)} د.ع',
                    color: Colors.orange,
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'عدد الفواتير',
                    value: '${sales.length}',
                    color: Colors.indigo,
                    icon: Icons.list_alt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('الفواتير', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: sales.isEmpty
                  ? const Center(child: Text('ما في فواتير بهذه الفترة', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: sales.length,
                      itemBuilder: (_, i) {
                        final s = sales[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            s.paymentType == PaymentType.credit ? Icons.receipt_long_outlined : Icons.payments_outlined,
                            size: 18,
                            color: s.paymentType == PaymentType.credit ? Colors.orange : Colors.green,
                          ),
                          title: Text('${s.total.toStringAsFixed(0)} د.ع'),
                          subtitle: Text('${s.createdAt.year}/${s.createdAt.month}/${s.createdAt.day}'),
                          trailing: const Icon(Icons.chevron_left, size: 18),
                          onTap: () => _showInvoiceDetails(context, s),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
