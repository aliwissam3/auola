import 'package:flutter_test/flutter_test.dart';

import 'package:store_app/main.dart';

void main() {
  testWidgets('Shows a setup message when Supabase credentials are not configured', (WidgetTester tester) async {
    // This test never calls Supabase.initialize (same as a fresh checkout
    // with the placeholder values still in lib/config/supabase_config.dart),
    // so the app should guide the user to configure it instead of crashing.
    await tester.pumpWidget(const StoreApp());
    await tester.pump();

    expect(find.text('إعداد الاتصال بالخادم غير مكتمل'), findsOneWidget);
  });
}
