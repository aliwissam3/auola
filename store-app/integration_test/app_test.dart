import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'package:store_app/db/db_helper.dart';
import 'package:store_app/main.dart';

Future<void> _resetDatabase() async {
  final dir = await getApplicationSupportDirectory();
  final dbFile = File(join(dir.path, 'store_app.db'));
  if (await dbFile.exists()) await dbFile.delete();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login, add product, sell with partial payment, see debt and report', (tester) async {
    DbHelper.initPlatform();
    await _resetDatabase();

    await tester.pumpWidget(const StoreApp());
    await tester.pumpAndSettle();

    // --- Login as the default admin ---
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));
    await tester.enterText(textFields.at(0), '1111');
    await tester.enterText(textFields.at(1), '1111');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    // Home shell loaded, on the Products tab by default.
    expect(find.text('لا توجد منتجات بعد'), findsOneWidget);

    // --- Add a product ---
    await tester.tap(find.text('إضافة منتج'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'اسم المنتج'), 'شاي');
    await tester.enterText(find.widgetWithText(TextFormField, 'سعر الشراء'), '1000');
    await tester.enterText(find.widgetWithText(TextFormField, 'سعر البيع'), '1500');
    await tester.enterText(find.widgetWithText(TextFormField, 'الكمية'), '10');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('شاي'), findsOneWidget);
    expect(find.textContaining('الكمية: 10'), findsOneWidget);

    // --- Go to Sales tab and create a sale with a partial payment ---
    await tester.tap(find.text('المبيعات'));
    await tester.pumpAndSettle();

    // Tap the product to add it to the cart.
    await tester.tap(find.text('شاي').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('1500 × 1 = 1500'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'اسم الزبون (اختياري إلا عند وجود دين)'), 'أحمد');
    await tester.enterText(
      find.widgetWithText(TextField, 'المبلغ المدفوع (اتركه فارغاً للدفع الكامل)'),
      '500',
    );

    await tester.tap(find.text('إتمام البيع'));
    await tester.pumpAndSettle();

    expect(find.text('تم حفظ عملية البيع بنجاح'), findsOneWidget);

    // Cart cleared and stock decremented.
    expect(find.text('السلة فارغة، اختر منتجات من القائمة'), findsOneWidget);
    expect(find.textContaining('متوفر: 9'), findsOneWidget);

    // --- Debts tab should show Ahmed owing 1000 ---
    await tester.tap(find.text('الديون'));
    await tester.pumpAndSettle();

    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text('1000'), findsWidgets);

    // --- Reports tab should reflect the sale total and profit ---
    await tester.tap(find.text('التقارير'));
    await tester.pumpAndSettle();

    expect(find.text('1500'), findsOneWidget); // total sales today
    expect(find.text('500'), findsWidgets); // profit (1500 - 1000) appears somewhere

    // --- Settings tab (admin-only) should be visible and allow adding an employee ---
    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('إضافة موظف'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'اسم الموظف'), 'سارة');
    await tester.enterText(find.widgetWithText(TextFormField, 'رمز الدخول (يجب أن يكون فريداً)'), '2222');
    await tester.enterText(find.widgetWithText(TextFormField, 'كلمة المرور'), '2222');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('سارة'), findsOneWidget);

    // --- Log out and log back in as the new cashier; Settings must be hidden ---
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    final loginFields = find.byType(TextField);
    await tester.enterText(loginFields.at(0), '2222');
    await tester.enterText(loginFields.at(1), '2222');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    expect(find.text('الإعدادات'), findsNothing);
  });
}
