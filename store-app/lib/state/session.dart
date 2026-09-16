import 'package:flutter/foundation.dart';

import '../models/employee.dart';
import '../services/backend_service.dart';

class AppSession extends ChangeNotifier {
  Employee? _employee;

  Employee? get employee => _employee;
  bool get isLoggedIn => _employee != null;
  bool get isAdmin => _employee?.isAdmin ?? false;

  Future<String?> login(String code, String password) async {
    if (code.trim().isEmpty || password.isEmpty) {
      return 'الرجاء إدخال الرمز وكلمة المرور';
    }
    try {
      final employee = await BackendService.instance.authenticate(code.trim(), password);
      if (employee == null) {
        return 'الرمز أو كلمة المرور غير صحيحة';
      }
      _employee = employee;
      notifyListeners();
      return null;
    } on BackendException catch (e) {
      return e.message;
    } catch (e) {
      return 'تعذر الاتصال بالخادم، تحقق من الإنترنت وحاول مجدداً';
    }
  }

  void logout() {
    _employee = null;
    notifyListeners();
  }
}
