import 'package:cloud_firestore/cloud_firestore.dart';

import 'player_character.dart';

/// Model for storing all player game data in Firestore
class PlayerData {
  PlayerData({
    required this.userId,
    this.coins = 0,
    this.purchasedItems = const [],
    this.achievements = const {},
    this.levelProgress = const {},
    this.dailyStreak = 0,
    this.lastDailyRewardClaim,
    this.totalWordsCompleted = 0,
    this.totalQuizzesPlayed = 0,
    this.bestQuizStreak = 0,
    this.character,
    this.createdAt,
    this.updatedAt,
  });

  factory PlayerData.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    DateTime? toDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return null;
    }

    // Parse level progress
    final levelProgressData = data['levelProgress'] as Map<String, dynamic>? ?? {};
    final levelProgress = <String, LevelProgress>{};
    levelProgressData.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        levelProgress[key] = LevelProgress.fromMap(value);
      }
    });

    // Parse achievements
    final achievementsData = data['achievements'] as Map<String, dynamic>? ?? {};
    final achievements = <String, bool>{};
    achievementsData.forEach((key, value) {
      if (value is bool) {
        achievements[key] = value;
      }
    });

    // Parse character
    PlayerCharacter? character;
    final characterData = data['character'] as Map<String, dynamic>?;
    if (characterData != null) {
      character = PlayerCharacter.fromMap(characterData);
    }

    return PlayerData(
      userId: doc.id,
      coins: data['coins'] as int? ?? 0,
      purchasedItems: List<String>.from(data['purchasedItems'] as List? ?? []),
      achievements: achievements,
      levelProgress: levelProgress,
      dailyStreak: data['dailyStreak'] as int? ?? 0,
      lastDailyRewardClaim: toDate(data['lastDailyRewardClaim']),
      totalWordsCompleted: data['totalWordsCompleted'] as int? ?? 0,
      totalQuizzesPlayed: data['totalQuizzesPlayed'] as int? ?? 0,
      bestQuizStreak: data['bestQuizStreak'] as int? ?? 0,
      character: character,
      createdAt: toDate(data['createdAt']),
      updatedAt: toDate(data['updatedAt']),
    );
  }

  final String userId;
  final int coins;
  final List<String> purchasedItems;
  final Map<String, bool> achievements; // achievementId -> isUnlocked
  final Map<String, LevelProgress> levelProgress; // levelId -> progress
  final int dailyStreak;
  final DateTime? lastDailyRewardClaim;
  final int totalWordsCompleted;
  final int totalQuizzesPlayed;
  final int bestQuizStreak;
  final PlayerCharacter? character;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    final levelProgressMap = <String, dynamic>{};
    levelProgress.forEach((key, value) {
      levelProgressMap[key] = value.toMap();
    });

    return <String, dynamic>{
      'coins': coins,
      'purchasedItems': purchasedItems,
      'achievements': achievements,
      'levelProgress': levelProgressMap,
      'dailyStreak': dailyStreak,
      if (lastDailyRewardClaim != null)
        'lastDailyRewardClaim': Timestamp.fromDate(lastDailyRewardClaim!),
      'totalWordsCompleted': totalWordsCompleted,
      'totalQuizzesPlayed': totalQuizzesPlayed,
      'bestQuizStreak': bestQuizStreak,
      if (character != null) 'character': character!.toMap(),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  PlayerData copyWith({
    String? userId,
    int? coins,
    List<String>? purchasedItems,
    Map<String, bool>? achievements,
    Map<String, LevelProgress>? levelProgress,
    int? dailyStreak,
    DateTime? lastDailyRewardClaim,
    int? totalWordsCompleted,
    int? totalQuizzesPlayed,
    int? bestQuizStreak,
    PlayerCharacter? character,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlayerData(
      userId: userId ?? this.userId,
      coins: coins ?? this.coins,
      purchasedItems: purchasedItems ?? this.purchasedItems,
      achievements: achievements ?? this.achievements,
      levelProgress: levelProgress ?? this.levelProgress,
      dailyStreak: dailyStreak ?? this.dailyStreak,
      lastDailyRewardClaim: lastDailyRewardClaim ?? this.lastDailyRewardClaim,
      totalWordsCompleted: totalWordsCompleted ?? this.totalWordsCompleted,
      totalQuizzesPlayed: totalQuizzesPlayed ?? this.totalQuizzesPlayed,
      bestQuizStreak: bestQuizStreak ?? this.bestQuizStreak,
      character: character ?? this.character,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Progress data for a specific level
class LevelProgress {
  LevelProgress({
    this.stars = 0,
    this.isUnlocked = false,
    this.wordsCompleted = const {},
    this.lastPlayedAt,
  });

  factory LevelProgress.fromMap(Map<String, dynamic> map) {
    DateTime? toDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return null;
    }

    final wordsCompletedData = map['wordsCompleted'] as Map<String, dynamic>? ?? {};
    final wordsCompleted = <String, bool>{};
    wordsCompletedData.forEach((key, value) {
      if (value is bool) {
        wordsCompleted[key] = value;
      }
    });

    return LevelProgress(
      stars: map['stars'] as int? ?? 0,
      isUnlocked: map['isUnlocked'] as bool? ?? false,
      wordsCompleted: wordsCompleted,
      lastPlayedAt: toDate(map['lastPlayedAt']),
    );
  }

  final int stars;
  final bool isUnlocked;
  final Map<String, bool> wordsCompleted; // word -> isCompleted
  final DateTime? lastPlayedAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'stars': stars,
      'isUnlocked': isUnlocked,
      'wordsCompleted': wordsCompleted,
      if (lastPlayedAt != null)
        'lastPlayedAt': Timestamp.fromDate(lastPlayedAt!),
    };
  }

  LevelProgress copyWith({
    int? stars,
    bool? isUnlocked,
    Map<String, bool>? wordsCompleted,
    DateTime? lastPlayedAt,
  }) {
    return LevelProgress(
      stars: stars ?? this.stars,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      wordsCompleted: wordsCompleted ?? this.wordsCompleted,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }
}

