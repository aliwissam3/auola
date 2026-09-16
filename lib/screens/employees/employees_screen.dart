import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../data/id_gen.dart';
import '../../models/people.dart';
import '../../widgets/employee_barcode_dialog.dart';
import 'cashier_codes_screen.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  String? _filterPharmacyId;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final pharmacies = data.pharmacies.items;
    final employees = data.employees.items
        .where((e) => _filterPharmacyId == null || e.pharmacyId == _filterPharmacyId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الموظفين والصلاحيات'),
        actions: [
          IconButton(
            tooltip: 'أكواد الدخول (كل الموظفين)',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CashierCodesScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEmployeeDialog(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('إضافة موظف'),
      ),
      body: Column(
        children: [
          if (pharmacies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: DropdownButtonFormField<String?>(
                value: _filterPharmacyId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'فلترة حسب الصيدلية',
                  prefixIcon: Icon(Icons.store_mall_directory_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('كل الصيدليات')),
                  ...pharmacies.map((ph) => DropdownMenuItem<String?>(value: ph.id, child: Text(ph.name))),
                ],
                onChanged: (v) => setState(() => _filterPharmacyId = v),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: employees.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final e = employees[i];
                final pharmacyName = e.pharmacyId == null
                    ? null
                    : pharmacies.where((ph) => ph.id == e.pharmacyId).firstOrNull?.name;
                final perms = <String>[
                  if (e.isAdmin) 'كل الصلاحيات (أدمن)',
                  if (!e.isAdmin && e.permissions.sales) 'البيع',
                  if (!e.isAdmin && e.permissions.reports) 'التقارير',
                  if (!e.isAdmin && e.permissions.debts) 'الديون',
                  if (!e.isAdmin && e.permissions.lists) 'القوائم',
                  if (!e.isAdmin && e.permissions.viewCost) 'عرض الكوست',
                  if (!e.isAdmin && e.permissions.viewProfit) 'عرض الأرباح',
                  if (!e.isAdmin && e.permissions.edit) 'التعديل',
                ];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: e.active ? null : Colors.grey.shade300,
                      child: Icon(e.isAdmin ? Icons.admin_panel_settings : Icons.person),
                    ),
                    title: Text(e.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${e.phone.isEmpty ? 'بدون هاتف' : e.phone} • ${perms.isEmpty ? 'بدون صلاحيات' : perms.join('، ')}'
                          '${pharmacyName != null ? ' • $pharmacyName' : ''}',
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: e.barcode == null || e.barcode!.isEmpty
                              ? null
                              : () => showEmployeeBarcodeDialog(context, e),
                          child: Row(
                            children: [
                              const Icon(Icons.qr_code_2, size: 14, color: Color(0xFF4A4A4A)),
                              const SizedBox(width: 4),
                              Text(
                                e.barcode == null || e.barcode!.isEmpty
                                    ? 'بدون كود دخول سريع'
                                    : 'كود الدخول: ${e.barcode} (اضغط لعرض الباركود)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: e.barcode == null || e.barcode!.isEmpty
                                      ? Colors.grey
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!e.active)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Chip(label: Text('موقوف'), visualDensity: VisualDensity.compact),
                          ),
                        IconButton(
                          tooltip: 'عرض / طباعة الباركود',
                          icon: const Icon(Icons.qr_code_2),
                          onPressed: e.barcode == null || e.barcode!.isEmpty
                              ? null
                              : () => showEmployeeBarcodeDialog(context, e),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showEmployeeDialog(context, employee: e),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => data.employees.delete(e.id),
                        ),
                      ],
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

  Future<void> _showEmployeeDialog(BuildContext context, {Employee? employee}) async {
    final data = context.read<AppData>();
    final name = TextEditingController(text: employee?.name ?? '');
    final phone = TextEditingController(text: employee?.phone ?? '');
    final password = TextEditingController(text: employee?.password ?? '');
    // A new employee gets a unique login code right away — the admin can
    // still regenerate or type a custom one before saving.
    // New employees start with no code — they set their own the first
    // time they try to log in (see LoginScreen), rather than the admin
    // assigning one for them. Editing an existing employee still shows
    // whatever code they already chose, and admin can still generate
    // one here manually if an employee needs a reset.
    final barcode = TextEditingController(text: employee?.barcode ?? '');
    bool isAdmin = employee?.isAdmin ?? false;
    bool active = employee?.active ?? true;
    String? pharmacyId = employee?.pharmacyId;
    var perms = EmployeePermissions(
      reports: employee?.permissions.reports ?? false,
      debts: employee?.permissions.debts ?? false,
      lists: employee?.permissions.lists ?? false,
      sales: employee?.permissions.sales ?? true,
      viewCost: employee?.permissions.viewCost ?? false,
      viewProfit: employee?.permissions.viewProfit ?? false,
      edit: employee?.permissions.edit ?? false,
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(employee == null ? 'إضافة موظف' : 'تعديل موظف'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
                  TextField(controller: phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
                  if (data.pharmacies.items.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      value: pharmacyId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'الصيدلية',
                        prefixIcon: Icon(Icons.store_mall_directory_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('بدون تحديد')),
                        ...data.pharmacies.items
                            .map((ph) => DropdownMenuItem<String?>(value: ph.id, child: Text(ph.name))),
                      ],
                      onChanged: (v) => setState(() => pharmacyId = v),
                    ),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'كلمة المرور'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: barcode,
                          decoration: const InputDecoration(
                            labelText: 'كود الدخول السريع',
                            helperText: 'رقم يحدده الموظف لتسجيل الدخول به مباشرة',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'توليد كود',
                        icon: const Icon(Icons.qr_code_2),
                        onPressed: () => setState(() => barcode.text = _generateCode()),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('حساب مفعّل'),
                    value: active,
                    onChanged: (v) => setState(() => active = v),
                  ),
                  SwitchListTile(
                    title: const Text('صلاحيات أدمن كاملة'),
                    value: isAdmin,
                    onChanged: (v) => setState(() => isAdmin = v),
                  ),
                  if (!isAdmin) ...[
                    const Divider(),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text('الصلاحيات', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    _permCheck('البيع', perms.sales, (v) => setState(() => perms.sales = v)),
                    _permCheck('التقارير', perms.reports, (v) => setState(() => perms.reports = v)),
                    _permCheck('الديون', perms.debts, (v) => setState(() => perms.debts = v)),
                    _permCheck('القوائم', perms.lists, (v) => setState(() => perms.lists = v)),
                    _permCheck('عرض الكوست', perms.viewCost, (v) => setState(() => perms.viewCost = v)),
                    _permCheck('عرض الأرباح', perms.viewProfit, (v) => setState(() => perms.viewProfit = v)),
                    _permCheck('التعديل', perms.edit, (v) => setState(() => perms.edit = v)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                await data.employees.upsert(Employee(
                  id: employee?.id ?? newId(),
                  name: name.text.trim(),
                  phone: phone.text.trim(),
                  password: password.text,
                  barcode: barcode.text.trim().isEmpty ? null : barcode.text.trim(),
                  isAdmin: isAdmin,
                  active: active,
                  permissions: perms,
                  pharmacyId: pharmacyId,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  /// A short numeric code (like a PIN) is easier for an employee to be
  /// told and remember than a long generated barcode string.
  String _generateCode() {
    final rand = DateTime.now().microsecondsSinceEpoch % 900000;
    return '${100000 + rand}';
  }

  Widget _permCheck(String label, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (v) => onChanged(v ?? false),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
