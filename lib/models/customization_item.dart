import 'package:flutter/material.dart';

/// What a [CustomizationItem] changes when equipped.
enum CustomizationKind { theme, sound }

/// Colour recipe for the MapScreen sky. Mirrors the [RadialGradient] the map
/// draws today so the default palette is a byte-for-byte match.
@immutable
class MapThemePalette {
  const MapThemePalette({required this.colors, required this.stops});

  final List<Color> colors;
  final List<double> stops;

  RadialGradient toGradient() => RadialGradient(
        center: const Alignment(0, -0.15),
        radius: 1.15,
        colors: colors,
        stops: stops,
      );
}

/// A purchasable cosmetic in the Magic Shop's "Themes & Sounds" section.
///
/// Unlike [ShopItem] (stickers / upgrades), a customization is *equipped*: at
/// most one theme and one sound are active at a time. Ownership + equipped
/// state are per-child and managed by `ShopCustomizationProvider`.
@immutable
class CustomizationItem {
  const CustomizationItem({
    required this.id,
    required this.name,
    required this.cost,
    required this.kind,
    required this.icon,
    this.palette,
    this.soundAsset,
  });

  final String id;

  /// Hebrew display name — matches the kid-facing copy on the shop screen.
  final String name;

  /// Price in coins. `0` for the always-owned defaults.
  final int cost;

  final CustomizationKind kind;
  final IconData icon;

  /// Set for [CustomizationKind.theme] items.
  final MapThemePalette? palette;

  /// Set for [CustomizationKind.sound] items — the asset played on a
  /// level-complete fanfare while this sound is equipped.
  final String? soundAsset;

  // ── Well-known ids ─────────────────────────────────────────────────────────

  static const String defaultThemeId = 'theme_default';
  static const String spaceThemeId = 'theme_space';
  static const String goldThemeId = 'theme_gold';
  static const String defaultSoundId = 'sound_default';
  static const String funnySoundId = 'sound_funny';

  /// The theme equipped before the child buys anything — the map's current look.
  static const MapThemePalette defaultPalette = MapThemePalette(
    colors: [
      Color(0xFFB8E4FF),
      Color(0xFF6EB5F5),
      Color(0xFF4A7FD4),
      Color(0xFF4E3F8C),
      Color(0xFF2D1B4E),
    ],
    stops: [0.0, 0.35, 0.62, 0.85, 1.0],
  );

  /// Level-complete fanfare used when no custom sound is equipped (today's).
  static const String defaultSoundAsset = 'assets/audio/the_twinkling_map.mp3';

  // ── Catalog ────────────────────────────────────────────────────────────────

  static const CustomizationItem defaultTheme = CustomizationItem(
    id: defaultThemeId,
    name: 'קלאסי',
    cost: 0,
    kind: CustomizationKind.theme,
    icon: Icons.public,
    palette: defaultPalette,
  );

  static const CustomizationItem spaceTheme = CustomizationItem(
    id: spaceThemeId,
    name: 'חלל',
    cost: 300,
    kind: CustomizationKind.theme,
    icon: Icons.rocket_launch,
    palette: MapThemePalette(
      colors: [
        Color(0xFF3A2F6B),
        Color(0xFF2A2350),
        Color(0xFF1B1740),
        Color(0xFF120E2E),
        Color(0xFF05030F),
      ],
      stops: [0.0, 0.32, 0.58, 0.82, 1.0],
    ),
  );

  static const CustomizationItem goldTheme = CustomizationItem(
    id: goldThemeId,
    name: 'זהב',
    cost: 250,
    kind: CustomizationKind.theme,
    icon: Icons.auto_awesome,
    palette: MapThemePalette(
      colors: [
        Color(0xFFFFE9A8),
        Color(0xFFFFD068),
        Color(0xFFE9A73C),
        Color(0xFF9C5A1E),
        Color(0xFF4A2A0C),
      ],
      stops: [0.0, 0.34, 0.6, 0.84, 1.0],
    ),
  );

  static const CustomizationItem defaultSound = CustomizationItem(
    id: defaultSoundId,
    name: 'ניצחון קלאסי',
    cost: 0,
    kind: CustomizationKind.sound,
    icon: Icons.celebration,
    soundAsset: defaultSoundAsset,
  );

  static const CustomizationItem funnySound = CustomizationItem(
    id: funnySoundId,
    name: 'ניצחון מצחיק',
    cost: 120,
    kind: CustomizationKind.sound,
    icon: Icons.emoji_emotions,
    soundAsset: 'assets/audio/startup_chime.wav',
  );

  static const List<CustomizationItem> catalog = [
    defaultTheme,
    spaceTheme,
    goldTheme,
    defaultSound,
    funnySound,
  ];

  static List<CustomizationItem> get themes =>
      catalog.where((c) => c.kind == CustomizationKind.theme).toList();

  static List<CustomizationItem> get sounds =>
      catalog.where((c) => c.kind == CustomizationKind.sound).toList();

  static CustomizationItem? byId(String id) {
    for (final item in catalog) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Defaults are owned by everyone and never appear as "locked".
  bool get isDefault => cost == 0;
}
