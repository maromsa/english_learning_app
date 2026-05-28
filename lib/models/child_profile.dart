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
    this.totalStars = 0,
    this.dailyStreak = 0,
    this.completedWordsCount = 0,
    this.achievements = const {},
    this.coins = 0,
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

    return ChildProfile(
      id: map['id'] as String,
      displayName: map['displayName'] as String,
      avatarColor: map['avatarColor'] as int? ?? defaultAvatarColors.first,
      avatarUrl: map['avatarUrl'] as String?,
      totalStars: map['totalStars'] as int? ?? 0,
      dailyStreak: map['dailyStreak'] as int? ?? 0,
      completedWordsCount: map['completedWordsCount'] as int? ?? 0,
      achievements: achievements,
      coins: map['coins'] as int? ?? 0,
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
  }) {
    final now = DateTime.now();
    return ChildProfile(
      id: now.millisecondsSinceEpoch.toString(),
      displayName: displayName,
      avatarColor: avatarColor,
      avatarUrl: avatarUrl,
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

  final String id;
  final String displayName;
  final int avatarColor;
  final String? avatarUrl;
  final int totalStars;
  final int dailyStreak;
  final int completedWordsCount;
  final Map<String, bool> achievements;
  final int coins;
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
      'totalStars': totalStars,
      'dailyStreak': dailyStreak,
      'completedWordsCount': completedWordsCount,
      'achievements': achievements,
      'coins': coins,
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
    int? totalStars,
    int? dailyStreak,
    int? completedWordsCount,
    Map<String, bool>? achievements,
    int? coins,
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
      totalStars: totalStars ?? this.totalStars,
      dailyStreak: dailyStreak ?? this.dailyStreak,
      completedWordsCount:
          completedWordsCount ?? this.completedWordsCount,
      achievements: achievements ?? this.achievements,
      coins: coins ?? this.coins,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}
