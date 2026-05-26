import 'package:flutter/material.dart';

/// Aurora design system — single source of truth for visual tokens.
class AuroraTokens {
  AuroraTokens._();

  // ── Brand palette ──────────────────────────────────────────────────────────

  static const Color plum = Color(0xFF8A4FFF);
  static const Color coral = Color(0xFFFF7A66);
  static const Color butter = Color(0xFFFFC857);
  static const Color mint = Color(0xFF2DC8A7);
  static const Color blueberry = Color(0xFF5B6FFF);
  static const Color sky = Color(0xFFBDE3FF);
  static const Color paper = Color(0xFFFBF7F0);
  static const Color paper2 = Color(0xFFF4ECDD);
  static const Color ink = Color(0xFF1F1B2E);
  static const Color inkSoft = Color(0xFF4B4660);
  static const Color inkMute = Color(0xFF8A859E);
  static const Color hair = Color(0xFFE6DDC9);

  // ── Semantic aliases ───────────────────────────────────────────────────────

  static const Color success = mint;
  static const Color warning = butter;
  static const Color danger = coral;
  static const Color info = blueberry;

  // ── Spacing ────────────────────────────────────────────────────────────────

  static const double s2 = 4;
  static const double s4 = 8;
  static const double s8 = 16;
  static const double s12 = 24;
  static const double s16 = 32;
  static const double s24 = 48;

  // ── Radius ─────────────────────────────────────────────────────────────────

  static const double rSm = 10;
  static const double rMd = 16;
  static const double rLg = 22;
  static const double rXl = 28;
  static const double rPill = 999;

  // ── Motion ─────────────────────────────────────────────────────────────────

  static const Duration dPress = Duration(milliseconds: 90);
  static const Duration dBounce = Duration(milliseconds: 200);
  static const Duration dBreathe = Duration(milliseconds: 2600);
  static const Duration dBurst = Duration(milliseconds: 1100);

  // ── Shadows ────────────────────────────────────────────────────────────────

  static List<BoxShadow> softCard() => [
        BoxShadow(
          color: ink.withValues(alpha: 0.18),
          blurRadius: 10,
        ),
      ];

  static List<BoxShadow> liftedCard() => [
        BoxShadow(
          color: ink.withValues(alpha: 0.22),
          blurRadius: 30,
          offset: const Offset(0, 18),
        ),
      ];

  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.55),
          blurRadius: 40,
          offset: const Offset(0, 18),
        ),
      ];
}
