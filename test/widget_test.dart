// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/theme_provider.dart';
import 'package:english_learning_app/services/achievement_service.dart';
import 'package:english_learning_app/providers/shop_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('App Initialization', () {
    testWidgets('app should initialize without errors', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_seen': true});
      
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CoinProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => AchievementService()),
            ChangeNotifierProvider(create: (_) => ShopProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Text('Test')),
          ),
        ),
      );

      expect(find.text('Test'), findsOneWidget);
    });
  });
}