import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/app_data.dart';
import 'data/supabase_config.dart';
import 'services/auth_service.dart';
import 'services/connectivity_status.dart';
import 'services/local_web_server_service.dart';
import 'services/pos_cart_service.dart';
import 'services/settings_service.dart';
import 'services/store_account_service.dart';
import 'services/subscription_service.dart';
import 'theme/theme_provider.dart';

import 'screens/login/login_screen.dart';
import 'screens/store_auth/store_auth_screen.dart';
import 'screens/subscription/subscription_lock_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/pos/pos_screen.dart';
import 'screens/purchases/purchases_screen.dart';
import 'screens/debts/debts_screen.dart';
import 'screens/employees/cashier_codes_screen.dart';
import 'screens/employees/employees_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/deficits/deficits_screen.dart';
import 'screens/expiry/expiry_screen.dart';
import 'screens/reps/reps_screen.dart';
import 'screens/lists/lists_screen.dart';
import 'screens/returns/returns_screen.dart';
import 'screens/movement/movement_screen.dart';
import 'screens/settlements/settlements_screen.dart';
import 'screens/entries/entries_screen.dart';
import 'screens/pharmacies/pharmacies_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/attendance/attendance_screen.dart';
import 'screens/returns/customer_returns_screen.dart';
import 'widgets/permission_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // runApp() fires immediately and unconditionally so the engine always
  // paints *something* on the very first frame — every async setup step
  // (local storage reads, demo-data seeding) happens afterwards inside
  // _AppBootstrap, where a thrown error surfaces as a visible error
  // screen instead of silently preventing runApp() from ever being
  // called (which would otherwise show as a blank/white page).
  runApp(const _AppBootstrap());
}

/// Holds the three services the rest of the app depends on, built once
/// initialization succeeds.
class _AppServices {
  _AppServices(this.appData, this.authService, this.settingsService, this.subscriptionService);
  final AppData appData;
  final AuthService authService;
  final SettingsService settingsService;
  final SubscriptionService subscriptionService;
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late final Future<ThemeProvider> _coreFuture = _initCore();
  Future<_AppServices>? _servicesFuture;

  /// Setup that doesn't belong to any one pharmacy — must finish before
  /// even the register/sign-in screen can be shown (it needs a loaded
  /// theme, and Supabase.initialize() must run before anything touches
  /// StoreAccountService, which reads Supabase's own auth client).
  Future<ThemeProvider> _initCore() async {
    // Every repository's local cache lives in a Hive box - must be ready
    // before any repository's load() runs below.
    await Hive.initFlutter();

    // Cloud sync: connects once at startup, but this app must work with
    // zero internet access (offline flash-drive deployment), so a
    // missing/unreachable network must never block first paint. The
    // previous unguarded await could hang indefinitely with no internet
    // at all (not just a slow network) - bounded with a timeout and
    // swallowed here; individual repository loads fall back to an
    // empty/offline state on their own. 8s (was 3s) gives a phone on a
    // slower/higher-latency connection a real chance to finish the
    // handshake instead of being written off as "offline" before it
    // ever got a fair shot - a phone session that gives up here loses
    // ALL cloud sync silently for the rest of that session, since every
    // later Supabase call just throws and is swallowed the same way.
    //
    // A *previously* signed-in pharmacy's session is restored from local
    // storage by this same call without needing the network — only a
    // brand-new registration/sign-in needs live internet.
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.publishableKey,
      ).timeout(const Duration(seconds: 8));
      ConnectivityStatus.instance.markConnected();
    } catch (_) {
      // No internet / cloud unreachable - continue fully offline.
      ConnectivityStatus.instance.markDisconnected();
    }

    final themeProvider = ThemeProvider();
    await themeProvider.load();
    return themeProvider;
  }

  /// Everything that belongs to the specific pharmacy now signed in —
  /// only ever runs once [StoreAccountService.instance.isSignedIn] is
  /// true, since every repository's load() needs a store id to know
  /// whose data to fetch.
  Future<_AppServices> _initServices() async {
    final appData = AppData();
    await appData.init();

    final authService = AuthService(appData);

    final settingsService = SettingsService();
    await settingsService.load();

    final subscriptionService = SubscriptionService();
    await subscriptionService.load();

    // Best-effort: hosts this app's own web build over the LAN for the
    // "باركود" login-screen QR. Never blocks startup on failure (no
    // `build/web` yet, port busy, offline) — the QR button simply won't
    // show, same as before this existed.
    await LocalWebServerService.instance.start();

    return _AppServices(appData, authService, settingsService, subscriptionService);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ThemeProvider>(
      future: _coreFuture,
      builder: (context, coreSnapshot) {
        if (coreSnapshot.hasError) {
          return _BootstrapMaterialApp(
            child: _BootstrapMessage(
              icon: Icons.error_outline,
              iconColor: Colors.red,
              title: 'تعذّر تشغيل التطبيق',
              message: '${coreSnapshot.error}',
            ),
          );
        }
        if (coreSnapshot.connectionState != ConnectionState.done) {
          return const _BootstrapMaterialApp(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final themeProvider = coreSnapshot.data!;

        if (!StoreAccountService.instance.isSignedIn) {
          return ListenableBuilder(
            listenable: themeProvider,
            builder: (context, _) => MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: themeProvider.themeData,
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => Directionality(
                textDirection: TextDirection.rtl,
                child: SafeArea(child: child!),
              ),
              home: StoreAuthScreen(
                onAuthenticated: () => setState(() => _servicesFuture = _initServices()),
              ),
            ),
          );
        }

        _servicesFuture ??= _initServices();
        return FutureBuilder<_AppServices>(
          future: _servicesFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _BootstrapMaterialApp(
                child: _BootstrapMessage(
                  icon: Icons.error_outline,
                  iconColor: Colors.red,
                  title: 'تعذّر تشغيل التطبيق',
                  message: '${snapshot.error}',
                ),
              );
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const _BootstrapMaterialApp(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final services = snapshot.data!;
            return PharmacyManagerApp(
              appData: services.appData,
              themeProvider: themeProvider,
              authService: services.authService,
              settingsService: services.settingsService,
              subscriptionService: services.subscriptionService,
            );
          },
        );
      },
    );
  }
}

