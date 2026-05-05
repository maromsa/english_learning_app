// lib/models/word_data.dart

/// Core word model used across levels and practice modes.
///
/// New fields:
/// - [masteryLevel] in the range \[0.0, 1.0] describing how well the learner
///   knows the word (0 = unseen, 1 = mastered).
/// - [lastReviewed] timestamp of the most recent meaningful practice.
///
/// These fields are optional in persisted JSON so that older caches and
/// word bundles remain fully backward compatible.
class WordData {
  final String word;
  final String? searchHint;
  final String? publicId; // From Cloudinary
  final String? imageUrl; // For local files from camera

  /// Whether this word is marked as completed for the current level/session.
  bool isCompleted;

  bool stickerUnlocked;

  /// Mastery score for the word in \[0.0, 1.0].
  ///
  /// This value is typically persisted per-user via [WordMasteryService] and
  /// then merged back into [WordData] instances used in the UI.
  double masteryLevel;

  /// When the learner last meaningfully reviewed this word.
  DateTime? lastReviewed;

  WordData({
    required this.word,
    this.searchHint,
    this.publicId,
    this.imageUrl,
    this.isCompleted = false,
    this.stickerUnlocked = false,
    double? masteryLevel,
    this.lastReviewed,
  }) : masteryLevel = _clampMastery(masteryLevel ?? 0.0);

  factory WordData.fromJson(Map<String, dynamic> json) {
    final word = json['word'] as String?;
    if (word == null || word.isEmpty) {
      throw ArgumentError('WordData JSON is missing a "word" field: $json');
    }

    final rawHint = json['searchHint'] as String?;
    final rawQuery = json['query'] as String?;
    final normalizedHint = rawHint?.trim();
    final normalizedQuery = rawQuery?.trim();

    final isCompleted = json['isCompleted'] as bool? ?? false;
    final stickerUnlocked = json['stickerUnlocked'] as bool? ?? false;

    final masteryFromJson = _parseMastery(json['masteryLevel']);

    // If we have legacy data that only stored `isCompleted`, treat a completed
    // word with no explicit mastery as fully mastered. This keeps historical
    // progress meaningful when moving to mastery-based logic.
    final masteryLevel = masteryFromJson == null && isCompleted
        ? 1.0
        : (masteryFromJson ?? 0.0);

    final lastReviewed = _parseLastReviewed(json['lastReviewed']);

    return WordData(
      word: word,
      searchHint: normalizedHint != null && normalizedHint.isNotEmpty
          ? normalizedHint
          : normalizedQuery != null && normalizedQuery.isNotEmpty
              ? normalizedQuery
              : null,
      publicId: json['publicId'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isCompleted: isCompleted,
      stickerUnlocked: stickerUnlocked,
      masteryLevel: masteryLevel,
      lastReviewed: lastReviewed,
    );
  }

  Map<String, dynamic> toJson() => {
        'word': word,
        if (searchHint != null && searchHint!.isNotEmpty)
          'searchHint': searchHint,
        if (publicId != null) 'publicId': publicId,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'isCompleted': isCompleted,
        'stickerUnlocked': stickerUnlocked,
        // Mastery fields are optional to keep older readers tolerant.
        if (masteryLevel > 0.0) 'masteryLevel': masteryLevel,
        if (lastReviewed != null) 'lastReviewed': lastReviewed!.toIso8601String(),
      };

  static double _clampMastery(double value) {
    if (value.isNaN || value.isInfinite) {
      return 0.0;
    }
    final numClamped = value.clamp(0.0, 1.0) as num;
    return numClamped.toDouble();
  }

  static double? _parseMastery(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is num) {
      return _clampMastery(raw.toDouble());
    }
    if (raw is String) {
      final parsed = double.tryParse(raw.trim());
      if (parsed == null) {
        return null;
      }
      return _clampMastery(parsed);
    }
    return null;
  }

  static DateTime? _parseLastReviewed(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }
    if (raw is int) {
      // Backward-friendly: support millisecond timestamps if ever stored.
      try {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
