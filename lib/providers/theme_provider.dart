// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }
  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    loadTheme();
  }

  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('is_dark_mode') ?? false;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      _notify();
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _notify();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dark_mode', isDark);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _notify();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dark_mode', mode == ThemeMode.dark);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

}