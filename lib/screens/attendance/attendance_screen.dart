import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../models/attendance.dart';
import '../../models/people.dart';
import '../../services/auth_service.dart';
import '../../utils/pharmacy_scope.dart';
import '../../widgets/sale_shortcut_action.dart';
import '../login/login_screen.dart';

/// A shift starts automatically the instant an employee logs into the
/// system, and can also be started/ended manually right here — name +
/// code, same as logging in — via the "تسجيل حضور"/"تسجيل انصراف"
/// buttons below. That manual path is independent of whoever's actual
/// app session is currently open on this device: a pharmacy normally
/// has several people physically present at once, but the app itself
/// only ever has one of them "logged in" (the one running the
/// register) — this lets every one of them still clock in/out on the
/// same shared device without disturbing that session. Tap a name to
/// see their attendance/sales/hours for whichever period you pick.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

enum _Period { today, month, year, day }

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
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

    final employeeIds = employees.map((e) => e.id).toSet();
    final todayRecords = data.attendance.items
        .where((a) => _isToday(a.checkIn))
        .where((a) => employeeIds.contains(a.employeeId))
        .toList();

    final openByEmployee = <String, AttendanceRecord>{};
    for (final r in todayRecords) {
      if (r.checkOut == null && !openByEmployee.containsKey(r.employeeId)) {
        openByEmployee[r.employeeId] = r;
      }
    }
    final workingNowCount = openByEmployee.length;
    final totalHoursToday = todayRecords.fold<Duration>(
      Duration.zero,
      (sum, r) => sum + (r.workedDuration ?? DateTime.now().difference(r.checkIn)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('الحضور والانصراف'), actions: const [SaleShortcutAction()]),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'check-in',
            onPressed: () => _checkInDialog(context),
            icon: const Icon(Icons.login_rounded),
            label: const Text('تسجيل حضور'),
            backgroundColor: Colors.green.shade600,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'check-out',
            onPressed: () => _checkOutDialog(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل انصراف'),
            backgroundColor: Colors.red.shade600,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    color: Colors.green,
                    icon: Icons.play_circle_outline,
                    label: 'يعملون الآن',
                    value: '$workingNowCount',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    color: Colors.indigo,
                    icon: Icons.timelapse,
                    label: 'إجمالي الساعات اليوم',
                    value: _fmtDuration(totalHoursToday),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    color: Colors.brown,
                    icon: Icons.list_alt,
                    label: 'سجلات اليوم',
                    value: '${todayRecords.length}',
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'الحضور يبدأ ويوكف تلقائياً بتسجيل الدخول والخروج من النظام — اضغط اسم الموظف لتفاصيله',
                style: TextStyle(fontSize: 12, color: Color(0xFF4A4A4A), fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: employees.length,
              itemBuilder: (_, i) {
                final emp = employees[i];
                final open = openByEmployee[emp.id];
                final working = open != null;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: working ? Colors.green.withValues(alpha: 0.08) : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: working ? Colors.green : Colors.grey.shade300,
                      child: Icon(working ? Icons.login : Icons.logout,
                          color: working ? Colors.white : Colors.grey.shade700, size: 20),
                    ),
                    title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(working ? 'شغال الآن' : 'غير مسجل دخول حالياً'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => _openDetails(context, data, emp),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetails(BuildContext context, AppData data, Employee emp) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EmployeeAttendanceSheet(employee: emp),
    );
  }

  Future<void> _checkInDialog(BuildContext context) async {
    final auth = context.read<AuthService>();
    final name = TextEditingController();
    final code = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل حضور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: code,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'الرمز / كود الدخول'),
              onSubmitted: (_) => _submitCheckIn(ctx, auth, name.text, code.text),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => _submitCheckIn(ctx, auth, name.text, code.text),
            child: const Text('تسجيل الحضور'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCheckIn(
    BuildContext dialogContext,
    AuthService auth,
    String name,
    String code,
  ) async {
    final result = await auth.checkInByCode(name, code);
    if (!dialogContext.mounted) return;
    switch (result) {
      case CheckInResult.notFound:
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(content: Text('الاسم أو الرمز غير صحيح')),
        );
        return;
      case CheckInResult.alreadyCheckedIn:
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هذا الموظف مسجّل دخول أصلاً')),
        );
        return;
      case CheckInResult.success:
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل الحضور')),
        );
    }
  }

  Future<void> _checkOutDialog(BuildContext context) async {
    final auth = context.read<AuthService>();
    final name = TextEditingController();
    final code = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل انصراف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: code,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'الرمز / كود الدخول'),
              onSubmitted: (_) => _submitCheckOut(ctx, auth, name.text, code.text),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => _submitCheckOut(ctx, auth, name.text, code.text),
            child: const Text('تسجيل الانصراف'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCheckOut(
    BuildContext dialogContext,
    AuthService auth,
    String name,
    String code,
  ) async {
    final (result, loggedOutSession) = await auth.checkOutByCode(name, code);
    if (!dialogContext.mounted) return;
    switch (result) {
      case CheckOutResult.notFound:
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(content: Text('الاسم أو الرمز غير صحيح')),
        );
        return;
      case CheckOutResult.noOpenShift:
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هذا الموظف مو مسجّل دخول حالياً')),
        );
        return;
      case CheckOutResult.success:
        Navigator.pop(dialogContext);
        if (loggedOutSession) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تسجيل الانصراف')),
          );
        }
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.color, required this.icon, required this.label, required this.value});
  final Color color;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Bottom sheet: pick "اليوم / الشهر / السنة", see that employee's
