import 'package:flutter/material.dart';

import '../db/db_helper.dart';
import '../models/customer.dart';
import '../models/debt_transaction.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  List<MapEntry<Customer, double>> _balances = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final balances = await DbHelper.instance.getCustomerBalances();
    if (!mounted) return;
    setState(() {
      _balances = balances;
      _loading = false;
    });
  }

  Future<void> _addManualDebt() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddDebtDialog(),
    );
    if (saved == true) _reload();
  }

  Future<void> _openCustomer(Customer customer, double balance) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _CustomerDebtDialog(customer: customer, balance: balance),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final total = _balances.fold<double>(0.0, (sum, e) => sum + e.value);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManualDebt,
        icon: const Icon(Icons.add),
        label: const Text('إضافة دين'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.teal.shade50,
            padding: const EdgeInsets.all(16),
            child: Text(
              'إجمالي الديون المستحقة: ${_fmt(total)}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _balances.isEmpty
                    ? const Center(child: Text('لا توجد ديون حالياً'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _balances.length,
                        itemBuilder: (context, index) {
                          final entry = _balances[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                              title: Text(entry.key.name),
                              subtitle: entry.key.phone.isNotEmpty ? Text(entry.key.phone) : null,
                              trailing: Text(
                                _fmt(entry.value),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                              onTap: () => _openCustomer(entry.key, entry.value),
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

class _AddDebtDialog extends StatefulWidget {
  const _AddDebtDialog();

  @override
  State<_AddDebtDialog> createState() => _AddDebtDialogState();
}

class _AddDebtDialogState extends State<_AddDebtDialog> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final amount = double.tryParse(_amount.text);
    if (name.isEmpty) {
      setState(() => _error = 'أدخل اسم الزبون');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'أدخل مبلغاً صحيحاً');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await DbHelper.instance.addManualDebt(customerName: name, amount: amount, note: _note.text.trim());
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة دين جديد'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم الزبون')),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'المبلغ'),
            ),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)')),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('حفظ')),
      ],
    );
  }
}

class _CustomerDebtDialog extends StatefulWidget {
  final Customer customer;
  final double balance;
  const _CustomerDebtDialog({required this.customer, required this.balance});

  @override
  State<_CustomerDebtDialog> createState() => _CustomerDebtDialogState();
}

class _CustomerDebtDialogState extends State<_CustomerDebtDialog> {
  List<DebtTransaction> _transactions = [];
  bool _loading = true;
  final _paymentController = TextEditingController();
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final txns = await DbHelper.instance.getTransactionsForCustomer(widget.customer.id!);
    if (!mounted) return;
    setState(() {
      _transactions = txns;
      _loading = false;
    });
  }

  Future<void> _addPayment() async {
    final amount = double.tryParse(_paymentController.text);
    if (amount == null || amount <= 0) return;
    await DbHelper.instance.addDebtPayment(customerId: widget.customer.id!, amount: amount);
    _paymentController.clear();
    _changed = true;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.customer.name),
      content: SizedBox(
        width: 400,
        height: 420,
        child: Column(
          children: [
            Text('الرصيد الحالي: ${_fmt(widget.balance)}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _paymentController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'تسجيل دفعة', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _addPayment, child: const Text('دفع')),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final t = _transactions[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            t.isCharge ? Icons.arrow_upward : Icons.arrow_downward,
                            color: t.isCharge ? Colors.red : Colors.green,
                          ),
                          title: Text(t.isCharge ? 'دين جديد' : 'دفعة'),
                          subtitle: Text('${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}${t.note.isNotEmpty ? " • ${t.note}" : ""}'),
                          trailing: Text(_fmt(t.amount)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, _changed), child: const Text('إغلاق')),
      ],
    );
  }
}

String _fmt(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}
