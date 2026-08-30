// lib/utils/srs_algorithm.dart
//
// Simple Leitner-style spaced-repetition scheduler driven by a child's
// pronunciation star rating (1-3) for a word.
//
// Rules:
//   - 3 stars ("perfect"):        increment the streak. The review interval
//     grows with the streak: 1, 3, 7, 14, 30 days (the 30-day interval is
//     reused once the streak passes 5).
//   - 2 stars ("good"):           keep the streak as-is, review again
//     tomorrow.
//   - 1 star ("needs practice"):  reset the streak to 0, review again
//     tomorrow.
//
// This is intentionally simpler than the SM-2 algorithm used by
// [SrsCard]/[SrsService] for the dedicated SRS review deck. It powers the
// lightweight per-word scheduling stored alongside `WordMasteryEntry` /
// `WordProgressEntry` for the main leveled-game pronunciation flow, so the
// two systems can evolve independently.

/// Result of applying the Leitner algorithm to a single pronunciation grade.
class SrsReviewResult {
  const SrsReviewResult({
    required this.streak,
    required this.nextReviewDate,
  });

  /// Consecutive-3-star streak after this review (reset to 0 on a 1-star
  /// grade; unchanged on a 2-star grade).
  final int streak;

  /// When the word should next be presented for review.
  final DateTime nextReviewDate;

  @override
  String toString() =>
      'SrsReviewResult(streak: $streak, nextReviewDate: $nextReviewDate)';
}

/// Leitner-style spaced-repetition scheduler for pronunciation star ratings.
class SrsAlgorithm {
  const SrsAlgorithm._();

  /// Review intervals in days, indexed by `streak - 1`. The last value is
  /// reused once the streak exceeds this list's length.
  static const List<int> intervalsByStreak = [1, 3, 7, 14, 30];

  /// Interval used for the "review again tomorrow" cases (2-star and
  /// 1-star grades).
  static const int _tomorrowIntervalDays = 1;

  /// Computes the next review date and streak for a word given a
  /// pronunciation [stars] rating and the [currentStreak] going in.
  ///
  /// [stars] is clamped into the valid 1-3 range (out-of-range input is
  /// treated as the nearest valid rating rather than throwing, since a
  /// scheduling call should never crash the app). [currentStreak] is
  /// clamped to be non-negative for the same reason.
  ///
  /// [now] defaults to [DateTime.now] and is exposed so callers (and tests)
  /// can compute deterministic results.
  static SrsReviewResult computeNextReview({
    required int stars,
    required int currentStreak,
    DateTime? now,
  }) {
    final clampedStars = stars.clamp(1, 3);
    final safeStreak = currentStreak < 0 ? 0 : currentStreak;
    final today = now ?? DateTime.now();

    final int nextStreak;
    final int intervalDays;

    if (clampedStars == 3) {
      nextStreak = safeStreak + 1;
      final index = (nextStreak - 1).clamp(0, intervalsByStreak.length - 1);
      intervalDays = intervalsByStreak[index];
    } else if (clampedStars == 2) {
      nextStreak = safeStreak;
      intervalDays = _tomorrowIntervalDays;
    } else {
      // 1 star.
      nextStreak = 0;
      intervalDays = _tomorrowIntervalDays;
    }

    return SrsReviewResult(
      streak: nextStreak,
      nextReviewDate: today.add(Duration(days: intervalDays)),
    );
  }
}