/// attendance records, total hours, total sales, and invoice count for
/// the chosen period.
class _EmployeeAttendanceSheet extends StatefulWidget {
  const _EmployeeAttendanceSheet({required this.employee});
  final Employee employee;

  @override
  State<_EmployeeAttendanceSheet> createState() => _EmployeeAttendanceSheetState();
}

class _EmployeeAttendanceSheetState extends State<_EmployeeAttendanceSheet> {
  _Period _period = _Period.today;
  DateTime _pickedDay = DateTime.now();

  bool _inPeriod(DateTime d) {
    final now = DateTime.now();
    switch (_period) {
      case _Period.today:
        return d.year == now.year && d.month == now.month && d.day == now.day;
      case _Period.month:
        return d.year == now.year && d.month == now.month;
      case _Period.year:
        return d.year == now.year;
      case _Period.day:
        return d.year == _pickedDay.year && d.month == _pickedDay.month && d.day == _pickedDay.day;
    }
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _pickedDay = picked;
        _period = _Period.day;
      });
    }
  }

  String _fmtDateTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.year}/${d.month}/${d.day} — $h:$m $period';
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final records = data.attendance.items
        .where((a) => a.employeeId == widget.employee.id)
        .where((a) => _inPeriod(a.checkIn))
        .toList()
      ..sort((a, b) => b.checkIn.compareTo(a.checkIn));

    final totalWorked = records.fold<Duration>(
      Duration.zero,
      (sum, r) => sum + (r.workedDuration ?? DateTime.now().difference(r.checkIn)),
    );

    final sales = data.sales.items
        .where((s) => s.employeeId == widget.employee.id)
        .where((s) => _inPeriod(s.createdAt))
        .toList();
    final totalSales = sales.fold(0.0, (sum, s) => sum + s.total);

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
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<_Period>(
                    showSelectedIcon: false,
                    emptySelectionAllowed: true,
                    segments: const [
                      ButtonSegment(value: _Period.today, label: Text('اليوم')),
                      ButtonSegment(value: _Period.month, label: Text('الشهر')),
                      ButtonSegment(value: _Period.year, label: Text('السنة')),
                    ],
                    selected: _period == _Period.day ? const {} : {_period},
                    onSelectionChanged: (s) => setState(() => _period = s.first),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'اختر يوماً محدداً',
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: _pickDay,
                ),
              ],
            ),
            if (_period == _Period.day) ...[
              const SizedBox(height: 8),
              Text(
                'اليوم المحدد: ${_pickedDay.year}/${_pickedDay.month}/${_pickedDay.day}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    color: const Color(0xFFE0407A),
                    icon: Icons.point_of_sale_outlined,
                    label: 'مبيعاته',
                    value: '${totalSales.toStringAsFixed(0)} د.ع',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    color: Colors.indigo,
                    icon: Icons.timelapse,
                    label: 'ساعات العمل',
                    value: _fmtDuration(totalWorked),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    color: Colors.brown,
                    icon: Icons.receipt_long_outlined,
                    label: 'عدد الفواتير',
                    value: '${sales.length}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('سجل الحضور', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: records.isEmpty
                  ? const Center(child: Text('ما في سجلات بهذه الفترة', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: records.length,
                      itemBuilder: (_, i) {
                        final r = records[i];
                        final worked = r.workedDuration;
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.login, size: 18),
                          title: Text(_fmtDateTime(r.checkIn)),
                          subtitle: Text(
                            r.checkOut == null
                                ? 'لسا شغال'
                                : 'خروج: ${_fmtDateTime(r.checkOut!)} — ${_fmtDuration(worked!)}',
                          ),
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
