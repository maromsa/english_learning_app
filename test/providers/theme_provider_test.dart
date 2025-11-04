// test/providers/theme_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:english_learning_app/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ThemeProvider', () {
    late ThemeProvider themeProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      themeProvider = ThemeProvider();
    });

    test('initial theme should be light', () {
      expect(themeProvider.themeMode, ThemeMode.light);
    });

    test('toggleTheme should change to dark mode', () async {
      await themeProvider.loadTheme(); // Wait for initial load
      await themeProvider.toggleTheme(true);
      expect(themeProvider.themeMode, ThemeMode.dark);
    });

    test('toggleTheme should change to light mode', () async {
      await themeProvider.loadTheme(); // Wait for initial load
      await themeProvider.toggleTheme(true);
      await themeProvider.toggleTheme(false);
      expect(themeProvider.themeMode, ThemeMode.light);
    });

    test('setThemeMode should set theme mode', () async {
      await themeProvider.loadTheme(); // Wait for initial load
      await themeProvider.setThemeMode(ThemeMode.dark);
      expect(themeProvider.themeMode, ThemeMode.dark);
      
      await themeProvider.setThemeMode(ThemeMode.light);
      expect(themeProvider.themeMode, ThemeMode.light);
    });

    test('loadTheme should load theme from SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dark_mode', true);
      
      final newProvider = ThemeProvider();
      await newProvider.loadTheme();
      expect(newProvider.themeMode, ThemeMode.dark);
    });

    test('loadTheme should default to light when no preference', () async {
      SharedPreferences.setMockInitialValues({});
      final newProvider = ThemeProvider();
      await newProvider.loadTheme();
      expect(newProvider.themeMode, ThemeMode.light);
    });
  });
}
