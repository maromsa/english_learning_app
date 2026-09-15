/// Consecutive days a child has completed practice (local-first).
///
/// Distinct from the login-claim streak in DailyRewardService: this one is
/// bumped by actually finishing a practice action (currently Sentence
/// Practice), not by opening the daily-reward chest.
///
/// Deserialization is tolerant (§2.3): a missing or malformed document
/// parses to an empty streak rather than throwing.
class DailyStreak {
  const DailyStreak({
    this.currentStreak = 0,
    this.lastPracticeDate,
    this.claimedMilestones = const [],
  });

  factory DailyStreak.empty() => const DailyStreak();

  final int currentStreak;
  final DateTime? lastPracticeDate;

  /// Streak-day counts (3 / 7 / 14) already rewarded on this streak.
  /// Cleared when the streak resets so the child can earn them again.
  final List<int> claimedMilestones;

  factory DailyStreak.fromJson(Map<String, dynamic> json) {
    return DailyStreak(
      currentStreak: _toInt(json['currentStreak']),
      lastPracticeDate: _toDate(json['lastPracticeDate']),
      claimedMilestones: _toIntList(json['claimedMilestones']),
    );
  }

  Map<String, dynamic> toJson() => {
        'currentStreak': currentStreak,
        if (lastPracticeDate != null)
          'lastPracticeDate': lastPracticeDate!.toIso8601String(),
        if (claimedMilestones.isNotEmpty)
          'claimedMilestones': claimedMilestones,
      };

  DailyStreak copyWith({
    int? currentStreak,
    DateTime? lastPracticeDate,
    List<int>? claimedMilestones,
    bool clearLastPracticeDate = false,
  }) {
    return DailyStreak(
      currentStreak: currentStreak ?? this.currentStreak,
      lastPracticeDate: clearLastPracticeDate
          ? null
          : (lastPracticeDate ?? this.lastPracticeDate),
      claimedMilestones: claimedMilestones ?? this.claimedMilestones,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyStreak &&
          other.currentStreak == currentStreak &&
          other.lastPracticeDate == lastPracticeDate &&
          _sameInts(other.claimedMilestones, claimedMilestones));

  @override
  int get hashCode => Object.hash(
        currentStreak,
        lastPracticeDate,
        Object.hashAll(claimedMilestones),
      );

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static DateTime? _toDate(dynamic value) {
    if (value is DateTime) return DateTime(value.year, value.month, value.day);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed == null) return null;
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    if (value is int) {
      final parsed = DateTime.fromMillisecondsSinceEpoch(value);
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    return null;
  }

  static List<int> _toIntList(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is int) item else if (item is num) item.toInt(),
    ];
  }

  static bool _sameInts(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
