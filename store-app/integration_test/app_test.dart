// End-to-end test against a REAL Supabase backend — it exercises the same
// schema.sql your production project uses, so it only proves anything once
// you point it at one. It will not run against the placeholder values in
// lib/config/supabase_config.dart.
//
// Point it at a throwaway/test Supabase project (never production, since it
// creates real rows) and run:
//   flutter test integration_test/app_test.dart -d windows \
//     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=eyJ...
//
// On Android, run the same command with a connected device/emulator instead
// of -d windows.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:store_app/config/supabase_config.dart';
import 'package:store_app/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login, add product, sell with partial payment, see debt and report', (tester) async {
    if (!SupabaseConfig.isConfigured) {
      // ignore: avoid_print
      print('Skipping: SUPABASE_URL / SUPABASE_ANON_KEY were not provided via --dart-define.');
      return;
    }

    await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey);

    await tester.pumpWidget(const StoreApp());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // --- First run on this project: create the admin account ---
    if (find.text('إعداد المحل لأول مرة').evaluate().isNotEmpty) {
      await tester.enterText(find.widgetWithText(TextFormField, 'اسمك'), 'المدير');
      await tester.enterText(find.widgetWithText(TextFormField, 'رمز الدخول'), '1111');
      await tester.enterText(find.widgetWithText(TextFormField, 'كلمة المرور'), '1111');
      await tester.tap(find.text('إنشاء الحساب والدخول'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
    } else {
      // --- Otherwise log in as the admin created by a previous run ---
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '1111');
      await tester.enterText(textFields.at(1), '1111');
      await tester.tap(find.text('دخول'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    // Home shell loaded, on the Products tab by default.
    expect(find.text('المبيعات'), findsWidgets);

    // --- Add a product ---
    final uniqueName = 'شاي-${DateTime.now().microsecondsSinceEpoch}';
    await tester.tap(find.text('إضافة منتج'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'اسم المنتج'), uniqueName);
    await tester.enterText(find.widgetWithText(TextFormField, 'سعر الشراء'), '1000');
    await tester.enterText(find.widgetWithText(TextFormField, 'سعر البيع'), '1500');
    await tester.enterText(find.widgetWithText(TextFormField, 'الكمية'), '10');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text(uniqueName), findsOneWidget);

    // --- Go to Sales tab and create a sale with a partial payment ---
    await tester.tap(find.text('المبيعات').first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text(uniqueName).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'اسم الزبون (اختياري إلا عند وجود دين)'), 'أحمد-تجريبي');
    await tester.enterText(
      find.widgetWithText(TextField, 'المبلغ المدفوع (اتركه فارغاً للدفع الكامل)'),
      '500',
    );

    await tester.tap(find.text('إتمام البيع'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('تم حفظ عملية البيع بنجاح'), findsOneWidget);

    // --- Debts tab should show the customer owing 1000 ---
    await tester.tap(find.text('الديون'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('أحمد-تجريبي'), findsOneWidget);
  });
}
