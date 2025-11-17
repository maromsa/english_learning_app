import 'dart:async';

import 'package:english_learning_app/firebase_options.dart';
import 'package:english_learning_app/providers/auth_provider.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/daily_mission_provider.dart';
import 'package:english_learning_app/providers/shop_provider.dart';
import 'package:english_learning_app/providers/theme_provider.dart';
import 'package:english_learning_app/services/achievement_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/auth_gate.dart';
import 'services/background_music_service.dart';
import 'services/telemetry_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      debugPrint('dotenv load failed: $e');
    }
  } else {
    debugPrint(
      'Skipping dotenv load on web build. Provide secrets via --dart-define.',
    );
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
  final backgroundMusicService = BackgroundMusicService();

  // Load persisted data with timeouts to prevent hanging
  try {
    await coinProvider.loadCoins().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('Coin loading timed out, continuing with default value');
      },
    );
  } catch (e) {
    debugPrint('Error loading coins: $e');
  }

  try {
    await themeProvider.loadTheme().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('Theme loading timed out, continuing with default theme');
      },
    );
  } catch (e) {
    debugPrint('Error loading theme: $e');
  }

  try {
    await shopProvider.loadPurchasedItems().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('Shop items loading timed out, continuing with empty list');
      },
    );
  } catch (e) {
    debugPrint('Error loading shop items: $e');
  }

  try {
    await dailyMissionProvider.initialize().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('Daily missions initialization timed out, continuing anyway');
      },
    );
  } catch (e) {
    debugPrint('Error initializing daily missions: $e');
  }
  
  // Initialize background music service asynchronously without blocking UI
  if (kIsWeb) {
    backgroundMusicService.initialize().catchError((error) {
      debugPrint('Background music initialization failed: $error');
    });
    debugPrint(
      'Startup chime disabled on web; map music will begin after first interaction.',
    );
  } else {
    // Don't await - let it run in background so UI can render immediately
    backgroundMusicService.playStartupSequence().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('Background music startup timed out, continuing anyway');
      },
    ).catchError((error) {
      debugPrint('Background music startup failed: $error');
    });
  }

  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  // Handle platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform error: $error');
    debugPrint('Stack trace: $stack');
    return true;
  };

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
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        unawaited(BackgroundMusicService().handleUserInteraction());
      },
      child: MaterialApp(
        title: 'מסע המילים באנגלית',
        locale: const Locale('he', 'IL'),
        supportedLocales: const [Locale('he', 'IL'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme:
              ColorScheme.fromSeed(seedColor: Colors.lightBlue.shade100),
          useMaterial3: true,
          textTheme:
              GoogleFonts.assistantTextTheme(Theme.of(context).textTheme),
        ),
        darkTheme: ThemeData.dark(),
        themeMode: themeProvider.themeMode,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          // Wrap entire app in error boundary
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: AuthGate(hasSeenOnboarding: hasSeenOnboarding),
      ),
    );
  }
}