/// A minimal, self-contained MaterialApp used only for the splash/error
/// states — before the real themed app is available, widgets still need
/// a Directionality/Material ancestor to render at all.
class _BootstrapMaterialApp extends StatelessWidget {
  const _BootstrapMaterialApp({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, widget) => Directionality(
        textDirection: TextDirection.rtl,
        child: widget!,
      ),
      home: Scaffold(body: child),
    );
  }
}

class _BootstrapMessage extends StatelessWidget {
  const _BootstrapMessage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 48),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class PharmacyManagerApp extends StatelessWidget {
  PharmacyManagerApp({
    super.key,
    required this.appData,
    required this.themeProvider,
    required this.authService,
    required this.settingsService,
    required this.subscriptionService,
  });

  final AppData appData;
  final ThemeProvider themeProvider;
  final AuthService authService;
  final SettingsService settingsService;
  final SubscriptionService subscriptionService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppData>.value(value: appData),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<SettingsService>.value(value: settingsService),
        ChangeNotifierProvider<SubscriptionService>.value(value: subscriptionService),
        ChangeNotifierProvider<PosCartService>(create: (_) => PosCartService()),
      ],
      // Rebuilds the themed MaterialApp on a palette/subscription change -
      // AppData is now a ChangeNotifier in its own right (see app_data.dart),
      // so every screen's own context.watch<AppData>() already keeps that
      // screen in sync with every table on its own, without needing to be
      // listed here too.
      child: ListenableBuilder(
        listenable: Listenable.merge([themeProvider, subscriptionService]),
        builder: (context, _) {
          return MaterialApp(
            title: 'صيدليتي',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              // Keeps every screen clear of system intrusions (status bar,
              // notches, and — the important one on Android — the bottom
              // gesture/back-navigation strip) without each screen having
              // to remember to wrap itself in SafeArea individually.
              child: SafeArea(child: child!),
            ),
            // A fresh launch always starts at the login screen —
            // LoginScreen/DashboardScreen navigate onward manually via
            // Navigator once a session is established. An expired
            // subscription overrides this entirely: nothing past the
            // lockout screen is reachable, not even the login form,
            // until a valid renewal code is entered.
            home: subscriptionService.isExpired
                ? const SubscriptionLockScreen()
                : const LoginScreen(),
            routes: {
              '/dashboard': (_) => const DashboardScreen(),
              '/profile': (_) => const ProfileScreen(),
              '/pos': (_) => const PosScreen(),
              '/purchases': (_) => const PurchasesScreen(),
              '/debts': (_) => PermissionGate(
                    check: (p) => p.debts,
                    label: 'ديون المراجعين',
                    child: const DebtsScreen(),
                  ),
              '/employees': (_) => const AdminGate(
                    label: 'الموظفين والصلاحيات',
                    child: EmployeesScreen(),
                  ),
              '/settings': (_) => const AdminGate(
                    label: 'الإعدادات',
                    child: SettingsScreen(),
                  ),
              '/deficits': (_) => const DeficitsScreen(),
              '/expiry': (_) => const ExpiryScreen(),
              '/reps': (_) => const RepsScreen(),
              '/lists': (_) => PermissionGate(
                    check: (p) => p.lists,
                    label: 'كل القوائم',
                    child: const ListsScreen(),
                  ),
              '/returns': (_) => const ReturnsScreen(),
              '/movement': (_) => const MovementScreen(),
              '/settlements': (_) => const SettlementsScreen(),
              '/entries': (_) => const EntriesScreen(),
              '/pharmacies': (_) => const AdminGate(
                    label: 'الصيدليات',
                    child: PharmaciesScreen(),
                  ),
              '/reports': (_) => PermissionGate(
                    check: (p) => p.reports,
                    label: 'التقارير',
                    child: const ReportsScreen(),
                  ),
              '/products': (_) => const ProductsScreen(),
              '/attendance': (_) => const AttendanceScreen(),
              '/customer-returns': (_) => const CustomerReturnsScreen(),
              '/cashier-codes': (_) => const AdminGate(
                    label: 'أكواد الدخول',
                    child: CashierCodesScreen(),
                  ),
            },
          );
        },
      ),
    );
  }
}

