import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'aurora_tokens.dart';

/// Modern, child-friendly theme for the English Learning App
class AppTheme {
  // Primary color palette — aliases preserved for existing call sites
  static const Color primaryBlue = AuroraTokens.plum;
  static const Color primaryPurple = AuroraTokens.blueberry;
  static const Color primaryGreen = AuroraTokens.mint;
  static const Color primaryOrange = AuroraTokens.coral;
  static const Color primaryYellow = AuroraTokens.butter;

  // Gradient colors
  static const List<Color> primaryGradient = [
    AuroraTokens.plum,
    AuroraTokens.blueberry,
  ];

  static const List<Color> successGradient = [
    AuroraTokens.mint,
    AuroraTokens.sky,
  ];

  static const List<Color> warmGradient = [
    AuroraTokens.coral,
    AuroraTokens.butter,
  ];

  static TextStyle _display(double size, FontWeight weight, {Color? color}) {
    return GoogleFonts.baloo2(
      fontSize: size,
      fontWeight: weight,
      color: color,
    ).copyWith(fontFamilyFallback: const ['Heebo']);
  }

  static TextStyle _body(double size, FontWeight weight, {Color? color}) {
    return GoogleFonts.heebo(
      fontSize: size,
      fontWeight: weight,
      color: color,
    ).copyWith(fontFamilyFallback: const ['Baloo 2']);
  }

  /// Light theme optimized for children
  static ThemeData get lightTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AuroraTokens.plum,
        brightness: Brightness.light,
        primary: AuroraTokens.plum,
        secondary: AuroraTokens.blueberry,
        tertiary: AuroraTokens.mint,
        error: AuroraTokens.coral,
        surface: AuroraTokens.paper,
        onSurface: AuroraTokens.ink,
      ),
    );

    return baseTheme.copyWith(
      textTheme: TextTheme(
        displayLarge: _display(40, FontWeight.w900, color: AuroraTokens.ink),
        displayMedium: _display(32, FontWeight.w800, color: AuroraTokens.ink),
        displaySmall: _display(26, FontWeight.w800, color: AuroraTokens.ink),
        headlineMedium: _display(22, FontWeight.w700, color: AuroraTokens.ink),
        titleLarge: _display(20, FontWeight.w700, color: AuroraTokens.ink),
        bodyLarge: _body(18, FontWeight.w500, color: AuroraTokens.ink),
        bodyMedium: _body(16, FontWeight.w400, color: AuroraTokens.inkSoft),
        bodySmall: _body(14, FontWeight.w400, color: AuroraTokens.inkMute),
        labelLarge: _display(18, FontWeight.w800),
      ),

      // AppBar theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: AuroraTokens.ink,
        titleTextStyle: _display(22, FontWeight.w700, color: AuroraTokens.ink),
        iconTheme: const IconThemeData(
          color: AuroraTokens.ink,
          size: 28,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: AuroraTokens.paper,
        shadowColor: AuroraTokens.ink.withValues(alpha: 0.1),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: _display(18, FontWeight.w800),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: _display(18, FontWeight.w800),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(width: 2),
          textStyle: _display(18, FontWeight.w800),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AuroraTokens.paper2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AuroraTokens.hair),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AuroraTokens.hair),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AuroraTokens.plum, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AuroraTokens.coral, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // Floating action button theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AuroraTokens.plum,
        linearTrackColor: AuroraTokens.hair,
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
      ),

      // Bottom sheet theme
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        elevation: 8,
      ),
    );
  }

  /// Dark theme optimized for children
  static ThemeData get darkTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AuroraTokens.plum,
        brightness: Brightness.dark,
        primary: AuroraTokens.plum,
        secondary: AuroraTokens.blueberry,
        tertiary: AuroraTokens.mint,
        error: AuroraTokens.coral,
        surface: AuroraTokens.ink,
        onSurface: AuroraTokens.paper,
      ),
    );

    return baseTheme.copyWith(
      textTheme: TextTheme(
        displayLarge: _display(40, FontWeight.w900, color: AuroraTokens.paper),
        displayMedium:
            _display(32, FontWeight.w800, color: AuroraTokens.paper),
        displaySmall: _display(26, FontWeight.w800, color: AuroraTokens.paper),
        headlineMedium:
            _display(22, FontWeight.w700, color: AuroraTokens.paper),
        titleLarge: _display(20, FontWeight.w700, color: AuroraTokens.paper),
        bodyLarge: _body(18, FontWeight.w500, color: AuroraTokens.paper),
        bodyMedium: _body(16, FontWeight.w400, color: AuroraTokens.paper2),
        bodySmall: _body(14, FontWeight.w400, color: AuroraTokens.inkMute),
        labelLarge: _display(18, FontWeight.w800),
      ),

      // AppBar theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: AuroraTokens.paper,
        titleTextStyle:
            _display(22, FontWeight.w700, color: AuroraTokens.paper),
        iconTheme: const IconThemeData(
          color: AuroraTokens.paper,
          size: 28,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: AuroraTokens.inkSoft,
        shadowColor: AuroraTokens.ink.withValues(alpha: 0.3),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: _display(18, FontWeight.w800),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: _display(18, FontWeight.w800),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(width: 2),
          textStyle: _display(18, FontWeight.w800),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AuroraTokens.inkSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AuroraTokens.inkMute),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AuroraTokens.inkMute),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AuroraTokens.plum, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AuroraTokens.coral, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
