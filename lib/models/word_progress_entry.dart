/// Per-word progress stored in Firestore under [LevelProgress.wordProgress].
class WordProgressEntry {
  const WordProgressEntry({
    required this.wordId,
    this.bestPronunciationStars = 0,
    this.isMastered = false,
    this.isCompleted = false,
  });

  factory WordProgressEntry.fromMap(Map<String, dynamic> map) {
    final rawStars = map['bestPronunciationStars'];
    var stars = 0;
    if (rawStars is int) {
      stars = rawStars.clamp(0, 3);
    } else if (rawStars is num) {
      stars = rawStars.toInt().clamp(0, 3);
    }

    return WordProgressEntry(
      wordId: map['wordId'] as String? ?? '',
      bestPronunciationStars: stars,
      isMastered: map['isMastered'] as bool? ?? false,
      isCompleted: map['isCompleted'] as bool? ?? false,
    );
  }

  /// Canonical word identifier (display text or [WordData.publicId] when set).
  final String wordId;

  final int bestPronunciationStars;
  final bool isMastered;
  final bool isCompleted;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'wordId': wordId,
        'bestPronunciationStars': bestPronunciationStars,
        'isMastered': isMastered,
        if (isCompleted) 'isCompleted': isCompleted,
      };

  WordProgressEntry copyWith({
    String? wordId,
    int? bestPronunciationStars,
    bool? isMastered,
    bool? isCompleted,
  }) {
    return WordProgressEntry(
      wordId: wordId ?? this.wordId,
      bestPronunciationStars:
          bestPronunciationStars ?? this.bestPronunciationStars,
      isMastered: isMastered ?? this.isMastered,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  /// Merges [other] into this entry, keeping the best star rating and flags.
  WordProgressEntry mergeWith(WordProgressEntry other) {
    final nextStars = bestPronunciationStars > other.bestPronunciationStars
        ? bestPronunciationStars
        : other.bestPronunciationStars;
    return WordProgressEntry(
      wordId: wordId.isNotEmpty ? wordId : other.wordId,
      bestPronunciationStars: nextStars,
      isMastered: isMastered || other.isMastered,
      isCompleted: isCompleted || other.isCompleted,
    );
  }

  /// Builds an entry from local [WordMasteryEntry] data.
  static WordProgressEntry fromMastery({
    required String wordId,
    required double masteryLevel,
    required int bestPronunciationStars,
    bool isCompleted = false,
  }) {
    final mastered =
        masteryLevel >= 1.0 || bestPronunciationStars >= 3;
    return WordProgressEntry(
      wordId: wordId,
      bestPronunciationStars: bestPronunciationStars,
      isMastered: mastered,
      isCompleted: isCompleted,
    );
  }
}

/// Encodes word text for use as a Firestore map key (field paths cannot contain `.`).
String encodeWordFirestoreKey(String word) {
  return word.replaceAll('.', '\u2024');
}

/// Decodes a Firestore map key back to the original word text.
String decodeWordFirestoreKey(String key) {
  return key.replaceAll('\u2024', '.');
}
