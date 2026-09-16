import 'package:flutter/foundation.dart';
import '../data/id_gen.dart';
import '../screens/pos/cart_tab.dart';

/// Owns every open POS cart/invoice tab for the whole app session (not
/// just one screen instance), so leaving the POS screen — to check the
/// dashboard, debts, etc. — and coming back later restores exactly what
/// was left in progress instead of starting over.
class PosCartService extends ChangeNotifier {
  final List<CartTab> carts = [CartTab(id: newId(), name: 'فاتورة 1')];
  int active = 0;

  CartTab get current => carts[active];

  void addCart() {
    carts.add(CartTab(id: newId(), name: 'فاتورة ${carts.length + 1}'));
    active = carts.length - 1;
    notifyListeners();
  }

  void closeCart(int index) {
    if (carts.length == 1) return;
    carts.removeAt(index);
    if (active >= carts.length) active = carts.length - 1;
    notifyListeners();
  }

  void setActive(int index) {
    active = index;
    notifyListeners();
  }

  void replaceCurrent(CartTab fresh) {
    carts[active] = fresh;
    notifyListeners();
  }

  /// Call after mutating [current]'s fields/items in place, to rebuild
  /// listeners without swapping the CartTab instance itself.
  void touch() => notifyListeners();
}
