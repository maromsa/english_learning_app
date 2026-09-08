import 'package:cloud_firestore/cloud_firestore.dart';

import 'local_user.dart';

/// A child profile under a parent's account.
///
/// Progress stats are stored as a summary for cloud sync; detailed progress
/// (per-level stars, word lists) lives in SharedPreferences keyed by [id].
class ChildProfile {
  ChildProfile({
    required this.id,
    required this.displayName,
    required this.avatarColor,
    this.avatarUrl,
    this.avatarId,
    this.totalStars = 0,
    this.dailyStreak = 0,
    this.completedWordsCount = 0,
    this.achievements = const {},
    this.coins = 0,
    this.unlockedThemes = const [],
    this.unlockedSounds = const [],
    this.equippedTheme,
    this.equippedSound,
    this.createdAt,
    this.lastPlayedAt,
    this.updatedAt,
    this.pendingSync = false,
  });

  factory ChildProfile.fromMap(Map<String, dynamic> map) {
    DateTime? toDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      if (value is String) {
        return DateTime.tryParse(value);
      }
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return null;
    }

    final achievementsRaw = map['achievements'] as Map<String, dynamic>? ?? {};
    final achievements = <String, bool>{};
    achievementsRaw.forEach((key, value) {
      if (value is bool) {
        achievements[key] = value;
      }
    });

    // Tolerant of profiles written before shop-customization existed and of a
    // malformed value: anything that isn't a list of strings becomes empty.
    List<String> toStringList(dynamic value) {
      if (value is List) {
        return value.whereType<String>().where((e) => e.isNotEmpty).toList();
      }
      return const [];
    }

    String? toNonEmptyString(dynamic value) =>
        (value is String && value.isNotEmpty) ? value : null;

