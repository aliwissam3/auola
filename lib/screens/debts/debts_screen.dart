import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../data/id_gen.dart';
import '../../models/operations.dart';
import '../../models/people.dart';
import '../../models/product.dart';
import '../../models/sales.dart';
import '../../services/auth_service.dart';
import '../../utils/arabic.dart';
import '../../utils/pharmacy_scope.dart';
import '../../widgets/sale_shortcut_action.dart';
import '../lists/sale_return_sheet.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  String _search = '';
  Customer? _selected;
  bool _newestFirst = true;
  bool _showPaidOff = false;

  DateTime _lastActivity(AppData data, Customer c) {
    DateTime latest = c.createdAt;
    for (final s in data.sales.items) {
      if (s.customerId == c.id && s.createdAt.isAfter(latest)) latest = s.createdAt;
    }
    for (final p in data.debtPayments.items) {
      if (p.customerId == c.id && p.createdAt.isAfter(latest)) latest = p.createdAt;
    }
    return latest;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final auth = context.watch<AuthService>();
    // A customer "had a debt" if they ever had a credit sale — so a fully
    // settled balance of 0 still shows up under "الديون المسددة" instead
    // of just vanishing from both lists.
    bool everHadDebt(Customer c) =>
        data.sales.items.any((s) => s.customerId == c.id && s.paymentType == PaymentType.credit);
    final customers = data.customers.items
        .where((c) => matchesPharmacy(c.pharmacyId, auth.currentPharmacyId))
        .where((c) => arabicContains(c.name, _search) || c.phone.contains(_search))
        .where((c) => _showPaidOff
            ? (data.customerBalance(c.id) <= 0 && everHadDebt(c))
            : data.customerBalance(c.id) > 0)
        .toList()
      ..sort((a, b) => _newestFirst
          ? _lastActivity(data, b).compareTo(_lastActivity(data, a))
          : _lastActivity(data, a).compareTo(_lastActivity(data, b)));

    final wide = MediaQuery.of(context).size.width > 900;
    final now = DateTime.now();

    final totalDebt = data.customers.items
        .map((c) => data.customerBalance(c.id))
        .where((b) => b > 0)
        .fold(0.0, (s, b) => s + b);
    final debtorsCount = data.customers.items
        .where((c) => data.customerBalance(c.id) > 0)
        .length;
    final monthDebt = data.sales.items
        .where((s) =>
            s.paymentType == PaymentType.credit &&
            s.createdAt.year == now.year &&
            s.createdAt.month == now.month)
        .fold(0.0, (s, inv) => s + inv.total);
    final monthPaid = data.debtPayments.items
        .where((p) => p.createdAt.year == now.year && p.createdAt.month == now.month)
        .fold(0.0, (s, p) => s + p.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ديون المراجعين'),
        actions: [
          const SaleShortcutAction(),
          IconButton(
            icon: Icon(_newestFirst ? Icons.south : Icons.north),
            tooltip: _newestFirst ? 'الأحدث أولاً' : 'الأقدم أولاً',
            onPressed: () => setState(() => _newestFirst = !_newestFirst),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'إضافة مراجع',
            onPressed: () => _showAddCustomerDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: _StatChip(
                    label: 'إجمالي الديون',
                    value: '${totalDebt.toStringAsFixed(0)} د.ع',
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatChip(
                    label: 'عدد المدينين',
                    value: '$debtorsCount',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatChip(
                    label: 'دين هذا الشهر',
                    value: '${monthDebt.toStringAsFixed(0)} د.ع',
                    color: Colors.deepOrange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatChip(
                    label: 'تسديد هذا الشهر',
                    value: '${monthPaid.toStringAsFixed(0)} د.ع',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('الديون الحالية'),
                    selected: !_showPaidOff,
                    onSelected: (_) => setState(() {
                      _showPaidOff = false;
                      _selected = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('الديون المسددة'),
                    selected: _showPaidOff,
                    onSelected: (_) => setState(() {
                      _showPaidOff = true;
                      _selected = null;
                    }),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'بحث عن مراجع',
                          ),
                          onChanged: (v) => setState(() => _search = v),
                        ),
                      ),
                      Expanded(
                  child: ListView.separated(
                    itemCount: customers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = customers[i];
                      final balance = data.customerBalance(c.id);
                      final overdue = c.dueDate != null &&
                          c.dueDate!.isBefore(DateTime.now()) &&
                          balance > 0;
                      return ListTile(
                        selected: _selected?.id == c.id,
                        title: Text(c.name),
                        subtitle: Text(
                          c.phone.isEmpty ? 'بدون رقم هاتف' : c.phone,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: c.locked ? Colors.red.shade100 : null,
                          child: Icon(c.locked ? Icons.lock_outline : Icons.person_outline),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${balance.toStringAsFixed(0)} د.ع',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: balance > 0 ? Colors.red : Colors.green,
                              ),
                            ),
                            if (overdue)
                              const Text('متأخر السداد',
                                  style: TextStyle(color: Colors.red, fontSize: 11)),
                          ],
                        ),
                        onTap: () => setState(() => _selected = c),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (wide) const VerticalDivider(width: 1),
          if (wide)
            Expanded(
              flex: 2,
              child: _selected == null
                  ? const Center(child: Text('اختر مراجعاً لعرض التفاصيل'))
                  : _CustomerPanel(customer: _selected!, key: ValueKey(_selected!.id)),
            ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: !wide && _selected != null
          ? FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: _CustomerPanel(customer: _selected!),
                ),
              ),
              label: const Text('إدارة الدين'),
              icon: const Icon(Icons.receipt_long),
            )
          : null,
    );
  }

  Future<void> _showAddCustomerDialog(BuildContext context) async {
    final data = context.read<AppData>();
    final name = TextEditingController();
    final phone = TextEditingController();
    final openingDebt = TextEditingController();
    final limit = TextEditingController(text: '0');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مراجع جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'الهاتف')),
            TextField(
              controller: openingDebt,
              decoration: const InputDecoration(
                labelText: 'الدين الحالي (إن وجد)',
                helperText: 'مبلغ سبق أن استدانه هذا المراجع قبل تسجيله بالبرنامج',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: limit,
              decoration: const InputDecoration(labelText: 'الحد الأقصى المسموح بالدين (اختياري)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              final customer = Customer(
                id: newId(),
                name: name.text.trim(),
                phone: phone.text.trim(),
                creditLimit: double.tryParse(limit.text) ?? 0,
                pharmacyId: context.read<AuthService>().currentPharmacyId,
              );
              await data.customers.upsert(customer);
              // A brand-new customer has no sales/payments yet, so
              // data.customerBalance would read 0 and they'd vanish from
              // both the "current debts" and "paid off" lists — this is
              // the actual opening balance the customer already owed
              // before being registered, recorded as a real credit
              // invoice so it shows up immediately.
              final opening = double.tryParse(openingDebt.text) ?? 0;
              if (opening > 0) {
                await data.sales.upsert(SaleInvoice(
                  id: newId(),
                  employeeId: context.read<AuthService>().currentEmployee?.id ?? '',
                  items: [
                    SaleItem(
                      productId: 'manual-debt',
                      name: 'دين سابق عند التسجيل',
                      unit: ProductUnit.piece,
                      quantity: 1,
                      price: opening,
                    ),
                  ],
                  customerId: customer.id,
                  paymentType: PaymentType.credit,
                  paidAmount: 0,
                ));
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() => _selected = customer);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _CustomerPanel extends StatefulWidget {
  const _CustomerPanel({required this.customer, super.key});
  final Customer customer;

  @override
  State<_CustomerPanel> createState() => _CustomerPanelState();
}

class _CustomerPanelState extends State<_CustomerPanel> {
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final c = widget.customer;
    final balance = data.customerBalance(c.id);
    final history = <(String, double, DateTime, SaleInvoice?)>[
      ...data.sales.items
          .where((s) => s.customerId == c.id && s.paymentType == PaymentType.credit)
          .map((s) => ('فاتورة بيع', s.total, s.createdAt, s)),
      ...data.debtPayments.items
          .where((p) => p.customerId == c.id)
          .map((p) => ('تسديد', -p.amount, p.createdAt, null)),
    ]..sort((a, b) => b.$3.compareTo(a.$3));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(c.phone),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (balance > 0 ? Colors.red : Colors.green).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text('الرصيد الحالي', style: Theme.of(context).textTheme.bodySmall),
                Text('${balance.toStringAsFixed(0)} د.ع',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('قفل الدين (منع بيع جديد بالدين)'),
            value: c.locked,
            onChanged: (v) {
              c.locked = v;
              data.customers.upsert(c);
            },
          ),
          ListTile(
            title: const Text('الحد الأقصى المسموح بالدين'),
            trailing: Text(c.creditLimit > 0 ? '${c.creditLimit.toStringAsFixed(0)} د.ع' : 'بدون حد'),
          ),
          ListTile(
            title: const Text('موعد التسديد'),
            trailing: Text(c.dueDate == null
                ? 'غير محدد'
                : '${c.dueDate!.year}/${c.dueDate!.month}/${c.dueDate!.day}'),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: c.dueDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                c.dueDate = picked;
                await data.customers.upsert(c);
              }
            },
          ),
          const Divider(height: 24),
          const Text('إضافة دين جديد / تسديد', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'المبلغ'),
          ),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'ملاحظة'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة دين'),
                  onPressed: () async {
                    final amount = double.tryParse(_amount.text) ?? 0;
                    if (amount <= 0) return;
                    await data.sales.upsert(SaleInvoice(
                      id: newId(),
                      employeeId: context.read<AuthService>().currentEmployee?.id ?? '',
                      items: [
                        SaleItem(
                          productId: 'manual-debt',
                          name: _note.text.trim().isEmpty ? 'دين يدوي' : _note.text.trim(),
                          unit: ProductUnit.piece,
                          quantity: 1,
                          price: amount,
                        ),
                      ],
                      customerId: c.id,
                      paymentType: PaymentType.credit,
                      paidAmount: 0,
                      notes: _note.text.trim(),
                    ));
                    _amount.clear();
                    _note.clear();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('تسديد'),
                  onPressed: () async {
                    final amount = double.tryParse(_amount.text) ?? 0;
                    if (amount <= 0) return;
                    await data.debtPayments.upsert(DebtPayment(
                      id: newId(),
                      customerId: c.id,
                      amount: amount,
                      note: _note.text.trim(),
                    ));
                    _amount.clear();
                    _note.clear();
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          const Text('السجل', style: TextStyle(fontWeight: FontWeight.bold)),
          ...history.map((h) {
            final invoice = h.$4;
            // A credit invoice's own items ARE "the medicines taken on
            // credit" - shown here instead of a generic "فاتورة بيع"
            // label, and tappable to return/exchange (استبدال) one of
            // them, exactly like any other completed invoice.
            final itemsLabel = invoice?.items
                .map((it) => '${it.name} ×${it.quantity.toStringAsFixed(0)}')
                .join('، ');
            return ListTile(
              dense: true,
              title: Text(h.$1),
              subtitle: Text(
                itemsLabel == null || itemsLabel.isEmpty
                    ? '${h.$3.year}/${h.$3.month}/${h.$3.day}'
                    : '$itemsLabel\n${h.$3.year}/${h.$3.month}/${h.$3.day}',
              ),
              isThreeLine: itemsLabel != null && itemsLabel.isNotEmpty,
              trailing: Text(
                '${h.$2 > 0 ? '+' : ''}${h.$2.toStringAsFixed(0)}',
                style: TextStyle(color: h.$2 > 0 ? Colors.red : Colors.green),
              ),
              onTap: invoice == null
                  ? null
                  : () => showSaleReturnSheet(context, invoice),
            );
          }),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
