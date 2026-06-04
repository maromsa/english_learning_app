import 'package:english_learning_app/models/word_progress_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WordProgressEntry', () {
    test('fromMap and toMap round-trip', () {
      const entry = WordProgressEntry(
        wordId: 'Apple',
        bestPronunciationStars: 3,
        isMastered: true,
        isCompleted: true,
      );

      final restored = WordProgressEntry.fromMap(entry.toMap());
      expect(restored.wordId, 'Apple');
      expect(restored.bestPronunciationStars, 3);
      expect(restored.isMastered, isTrue);
      expect(restored.isCompleted, isTrue);
    });

    test('mergeWith keeps best stars and flags', () {
      const a = WordProgressEntry(
        wordId: 'Dog',
        bestPronunciationStars: 2,
        isMastered: false,
      );
      const b = WordProgressEntry(
        wordId: 'Dog',
        bestPronunciationStars: 3,
        isMastered: true,
        isCompleted: true,
      );

      final merged = a.mergeWith(b);
      expect(merged.bestPronunciationStars, 3);
      expect(merged.isMastered, isTrue);
      expect(merged.isCompleted, isTrue);
    });

    test('encodeWordFirestoreKey escapes dots', () {
      expect(encodeWordFirestoreKey('Mr. Smith'), 'Mr\u2024 Smith');
      expect(decodeWordFirestoreKey('Mr\u2024 Smith'), 'Mr. Smith');
    });
  });
}
