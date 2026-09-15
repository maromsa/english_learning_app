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
  });

  factory DailyStreak.empty() => const DailyStreak();

  final int currentStreak;
  final DateTime? lastPracticeDate;

  factory DailyStreak.fromJson(Map<String, dynamic> json) {
    return DailyStreak(
      currentStreak: _toInt(json['currentStreak']),
      lastPracticeDate: _toDate(json['lastPracticeDate']),
    );
  }

  Map<String, dynamic> toJson() => {
        'currentStreak': currentStreak,
        if (lastPracticeDate != null)
          'lastPracticeDate': lastPracticeDate!.toIso8601String(),
      };

  DailyStreak copyWith({
    int? currentStreak,
    DateTime? lastPracticeDate,
    bool clearLastPracticeDate = false,
  }) {
    return DailyStreak(
      currentStreak: currentStreak ?? this.currentStreak,
      lastPracticeDate: clearLastPracticeDate
          ? null
          : (lastPracticeDate ?? this.lastPracticeDate),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyStreak &&
          other.currentStreak == currentStreak &&
          other.lastPracticeDate == lastPracticeDate);

  @override
  int get hashCode => Object.hash(currentStreak, lastPracticeDate);

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
}
