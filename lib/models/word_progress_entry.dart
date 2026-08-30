import 'package:cloud_firestore/cloud_firestore.dart';

/// Per-word progress stored in Firestore under [LevelProgress.wordProgress].
class WordProgressEntry {
  const WordProgressEntry({
    required this.wordId,
    this.bestPronunciationStars = 0,
    this.isMastered = false,
    this.isCompleted = false,
    this.nextReviewDate,
    this.srsStreak = 0,
  });

  factory WordProgressEntry.fromMap(Map<String, dynamic> map) {
    final rawStars = map['bestPronunciationStars'];
    var stars = 0;
    if (rawStars is int) {
      stars = rawStars.clamp(0, 3);
    } else if (rawStars is num) {
      stars = rawStars.toInt().clamp(0, 3);
    }

    final rawStreak = map['srsStreak'];
    var streak = 0;
    if (rawStreak is int) {
      streak = rawStreak < 0 ? 0 : rawStreak;
    } else if (rawStreak is num) {
      final asInt = rawStreak.toInt();
      streak = asInt < 0 ? 0 : asInt;
    }

    return WordProgressEntry(
      wordId: map['wordId'] as String? ?? '',
      bestPronunciationStars: stars,
      isMastered: map['isMastered'] as bool? ?? false,
      isCompleted: map['isCompleted'] as bool? ?? false,
      nextReviewDate: _toDate(map['nextReviewDate']),
      srsStreak: streak,
    );
  }

  /// Canonical word identifier (display text or [WordData.publicId] when set).
  final String wordId;

  final int bestPronunciationStars;
  final bool isMastered;
  final bool isCompleted;

  /// When this word should next be presented for review, per `SrsAlgorithm`.
  final DateTime? nextReviewDate;

  /// Consecutive-3-star streak used by `SrsAlgorithm` to size the next
  /// review interval.
  final int srsStreak;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'wordId': wordId,
        'bestPronunciationStars': bestPronunciationStars,
        'isMastered': isMastered,
        if (isCompleted) 'isCompleted': isCompleted,
        if (nextReviewDate != null)
          'nextReviewDate': Timestamp.fromDate(nextReviewDate!),
        if (srsStreak > 0) 'srsStreak': srsStreak,
      };

  WordProgressEntry copyWith({
    String? wordId,
    int? bestPronunciationStars,
    bool? isMastered,
    bool? isCompleted,
    DateTime? nextReviewDate,
    int? srsStreak,
  }) {
    return WordProgressEntry(
      wordId: wordId ?? this.wordId,
      bestPronunciationStars:
          bestPronunciationStars ?? this.bestPronunciationStars,
      isMastered: isMastered ?? this.isMastered,
      isCompleted: isCompleted ?? this.isCompleted,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      srsStreak: srsStreak ?? this.srsStreak,
    );
  }

  /// Merges [other] into this entry, keeping the best star rating and flags.
  ///
  /// The SRS streak/review-date pair is kept from whichever side has the
  /// higher streak (ties favour this entry), so the two always stay
  /// consistent with each other rather than mixing a streak from one side
  /// with a review date from the other.
  WordProgressEntry mergeWith(WordProgressEntry other) {
    final nextStars = bestPronunciationStars > other.bestPronunciationStars
        ? bestPronunciationStars
        : other.bestPronunciationStars;
    final keepThisSrs = srsStreak >= other.srsStreak;
    return WordProgressEntry(
      wordId: wordId.isNotEmpty ? wordId : other.wordId,
      bestPronunciationStars: nextStars,
      isMastered: isMastered || other.isMastered,
      isCompleted: isCompleted || other.isCompleted,
      srsStreak: keepThisSrs ? srsStreak : other.srsStreak,
      nextReviewDate: keepThisSrs ? nextReviewDate : other.nextReviewDate,
    );
  }

  /// Builds an entry from local `WordMasteryEntry` data.
  static WordProgressEntry fromMastery({
    required String wordId,
    required double masteryLevel,
    required int bestPronunciationStars,
    bool isCompleted = false,
    DateTime? nextReviewDate,
    int srsStreak = 0,
  }) {
    final mastered = masteryLevel >= 1.0 || bestPronunciationStars >= 3;
    return WordProgressEntry(
      wordId: wordId,
      bestPronunciationStars: bestPronunciationStars,
      isMastered: mastered,
      isCompleted: isCompleted,
      nextReviewDate: nextReviewDate,
      srsStreak: srsStreak,
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Encodes word text for use as a Firestore map key (field paths cannot contain `.`).
String encodeWordFirestoreKey(String word) {
  return word.replaceAll('.', '․');
}

/// Decodes a Firestore map key back to the original word text.
String decodeWordFirestoreKey(String key) {
  return key.replaceAll('․', '.');
}
