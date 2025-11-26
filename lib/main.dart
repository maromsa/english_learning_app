import 'dart:async';

import 'package:english_learning_app/firebase_options.dart';
import 'package:english_learning_app/providers/auth_provider.dart';
import 'package:english_learning_app/providers/character_provider.dart';
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
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/auth_gate.dart';
import 'services/background_music_service.dart';
import 'services/sound_service.dart';
import 'services/telemetry_service.dart';
import 'utils/app_theme.dart';
import 'utils/route_observer.dart';
import 'providers/user_session_provider.dart';

Future<void> main() async {
  // Global error handler to catch any unhandled errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  // Platform error handler
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform Error: $error');
    debugPrint('Stack trace: $stack');
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: '.env');
      debugPrint('dotenv loaded successfully');
    } catch (e) {
      debugPrint('dotenv load failed: $e');
    }
  } else {
    debugPrint(
      'Skipping dotenv load on web build. Provide secrets via --dart-define.',
    );
  }

  // Initialize Firebase with better error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('Firebase initialization timed out');
        throw TimeoutException('Firebase initialization timed out');
      },
    );
    debugPrint('Firebase initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('Firebase initialization error: $e');
    debugPrint('Stack trace: $stackTrace');
    // Continue anyway - app should work without Firebase
  }

  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenOnboarding = prefs.getBool('onboarding_seen') ?? false;

  // Initialize providers with persistence
  final coinProvider = CoinProvider();
  final themeProvider = ThemeProvider();
  final achievementService = AchievementService();
  final shopProvider = ShopProvider();
  final characterProvider = CharacterProvider();
  final telemetryService = TelemetryService();
  final dailyMissionProvider = DailyMissionProvider();
  final backgroundMusicService = BackgroundMusicService();
  final soundService = SoundService();

  // Load persisted data in parallel with timeouts to prevent hanging
  await Future.wait([
    coinProvider.loadCoins().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint('Coin loading timed out, continuing with default value');
      },
    ).catchError((e) {
      debugPrint('Error loading coins: $e');
    }),
    themeProvider.loadTheme().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint('Theme loading timed out, continuing with default theme');
      },
    ).catchError((e) {
      debugPrint('Error loading theme: $e');
    }),
    shopProvider.loadPurchasedItems().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint('Shop items loading timed out, continuing with empty list');
      },
    ).catchError((e) {
      debugPrint('Error loading shop items: $e');
    }),
    dailyMissionProvider.initialize().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint(
            'Daily missions initialization timed out, continuing anyway');
      },
    ).catchError((e) {
      debugPrint('Error initializing daily missions: $e');
    }),
  ], eagerError: false); // Don't fail if one fails

  // Initialize background music service (music will only play on MapScreen)
  backgroundMusicService.initialize().catchError((error) {
    debugPrint('Background music initialization failed: $error');
  });

  // Initialize sound service for UI feedback
  soundService.initialize().catchError((error) {
    debugPrint('Sound service initialization failed: $error');
  });

  // Error handlers are already set up at the beginning of main()

  // Create UserSessionProvider and load active user
  final userSessionProvider = UserSessionProvider();
  await userSessionProvider.loadActiveUser();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userSessionProvider),
        ChangeNotifierProvider.value(value: coinProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: achievementService),
        ChangeNotifierProvider.value(value: shopProvider),
        ChangeNotifierProvider.value(value: characterProvider),
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
        navigatorObservers: [RouteObserverService.routeObserver],
        locale: const Locale('he', 'IL'),
        supportedLocales: const [Locale('he', 'IL'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider.themeMode,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          // Wrap entire app in error boundary
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.0)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: AuthGate(hasSeenOnboarding: hasSeenOnboarding),
      ),
    );
  }
}
