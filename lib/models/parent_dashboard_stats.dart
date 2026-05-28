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

  double get wordsProgressRatio => totalWordsInCatalog == 0
      ? 0
      : (wordsPracticed / totalWordsInCatalog).clamp(0.0, 1.0);

  double get levelsProgressRatio =>
      totalLevels == 0 ? 0 : (levelsCompleted / totalLevels).clamp(0.0, 1.0);
}
