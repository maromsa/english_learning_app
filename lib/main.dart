import 'package:english_learning_app/firebase_options.dart';
import 'package:english_learning_app/providers/auth_provider.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/daily_mission_provider.dart';
import 'package:english_learning_app/providers/shop_provider.dart';
import 'package:english_learning_app/providers/theme_provider.dart';
import 'package:english_learning_app/services/achievement_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/auth_gate.dart';
import 'services/telemetry_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('dotenv load failed: $e');
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenOnboarding = prefs.getBool('onboarding_seen') ?? false;

  // Initialize providers with persistence
  final coinProvider = CoinProvider();
  final themeProvider = ThemeProvider();
  final achievementService = AchievementService();
  final shopProvider = ShopProvider();
  final telemetryService = TelemetryService();
  final dailyMissionProvider = DailyMissionProvider();

  // Load persisted data
  await coinProvider.loadCoins();
  await themeProvider.loadTheme();
  await shopProvider.loadPurchasedItems();
  await dailyMissionProvider.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: coinProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: achievementService),
        ChangeNotifierProvider.value(value: shopProvider),
        ChangeNotifierProvider.value(value: dailyMissionProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        Provider<TelemetryService>.value(value: telemetryService),
      ],
      child: MyApp(hasSeenOnboarding: hasSeenOnboarding),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool hasSeenOnboarding;
  const MyApp({super.key, required this.hasSeenOnboarding});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'מסע המילים באנגלית',
      locale: const Locale('he', 'IL'),
      supportedLocales: const [Locale('he', 'IL'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue.shade100),
        useMaterial3: true,
        textTheme: GoogleFonts.assistantTextTheme(Theme.of(context).textTheme),
      ),
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      home: AuthGate(hasSeenOnboarding: hasSeenOnboarding),
    );
  }
}
