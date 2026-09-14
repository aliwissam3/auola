import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:store_app/main.dart';

void main() {
  testWidgets('Login screen shows the app title', (WidgetTester tester) async {
    await tester.pumpWidget(const StoreApp());
    await tester.pump();

    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.byIcon(Icons.storefront), findsOneWidget);
  });
}
