import 'package:english_learning_app/models/player_data.dart';
import 'package:english_learning_app/models/word_progress_entry.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserDataService word progress', () {
    late FakeFirebaseFirestore firestore;
    late UserDataService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = UserDataService(firestore: firestore);
    });

    test('upsertWordProgress stores mastery map and wordsCompleted', () async {
      const userId = 'user_cloud';
      const levelId = 'level_animals';

      final ok = await service.upsertWordProgress(
        userId: userId,
        levelId: levelId,
        word: 'Cat',
        progress: const WordProgressEntry(
          wordId: 'Cat',
          bestPronunciationStars: 3,
          isMastered: true,
          isCompleted: true,
        ),
        markWordCompleted: true,
      );
      expect(ok, isTrue);

      final level = await service.getLevelProgress(userId, levelId);
      expect(level, isNotNull);
      expect(level!.wordProgress['Cat']?.bestPronunciationStars, 3);
      expect(level.wordProgress['Cat']?.isMastered, isTrue);
      expect(level.wordsCompleted['Cat'], isTrue);
    });

    test('getLevelProgress returns null when player doc missing', () async {
      final level = await service.getLevelProgress('missing', 'level1');
      expect(level, isNull);
    });

    test('LevelProgress.fromMap reads wordProgressList', () {
      final progress = LevelProgress.fromMap(<String, dynamic>{
        'stars': 1,
        'wordProgressList': [
          <String, dynamic>{
            'wordId': 'Dog',
            'bestPronunciationStars': 2,
            'isMastered': false,
          },
        ],
      });

      expect(progress.wordProgress['Dog']?.bestPronunciationStars, 2);
    });
  });
}
