import 'package:flutter/foundation.dart';

import '../db/db_helper.dart';
import '../models/employee.dart';

class Session extends ChangeNotifier {
  Employee? _employee;

  Employee? get employee => _employee;
  bool get isLoggedIn => _employee != null;
  bool get isAdmin => _employee?.isAdmin ?? false;

  Future<String?> login(String code, String password) async {
    if (code.trim().isEmpty || password.isEmpty) {
      return 'الرجاء إدخال الرمز وكلمة المرور';
    }
    final employee = await DbHelper.instance.authenticate(code.trim(), password);
    if (employee == null) {
      return 'الرمز أو كلمة المرور غير صحيحة';
    }
    _employee = employee;
    notifyListeners();
    return null;
  }

  void logout() {
    _employee = null;
    notifyListeners();
  }
}