    return ChildProfile(
      id: (map['id'] as String?) ?? '',
      displayName: (map['displayName'] as String?) ?? '',
      avatarColor: map['avatarColor'] as int? ?? defaultAvatarColors.first,
      avatarUrl: map['avatarUrl'] as String?,
      avatarId: (map['avatarId'] as String?)?.isNotEmpty ?? false
          ? map['avatarId'] as String
          : null,
      totalStars: map['totalStars'] as int? ?? 0,
      dailyStreak: map['dailyStreak'] as int? ?? 0,
      completedWordsCount: map['completedWordsCount'] as int? ?? 0,
      achievements: achievements,
      coins: map['coins'] as int? ?? 0,
      unlockedThemes: toStringList(map['unlockedThemes']),
      unlockedSounds: toStringList(map['unlockedSounds']),
      equippedTheme: toNonEmptyString(map['equippedTheme']),
      equippedSound: toNonEmptyString(map['equippedSound']),
      createdAt: toDate(map['createdAt']),
      lastPlayedAt: toDate(map['lastPlayedAt']),
      updatedAt: toDate(map['updatedAt']),
      pendingSync: map['pendingSync'] as bool? ?? false,
    );
  }

  factory ChildProfile.fromLocalUser(LocalUser user) {
    return ChildProfile(
      id: user.id,
      displayName: user.name,
      avatarColor: defaultAvatarColors[user.age % defaultAvatarColors.length],
      avatarUrl: user.photoUrl,
      createdAt: user.createdAt ?? DateTime.now(),
      lastPlayedAt: user.lastPlayedAt,
      pendingSync: true,
    );
  }

  factory ChildProfile.create({
    required String displayName,
    required int avatarColor,
    String? avatarUrl,
    String? avatarId,
  }) {
    final now = DateTime.now();
    return ChildProfile(
      id: now.millisecondsSinceEpoch.toString(),
      displayName: displayName,
      avatarColor: avatarColor,
      avatarUrl: avatarUrl,
      avatarId: (avatarId?.isNotEmpty ?? false) ? avatarId : null,
      createdAt: now,
      lastPlayedAt: now,
      pendingSync: true,
    );
  }

  static const List<int> defaultAvatarColors = <int>[
    0xFF4A90E2,
    0xFF50C878,
    0xFFFF6B6B,
    0xFFFFB347,
    0xFF9B59B6,
    0xFF1ABC9C,
  ];

  /// Fun animal emojis a child can pick as their avatar. An empty/absent
  /// [avatarId] means "use the coloured initial" (the pre-avatar behaviour).
  static const List<String> avatarChoices = <String>[
    '🦊',
    '🐼',
    '🦁',
    '🐸',
    '🦄',
    '🐰',
    '🐨',
    '🐯',
    '🐵',
    '🐧',
    '🐢',
    '🦉',
  ];

  final String id;
  final String displayName;
  final int avatarColor;
  final String? avatarUrl;

  /// Optional emoji avatar (one of [avatarChoices]). Null/empty → coloured
  /// initial fallback. Kept nullable so profiles created before this feature
  /// deserialize unchanged.
  final String? avatarId;
  final int totalStars;
  final int dailyStreak;
  final int completedWordsCount;
  final Map<String, bool> achievements;
  final int coins;

  /// Magic Shop cosmetic ids the child has unlocked. Cloud-mirrored so a
  /// purchase survives a reinstall / new device. Merge strategy: union.
  final List<String> unlockedThemes;
  final List<String> unlockedSounds;

  /// Currently equipped customization ids (null → the built-in default).
  /// Merge strategy: newer [updatedAt] wins.
  final String? equippedTheme;
  final String? equippedSound;

  final DateTime? createdAt;
  final DateTime? lastPlayedAt;
  final DateTime? updatedAt;
  final bool pendingSync;

  int get achievementsUnlocked =>
      achievements.values.where((unlocked) => unlocked).length;

  Map<String, dynamic> toMap({bool forCloud = false}) {
    return <String, dynamic>{
      'id': id,
      'displayName': displayName,
      'avatarColor': avatarColor,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (avatarId != null && avatarId!.isNotEmpty) 'avatarId': avatarId,
      'totalStars': totalStars,
      'dailyStreak': dailyStreak,
      'completedWordsCount': completedWordsCount,
      'achievements': achievements,
      'coins': coins,
      if (unlockedThemes.isNotEmpty) 'unlockedThemes': unlockedThemes,
      if (unlockedSounds.isNotEmpty) 'unlockedSounds': unlockedSounds,
      if (equippedTheme != null) 'equippedTheme': equippedTheme,
      if (equippedSound != null) 'equippedSound': equippedSound,
      if (createdAt != null)
        'createdAt': forCloud
            ? Timestamp.fromDate(createdAt!)
            : createdAt!.toIso8601String(),
      if (lastPlayedAt != null)
        'lastPlayedAt': forCloud
            ? Timestamp.fromDate(lastPlayedAt!)
            : lastPlayedAt!.toIso8601String(),
      if (updatedAt != null)
        'updatedAt': forCloud
            ? Timestamp.fromDate(updatedAt!)
            : updatedAt!.toIso8601String(),
      if (!forCloud) 'pendingSync': pendingSync,
    };
  }

  ChildProfile copyWith({
    String? id,
    String? displayName,
    int? avatarColor,
    String? avatarUrl,
    String? avatarId,
    int? totalStars,
    int? dailyStreak,
    int? completedWordsCount,
    Map<String, bool>? achievements,
    int? coins,
    List<String>? unlockedThemes,
    List<String>? unlockedSounds,
    String? equippedTheme,
    String? equippedSound,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    DateTime? updatedAt,
    bool? pendingSync,
  }) {
    return ChildProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarId: avatarId ?? this.avatarId,
      totalStars: totalStars ?? this.totalStars,
      dailyStreak: dailyStreak ?? this.dailyStreak,
      completedWordsCount: completedWordsCount ?? this.completedWordsCount,
      achievements: achievements ?? this.achievements,
      coins: coins ?? this.coins,
      unlockedThemes: unlockedThemes ?? this.unlockedThemes,
      unlockedSounds: unlockedSounds ?? this.unlockedSounds,
      equippedTheme: equippedTheme ?? this.equippedTheme,
      equippedSound: equippedSound ?? this.equippedSound,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}
