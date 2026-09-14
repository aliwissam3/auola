import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'db/db_helper.dart';
import 'screens/login_screen.dart';
import 'state/session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  DbHelper.initPlatform();
  runApp(const StoreApp());
}

class StoreApp extends StatelessWidget {
  const StoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => Session(),
      child: MaterialApp(
        title: 'إدارة المحل',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        theme: ThemeData(
          colorSchemeSeed: Colors.teal,
          useMaterial3: true,
        ),
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const LoginScreen(),
      ),
    );
  }
}
