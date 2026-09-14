import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/db_helper.dart';
import '../models/employee.dart';
import '../state/session.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Employee> _employees = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final employees = await DbHelper.instance.getEmployees();
    if (!mounted) return;
    setState(() {
      _employees = employees;
      _loading = false;
    });
  }

  Future<void> _openEditor({Employee? employee}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EmployeeEditorDialog(employee: employee),
    );
    if (saved == true) _reload();
  }

  Future<void> _confirmDelete(Employee employee) async {
    if (employee.isAdmin) {
      final otherAdmins = await DbHelper.instance.countAdmins(excludingId: employee.id);
      if (otherAdmins == 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن حذف آخر حساب مدير في النظام')),
        );
        return;
      }
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف الموظف "${employee.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DbHelper.instance.deleteEmployee(employee.id!);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentId = context.read<Session>().employee?.id;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('إضافة موظف'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'إدارة الموظفين — لكل موظف رمز دخول وكلمة مرور خاصة به',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _employees.length,
                    itemBuilder: (context, index) {
                      final e = _employees[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: e.isAdmin ? Colors.teal.shade100 : Colors.blueGrey.shade100,
                            child: Icon(e.isAdmin ? Icons.admin_panel_settings : Icons.person_outline),
                          ),
                          title: Text('${e.name}${e.id == currentId ? " (أنت)" : ""}'),
                          subtitle: Text(
                            'الرمز: ${e.code} • ${e.isAdmin ? "مدير" : "كاشير"}${e.active ? "" : " • معطل"}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _openEditor(employee: e),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _confirmDelete(e),
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
}

class _EmployeeEditorDialog extends StatefulWidget {
  final Employee? employee;
  const _EmployeeEditorDialog({this.employee});

  @override
  State<_EmployeeEditorDialog> createState() => _EmployeeEditorDialogState();
}

class _EmployeeEditorDialogState extends State<_EmployeeEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _password;
  late String _role;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _name = TextEditingController(text: e?.name ?? '');
    _code = TextEditingController(text: e?.code ?? '');
    _password = TextEditingController();
    _role = e?.role ?? 'cashier';
    _active = e?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.employee == null && _password.text.isEmpty) {
      setState(() => _error = 'كلمة المرور مطلوبة للموظف الجديد');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final employee = Employee(
        id: widget.employee?.id,
        name: _name.text.trim(),
        code: _code.text.trim(),
        passwordHash: widget.employee?.passwordHash ?? '',
        role: _role,
        active: _active,
        createdAt: widget.employee?.createdAt ?? DateTime.now(),
      );
      await DbHelper.instance.saveEmployee(
        employee,
        newPassword: _password.text.isEmpty ? null : _password.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'حدث خطأ أثناء الحفظ');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.employee == null ? 'إضافة موظف' : 'تعديل موظف'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'اسم الموظف'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(labelText: 'رمز الدخول (يجب أن يكون فريداً)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: widget.employee == null ? 'كلمة المرور' : 'كلمة مرور جديدة (اتركها فارغة للإبقاء عليها)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'الصلاحية'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('مدير (كل الصلاحيات)')),
                    DropdownMenuItem(value: 'cashier', child: Text('كاشير (بدون الإعدادات)')),
                  ],
                  onChanged: (value) => setState(() => _role = value ?? 'cashier'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('حساب مفعل'),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
