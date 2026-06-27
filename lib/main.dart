import 'dart:async';
import 'dart:ui';

import 'package:english_learning_app/firebase_options.dart';
import 'package:english_learning_app/providers/auth_provider.dart';
import 'package:english_learning_app/providers/character_provider.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/daily_mission_provider.dart';
import 'package:english_learning_app/providers/shop_provider.dart';
import 'package:english_learning_app/providers/spark_overlay_controller.dart';
import 'package:english_learning_app/providers/theme_provider.dart';
import 'package:english_learning_app/services/achievement_service.dart';
import 'package:english_learning_app/services/speech_feedback_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/child_profile_provider.dart';
import 'providers/user_session_provider.dart';
import 'screens/auth_gate.dart';
import 'services/audio_settings.dart';
import 'services/background_music_service.dart';
import 'services/notification_service.dart';
import 'services/sound_service.dart';
import 'services/streak_shield_service.dart';
import 'services/telemetry_service.dart';
import 'utils/app_theme.dart';
import 'utils/route_observer.dart';
import 'utils/spark_route_observer.dart';
import 'widgets/living_spark.dart';

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

  // Cap decoded image cache to reduce memory pressure on low-end devices.
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 100;
  imageCache.maximumSizeBytes = 50 << 20;

  // Configuration comes from --dart-define (all platforms) or OS environment
  // variables (desktop dev). flutter_dotenv was removed: it loaded `.env` from
  // the asset bundle, which was never declared (so it silently failed) and
  // bundling it would ship secrets inside release builds.

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

    // Crash reporting: forward uncaught errors to Crashlytics so production
    // crashes are visible. Not supported on web.
    if (!kIsWeb) {
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  } catch (e, stackTrace) {
    debugPrint('Firebase initialization error: $e');
    debugPrint('Stack trace: $stackTrace');
    // Continue anyway - app should work without Firebase
  }

  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenOnboarding = prefs.getBool('onboarding_seen') ?? false;

  // Initialize providers with persistence (Spark and AchievementService need refs)
  final coinProvider = CoinProvider();
  final themeProvider = ThemeProvider();
  final sparkOverlayController = SparkOverlayController();
  final achievementService = AchievementService(
    coinProvider: coinProvider,
    sparkOverlayController: sparkOverlayController,
  );
  final streakShieldService = StreakShieldService();
  await streakShieldService.initialize().catchError((e) {
    debugPrint('StreakShieldService init error: $e');
  });
  final shopProvider = ShopProvider(shieldService: streakShieldService);
  final characterProvider = CharacterProvider();
  final telemetryService = TelemetryService();
  final dailyMissionProvider = DailyMissionProvider();
  final backgroundMusicService = BackgroundMusicService();
  final soundService = SoundService();
  final audioSettings = AudioSettings();

  // Load persisted data in parallel with timeouts to prevent hanging
  await Future.wait(
    [
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
          debugPrint(
              'Shop items loading timed out, continuing with empty list');
        },
      ).catchError((e) {
        debugPrint('Error loading shop items: $e');
      }),
      dailyMissionProvider.initialize().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint(
            'Daily missions initialization timed out, continuing anyway',
          );
        },
      ).catchError((e) {
        debugPrint('Error initializing daily missions: $e');
      }),
      audioSettings.load().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('Audio settings loading timed out, defaulting to unmuted');
        },
      ).catchError((e) {
        debugPrint('Error loading audio settings: $e');
      }),
    ],
    eagerError: false,
  ); // Don't fail if one fails

  // Initialize background music service (music will only play on MapScreen)
  unawaited(backgroundMusicService.initialize().catchError((error) {
    debugPrint('Background music initialization failed: $error');
  }));

  // Initialize sound service for UI feedback
  unawaited(soundService.initialize().catchError((error) {
    debugPrint('Sound service initialization failed: $error');
  }));

  // Initialize local notifications and restore any scheduled ones.
  unawaited(NotificationService.instance.initialize().then((_) {
    return NotificationService.instance.restoreScheduledNotifications();
  }).catchError((e) {
    debugPrint('NotificationService init error: $e');
  }));

  // Error handlers are already set up at the beginning of main()

  // Create UserSessionProvider and load active user
  final userSessionProvider = UserSessionProvider();
  await userSessionProvider.loadActiveUser().timeout(
    const Duration(seconds: 3),
    onTimeout: () {
      debugPrint('User session loading timed out, continuing without active user');
    },
  ).catchError((e) {
    debugPrint('Error loading active user: $e');
  });
  final childProfileProvider = ChildProfileProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userSessionProvider),
        ChangeNotifierProvider.value(value: childProfileProvider),
        ChangeNotifierProvider.value(value: coinProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: achievementService),
        ChangeNotifierProvider.value(value: shopProvider),
        ChangeNotifierProvider.value(value: characterProvider),
        ChangeNotifierProvider.value(value: dailyMissionProvider),
        ChangeNotifierProvider.value(value: streakShieldService),
        ChangeNotifierProvider.value(value: sparkOverlayController),
        Provider<SoundService>.value(value: soundService),
        ChangeNotifierProvider<AudioSettings>.value(value: audioSettings),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        Provider<TelemetryService>.value(value: telemetryService),
        Provider<SpeechFeedbackService>(
          create: (_) => SpeechFeedbackService(),
          dispose: (_, service) => service.dispose(),
        ),
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
    final sparkController =
        Provider.of<SparkOverlayController>(context, listen: false);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        unawaited(BackgroundMusicService().handleUserInteraction());
      },
      child: MaterialApp(
        title: 'מסע המילים באנגלית',
        navigatorObservers: [
          RouteObserverService.routeObserver,
          SparkRouteObserver(sparkController),
        ],
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
          final media = MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.0));

          return MediaQuery(
            data: media,
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                const LivingSparkOverlay(),
              ],
            ),
          );
        },
        home: AuthGate(hasSeenOnboarding: hasSeenOnboarding),
      ),
    );
  }
}
