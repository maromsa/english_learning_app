import '../services/word_mastery_service.dart';
import 'word_data.dart';

/// A word in the sticker collection with merged progress for display.
class CollectionWordItem {
  const CollectionWordItem({
    required this.word,
    required this.levelId,
    required this.mastery,
    required this.isCompleted,
  });

  final WordData word;
  final String levelId;
  final WordMasteryEntry mastery;
  final bool isCompleted;

  /// Full-color sticker with glowing 3-star badge.
  bool get isMastered => mastery.isMastered;

  /// Silhouette + lock until the learner earns 3-star mastery.
  bool get isLocked => !isMastered;
}
