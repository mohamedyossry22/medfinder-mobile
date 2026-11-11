import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/api.dart';
import 'core/auth_state.dart';
import 'core/pharmacy_state.dart';
import 'core/push.dart';
import 'core/realtime.dart';
import 'core/theme.dart';
import 'screens/main_shell.dart';
import 'screens/pharmacy/pharmacy_shell.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';
final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // لو Firebase مش متظبط التطبيق بيشتغل من غير إشعارات
  } catch (_) {}

  final auth = AuthState();
  await auth.load();
  // لو اتسجل خروج (يدويًا أو انتهاء التوكن) نرجع لأول شاشة
  auth.addListener(() {
    if (!auth.loggedIn) navKey.currentState?.popUntil((r) => r.isFirst);
  });

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider(create: (_) => Settings()),
      Provider<Api>(create: (_) => Api(auth)),
      Provider<RealtimeService>(create: (_) => RealtimeService(auth), dispose: (_, r) => r.stop()),
      ChangeNotifierProvider<PharmacyState>(create: (c) => PharmacyState(c.read<Api>(), c.read<RealtimeService>())),
      Provider<PushService>(create: (c) => PushService(c.read<Api>(), navKey, c.read<RealtimeService>())),
    ],
    child: const MedFinderApp(),
  ));
}

class MedFinderApp extends StatelessWidget {
  const MedFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedFinder',
      debugShowCheckedModeBanner: false,
      navigatorKey: navKey,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: Consumer<AuthState>(builder: (_, a, __) => a.loggedIn ? (a.isPharmacy ? const PharmacyShell() : const MainShell()) : const LoginScreen()),
    );
  }
}
