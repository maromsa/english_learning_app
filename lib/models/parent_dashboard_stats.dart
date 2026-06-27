// lib/models/parent_dashboard_stats.dart
/// Aggregated learning metrics for the parent/teacher dashboard.
class ParentDashboardStats {
  const ParentDashboardStats({
    required this.childName,
    required this.totalStars,
    required this.dailyStreak,
    required this.wordsPracticed,
    required this.totalWordsInCatalog,
    required this.levelsCompleted,
    required this.totalLevels,
    required this.coins,
    required this.achievementsUnlocked,
    required this.achievementsTotal,
    required this.dailyMissionsCompleted,
    required this.dailyMissionsTotal,
    required this.wordsMastered,
    this.lastPlayedAt,
    // ── New fields ──────────────────────────────────────────────────────────
    this.weeklyActivity = const [],
    this.weakWords = const [],
    this.totalSessionMinutes = 0,
    this.weeklyNewWords = 0,
  });

  final String childName;
  final int totalStars;
  final int dailyStreak;
  final int wordsPracticed;
  final int totalWordsInCatalog;
  final int levelsCompleted;
  final int totalLevels;
  final int coins;
  final int achievementsUnlocked;
  final int achievementsTotal;
  final int dailyMissionsCompleted;
  final int dailyMissionsTotal;
  final int wordsMastered;
  final DateTime? lastPlayedAt;

  /// Activity per day for the last 7 days.
  /// Each entry: {'date': DateTime, 'words': int, 'minutes': int}.
  final List<DailyActivity> weeklyActivity;

  /// Words with lowest mastery that need more practice.
  final List<WeakWord> weakWords;

  /// Estimated total learning session time in minutes (all-time).
  final int totalSessionMinutes;

  /// How many new words the child started this week.
  final int weeklyNewWords;

  // ---------------------------------------------------------------------------
  // Computed ratios (unchanged)
  // ---------------------------------------------------------------------------

  double get wordsProgressRatio => totalWordsInCatalog == 0
      ? 0
      : (wordsPracticed / totalWordsInCatalog).clamp(0.0, 1.0);

  double get levelsProgressRatio =>
      totalLevels == 0 ? 0 : (levelsCompleted / totalLevels).clamp(0.0, 1.0);

  /// Average words practiced per active day this week.
  double get avgWordsPerDay {
    final activeDays = weeklyActivity.where((d) => d.words > 0).length;
    if (activeDays == 0) return 0;
    final totalWords = weeklyActivity.fold(0, (sum, d) => sum + d.words);
    return totalWords / activeDays;
  }
}

/// Words practiced on a single calendar day.
class DailyActivity {
  const DailyActivity({
    required this.date,
    required this.words,
    required this.minutes,
  });

  final DateTime date;

  /// Number of words practiced (quiz answers, pronunciation, etc.)
  final int words;

  /// Estimated session length in minutes.
  final int minutes;

  String get shortDayLabel {
    const days = ['ש׳', 'א׳', 'ב׳', 'ג׳', 'ד׳', 'ה׳', 'ו׳'];
    return days[date.weekday % 7];
  }
}

/// A word that needs more practice.
class WeakWord {
  const WeakWord({
    required this.word,
    required this.masteryLevel,
    required this.levelName,
  });

  final String word;

  /// Mastery in [0, 1] — lower = weaker.
  final double masteryLevel;

  final String levelName;

  int get masteryPercent => (masteryLevel * 100).round();
}
