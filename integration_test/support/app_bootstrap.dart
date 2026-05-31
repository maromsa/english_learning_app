import 'package:english_learning_app/providers/character_provider.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/daily_mission_provider.dart';
import 'package:english_learning_app/providers/shop_provider.dart';
import 'package:english_learning_app/providers/spark_overlay_controller.dart';
import 'package:english_learning_app/providers/theme_provider.dart';
import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/screens/map_screen.dart';
import 'package:english_learning_app/services/achievement_service.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:english_learning_app/services/speech_feedback_service.dart';
import 'package:english_learning_app/services/telemetry_service.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:english_learning_app/utils/app_theme.dart';
import 'package:english_learning_app/utils/route_observer.dart';
import 'package:english_learning_app/utils/spark_route_observer.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Boots a production [MapScreen] with the same provider stack as [main], but
/// skips [AuthGate] so the integration test can focus on the web postMessage bridge.
Future<void> bootstrapMapIntegrationApp() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  SharedPreferences.setMockInitialValues({'onboarding_seen': true});

  final firestore = FakeFirebaseFirestore();
  final userDataService = UserDataService(firestore: firestore);
  final coinProvider = CoinProvider(userDataService: userDataService);
  final themeProvider = ThemeProvider();
  final sparkOverlayController = SparkOverlayController();
  final achievementService = AchievementService(
    coinProvider: coinProvider,
    sparkOverlayController: sparkOverlayController,
    userDataService: userDataService,
  );
  final shopProvider = ShopProvider(userDataService: userDataService);
  final characterProvider = CharacterProvider(userDataService: userDataService);
  final dailyMissionProvider = DailyMissionProvider();
  final userSessionProvider = UserSessionProvider();
  final telemetryService = TelemetryService();

  await Future.wait([
    coinProvider.loadCoins(),
    themeProvider.loadTheme(),
    shopProvider.loadPurchasedItems(),
    dailyMissionProvider.initialize(),
    userSessionProvider.loadActiveUser(),
  ], eagerError: false);

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
        ChangeNotifierProvider.value(value: sparkOverlayController),
        Provider<SoundService>.value(value: SoundService()),
        Provider<SpeechFeedbackService>(
          create: (_) => SpeechFeedbackService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<TelemetryService>.value(value: telemetryService),
      ],
      child: MaterialApp(
        navigatorObservers: [
          RouteObserverService.routeObserver,
          SparkRouteObserver(sparkOverlayController),
        ],
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child ?? const SizedBox.shrink(),
          );
        },
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
        home: const MapScreen(),
      ),
    ),
  );
}
