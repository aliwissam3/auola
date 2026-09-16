import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../models/people.dart';
import '../../services/auth_service.dart';
import '../../utils/web_deep_link.dart';
import '../../widgets/employee_barcode_dialog.dart';

/// All employee login codes shown together on one page, each with its
/// own QR code and an inline editable code field — the same "أكواد
/// الكاشير" overview the reference app had, instead of only being able
/// to see one employee's code at a time via the edit dialog.
class CashierCodesScreen extends StatelessWidget {
  const CashierCodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final auth = context.watch<AuthService>();
    final me = auth.currentEmployee;
    final cashiers = data.employees.items.where((e) => !e.isAdmin).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('أكواد الدخول')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (me != null && me.isAdmin) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red),
                      SizedBox(width: 6),
                      Text('كود الأدمن — لا تعطيه للموظفين',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CodeCard(employee: me, accent: Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'أكواد الموظفين — هذي التي تُعطى لهم',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (cashiers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('لا يوجد موظفون غير الأدمن بعد', textAlign: TextAlign.center),
                  )
                else
                  ...cashiers.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _CodeCard(employee: e, accent: Colors.green),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatefulWidget {
  const _CodeCard({required this.employee, required this.accent});
  final Employee employee;
  final Color accent;

  @override
  State<_CodeCard> createState() => _CodeCardState();
}

class _CodeCardState extends State<_CodeCard> {
  late final _code = TextEditingController(text: widget.employee.barcode ?? '');

  @override
  Widget build(BuildContext context) {
    final e = widget.employee;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(e.isAdmin ? Icons.admin_panel_settings : Icons.person, color: widget.accent),
              const SizedBox(width: 6),
              Text(e.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          if (e.barcode != null && e.barcode!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: bw.BarcodeWidget(
                barcode: bw.Barcode.qrCode(),
                data: buildLoginLink(e.barcode!, employeeId: e.id),
                width: 150,
                height: 150,
              ),
            )
          else
            const Text('لا يوجد كود بعد', style: TextStyle(color: Color(0xFF4A4A4A), fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  decoration: const InputDecoration(labelText: 'كود الدخول', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final data = context.read<AppData>();
                  e.barcode = _code.text.trim().isEmpty ? null : _code.text.trim();
                  await data.employees.upsert(e);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم تحديث كود ${e.name}')),
                  );
                },
                child: const Text('حفظ'),
              ),
              IconButton(
                tooltip: 'طباعة البطاقة',
                icon: const Icon(Icons.print_outlined),
                onPressed: e.barcode == null || e.barcode!.isEmpty
                    ? null
                    : () => printEmployeeCard(e, e.barcode!),
              ),
              IconButton(
                tooltip: 'توليد كود جديد',
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  final newCode = '${100000 + (DateTime.now().microsecondsSinceEpoch % 900000)}';
                  setState(() => _code.text = newCode);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
