// lib/models/srs_card.dart
//
// Spaced-Repetition System card based on the SM-2 algorithm.
//
// SM-2 reference: https://www.supermemo.com/en/blog/application-of-a-computer-to-improve-the-results-obtained-in-working-with-the-super-memo-method
//
// Card state transitions:
//   - Grade 0-1 ("again"): reset repetitions to 0, interval stays 1 day.
//   - Grade 2   ("hard"):  advance but penalise EF.
//   - Grade 3-4 ("good"):  standard advancement.
//   - Grade 5   ("easy"):  advance with EF bonus.
//
// EF (ease factor) starts at 2.5, never drops below 1.3.
// Interval: day 1 → 6 → EF*prev, rounded to int.

class SrsCard {
  const SrsCard({
    required this.wordId,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.intervalDays = 1,
    this.nextReviewDate,
    this.lastReviewDate,
    this.masteryLevel = 0.0,
    this.bestPronunciationStars = 0,
  });

  /// Word identifier (same as WordData.word, lower-cased).
  final String wordId;

  /// Number of consecutive correct reviews (≥ grade 3).
  final int repetitions;

  /// SM-2 ease factor — higher means longer intervals.
  final double easeFactor;

  /// Current review interval in days.
  final int intervalDays;

  /// When the card should next be reviewed. Null = review immediately.
  final DateTime? nextReviewDate;

  /// When the card was last reviewed.
  final DateTime? lastReviewDate;

  /// Derived mastery in [0, 1] — used for UI display and ordering.
  final double masteryLevel;

  /// Best pronunciation score (1–3 stars).
  final int bestPronunciationStars;

  /// Whether the card is due for review right now.
  bool get isDue {
    if (nextReviewDate == null) return true;
    return DateTime.now().isAfter(nextReviewDate!);
  }

  /// How many days until next review. Negative means overdue.
  int get daysUntilDue {
    if (nextReviewDate == null) return -1;
    return nextReviewDate!.difference(DateTime.now()).inDays;
  }

  // ---------------------------------------------------------------------------
  // SM-2 core logic
  // ---------------------------------------------------------------------------

  /// Apply a review grade (0–5) and return the updated card.
  ///
  /// Grade scale:
  ///   0 – complete blackout (wrong, no idea)
  ///   1 – wrong but remembered after seeing answer
  ///   2 – wrong but answer seemed easy once revealed (hard)
  ///   3 – correct but significant hesitation
  ///   4 – correct with minor hesitation
  ///   5 – perfect response
  SrsCard review({required int grade, DateTime? reviewedAt}) {
    assert(grade >= 0 && grade <= 5, 'SM-2 grade must be 0–5');
    final now = reviewedAt ?? DateTime.now();

    int nextReps = repetitions;
    double nextEF = easeFactor;
    int nextInterval;

    // EF update (applied regardless of pass/fail per SM-2 spec).
    nextEF = easeFactor + (0.1 - (5 - grade) * (0.08 + (5 - grade) * 0.02));
    if (nextEF < 1.3) nextEF = 1.3;
    // Cap EF at a reasonable maximum to prevent runaway intervals.
    if (nextEF > 3.5) nextEF = 3.5;

    if (grade < 3) {
      // Failure — restart the repetition counter.
      nextReps = 0;
      nextInterval = 1;
    } else {
      // Success
      nextReps = repetitions + 1;
      switch (nextReps) {
        case 1:
          nextInterval = 1;
        case 2:
          nextInterval = 6;
        default:
          nextInterval = (intervalDays * nextEF).round();
          if (nextInterval < intervalDays + 1) {
            nextInterval = intervalDays + 1;
          }
      }
    }

    // Cap interval at 365 days to prevent absurd schedules.
    if (nextInterval > 365) nextInterval = 365;

    final nextReview = now.add(Duration(days: nextInterval));

    // Derive mastery from grade history and repetitions.
    final nextMastery = _computeMastery(
      grade: grade,
      repetitions: nextReps,
      easeFactor: nextEF,
    );

    return SrsCard(
      wordId: wordId,
      repetitions: nextReps,
      easeFactor: nextEF,
      intervalDays: nextInterval,
      nextReviewDate: nextReview,
      lastReviewDate: now,
      masteryLevel: nextMastery,
      bestPronunciationStars: bestPronunciationStars,
    );
  }

  /// Records a pronunciation score (1–3 stars) without a full SM-2 review.
  SrsCard withPronunciationScore(int stars) {
    final clampedStars = stars.clamp(1, 3);
    final nextStars = clampedStars > bestPronunciationStars
        ? clampedStars
        : bestPronunciationStars;
    // Map stars to SM-2 grade: 1→2, 2→3, 3→5
    final grade = [0, 2, 3, 5][clampedStars];
    return review(grade: grade).copyWith(bestPronunciationStars: nextStars);
  }

  static double _computeMastery({
    required int grade,
    required int repetitions,
    required double easeFactor,
  }) {
    if (grade < 3 || repetitions == 0) {
      return (grade / 5.0 * 0.3).clamp(0.0, 0.3);
    }
    // Mastery = combination of repetitions (breadth) and EF (ease).
    // 3 successful reviews → ~0.6, 5+ reviews with high EF → 1.0.
    final repScore = (repetitions / 5.0).clamp(0.0, 1.0);
    final efScore = ((easeFactor - 1.3) / (3.5 - 1.3)).clamp(0.0, 1.0);
    final combined = repScore * 0.7 + efScore * 0.3;
    return combined.clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'wordId': wordId,
        'repetitions': repetitions,
        'easeFactor': easeFactor,
        'intervalDays': intervalDays,
        if (nextReviewDate != null)
          'nextReviewDate': nextReviewDate!.toIso8601String(),
        if (lastReviewDate != null)
          'lastReviewDate': lastReviewDate!.toIso8601String(),
        'masteryLevel': masteryLevel,
        if (bestPronunciationStars > 0)
          'bestPronunciationStars': bestPronunciationStars,
      };

  factory SrsCard.fromJson(Map<String, dynamic> json) {
    return SrsCard(
      wordId: json['wordId'] as String? ?? '',
      repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      intervalDays: (json['intervalDays'] as num?)?.toInt() ?? 1,
      nextReviewDate: _parseDate(json['nextReviewDate']),
      lastReviewDate: _parseDate(json['lastReviewDate']),
      masteryLevel: ((json['masteryLevel'] as num?)?.toDouble() ?? 0.0)
          .clamp(0.0, 1.0),
      bestPronunciationStars:
          ((json['bestPronunciationStars'] as num?)?.toInt() ?? 0)
              .clamp(0, 3),
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    if (raw is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  SrsCard copyWith({
    String? wordId,
    int? repetitions,
    double? easeFactor,
    int? intervalDays,
    DateTime? nextReviewDate,
    DateTime? lastReviewDate,
    double? masteryLevel,
    int? bestPronunciationStars,
  }) {
    return SrsCard(
      wordId: wordId ?? this.wordId,
      repetitions: repetitions ?? this.repetitions,
      easeFactor: easeFactor ?? this.easeFactor,
      intervalDays: intervalDays ?? this.intervalDays,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      lastReviewDate: lastReviewDate ?? this.lastReviewDate,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      bestPronunciationStars:
          bestPronunciationStars ?? this.bestPronunciationStars,
    );
  }

  @override
  String toString() =>
      'SrsCard($wordId reps=$repetitions ef=${easeFactor.toStringAsFixed(2)} '
      'interval=${intervalDays}d due=${nextReviewDate?.toIso8601String()} '
      'mastery=${(masteryLevel * 100).round()}%)';
}
