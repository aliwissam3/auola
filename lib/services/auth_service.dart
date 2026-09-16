import 'package:flutter/foundation.dart';
import '../data/app_data.dart';
import '../data/id_gen.dart';
import '../models/attendance.dart';
import '../models/people.dart';
import '../models/operations.dart';

enum CheckOutResult { success, notFound, noOpenShift }
enum CheckInResult { success, notFound, alreadyCheckedIn }

/// Tracks the logged-in employee. Login is intentionally simple (matched
/// against the local [AppData] employee list) since this is a
/// single-store offline app, not a networked multi-tenant system.
class AuthService extends ChangeNotifier {
  AuthService(this._data);

  final AppData _data;

  /// Holds the logged-in employee's id, not the Employee object itself —
  /// permissions/isAdmin are read fresh from [_data] on every check (see
  /// [currentEmployee] below). Without this, editing an employee's
  /// permissions (or another device pushing a Supabase sync update)
  /// would never apply to an already-logged-in session until they
  /// manually logged out and back in.
  String? _currentId;
  Employee? get currentEmployee => _currentId == null ? null : _data.employees.byId(_currentId!);
  bool get isLoggedIn => _currentId != null;
  bool get isAdmin => currentEmployee?.isAdmin ?? false;
  /// The pharmacy the logged-in employee belongs to — every pharmacy-
  /// scoped screen filters its data to this id. Null means the employee
  /// has no pharmacy assigned yet (legacy data, or a setup mistake) —
  /// screens treat that as "see everything" rather than "see nothing",
  /// so nobody's data silently disappears because of an unset field.
  String? get currentPharmacyId => currentEmployee?.pharmacyId;

  /// Single unified login: name + code, for admin and staff alike - the
  /// role (and which screens they can reach) comes from the matched
  /// employee's own [Employee.isAdmin]/permissions, not from picking a
  /// different login form. The code matches either the employee's
  /// password or their barcode, so the same field works whether it was
  /// typed or scanned.
  Future<bool> loginWithNameAndCode(String name, String code) async {
    final trimmedName = name.trim();
    final trimmedCode = code.trim();
    if (trimmedName.isEmpty || trimmedCode.isEmpty) return false;
    final match = _data.employees.items.where(
      (e) =>
          e.active &&
          e.name == trimmedName &&
          (e.password == trimmedCode ||
              (e.barcode != null && e.barcode == trimmedCode)),
    );
    if (match.isEmpty) return false;
    _currentId = match.first.id;
    await _logEntry();
    notifyListeners();
    return true;
  }

  /// Barcode-only login (USB/Bluetooth scanner typing into a single
  /// field, or a phone camera scan) - no name needed since a barcode
  /// already belongs to exactly one employee.
  Future<bool> loginWithBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return false;
    final match = _data.employees.items.where(
      (e) => e.active && e.barcode != null && e.barcode == trimmed,
    );
    if (match.isEmpty) return false;
    _currentId = match.first.id;
    await _logEntry();
    notifyListeners();
    return true;
  }

  Future<void> _logEntry() async {
    final emp = currentEmployee;
    if (emp == null) return;
    await _data.entries.upsert(EntryLog(
      id: newId(),
      employeeId: emp.id,
      employeeName: emp.name,
    ));
    // Attendance now starts the instant someone logs into the system —
    // no separate button to press. If they somehow still have an open
    // shift from before (e.g. the app closed without a clean logout),
    // reuse it instead of starting a second overlapping one.
    final alreadyOpen = _data.attendance.items.any(
      (a) => a.employeeId == emp.id && a.checkOut == null,
    );
    if (!alreadyOpen) {
      await _data.attendance.upsert(AttendanceRecord(
        id: newId(),
        employeeId: emp.id,
        employeeName: emp.name,
        checkIn: DateTime.now(),
      ));
    }
  }

  /// Clocks in whoever matches [name]+[code], independent of whatever
  /// app session is currently logged in on this device — a pharmacy
  /// normally has several people physically present and working at
  /// once, but only one of them is ever "logged into" the app itself at
  /// a time (the one running the register). This lets every one of them
  /// still have their own attendance shift tracked, entered right on the
  /// Attendance screen without disturbing whoever's actually using the
  /// app right now.
  Future<CheckInResult> checkInByCode(String name, String code) async {
    final trimmedName = name.trim();
    final trimmedCode = code.trim();
    if (trimmedName.isEmpty || trimmedCode.isEmpty) {
      return CheckInResult.notFound;
    }
    final match = _data.employees.items.where(
      (e) =>
          e.active &&
          e.name == trimmedName &&
          (e.password == trimmedCode ||
              (e.barcode != null && e.barcode == trimmedCode)),
    );
    if (match.isEmpty) return CheckInResult.notFound;
    final emp = match.first;
    final alreadyOpen = _data.attendance.items.any(
      (a) => a.employeeId == emp.id && a.checkOut == null,
    );
    if (alreadyOpen) return CheckInResult.alreadyCheckedIn;
    await _data.attendance.upsert(AttendanceRecord(
      id: newId(),
      employeeId: emp.id,
      employeeName: emp.name,
      checkIn: DateTime.now(),
    ));
    return CheckInResult.success;
  }

  /// Closes whoever's open shift matches [name]+[code] — entered right
  /// on the Attendance screen rather than only ever happening as a side
  /// effect of the app-wide "تسجيل الخروج" menu action, per the
  /// pharmacist's own request: attendance should end with a deliberate
  /// check-out, code and all, the same way check-in starts with a
  /// deliberate login. If that employee happens to be the one currently
  /// logged into this device, their whole session ends too (there's no
  /// reason to stay logged in once clocked out) — the second element of
  /// the result says whether that happened, so the caller knows whether
  /// to return to the login screen.
  Future<(CheckOutResult result, bool loggedOutSession)> checkOutByCode(
    String name,
    String code,
  ) async {
    final trimmedName = name.trim();
    final trimmedCode = code.trim();
    if (trimmedName.isEmpty || trimmedCode.isEmpty) {
      return (CheckOutResult.notFound, false);
    }
    final match = _data.employees.items.where(
      (e) =>
          e.active &&
          e.name == trimmedName &&
          (e.password == trimmedCode ||
              (e.barcode != null && e.barcode == trimmedCode)),
    );
    if (match.isEmpty) return (CheckOutResult.notFound, false);
    final emp = match.first;
    final open = _data.attendance.items.where(
      (a) => a.employeeId == emp.id && a.checkOut == null,
    );
    if (open.isEmpty) return (CheckOutResult.noOpenShift, false);
    for (final record in open) {
      record.checkOut = DateTime.now();
      await _data.attendance.upsert(record);
    }
    final loggedOutSession = _currentId == emp.id;
    if (loggedOutSession) _currentId = null;
    notifyListeners();
    return (CheckOutResult.success, loggedOutSession);
  }

  Future<void> logout() async {
    final emp = currentEmployee;
    _currentId = null;
    notifyListeners();
    if (emp != null) {
      // Close whatever attendance record is still open for this employee
      // — logging out of the system IS clocking out, nothing else to do.
      final open = _data.attendance.items.where(
        (a) => a.employeeId == emp.id && a.checkOut == null,
      );
      for (final record in open) {
        record.checkOut = DateTime.now();
        await _data.attendance.upsert(record);
      }
    }
  }

  bool can(bool Function(EmployeePermissions p) check) {
    final emp = currentEmployee;
    if (emp == null) return false;
    if (emp.isAdmin) return true;
    return check(emp.permissions);
  }
}
