import 'package:english_learning_app/models/player_data.dart';
import 'package:english_learning_app/models/word_progress_entry.dart';
import 'package:english_learning_app/services/level_progress_service.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:english_learning_app/services/word_mastery_cloud_sync_service.dart';
import 'package:english_learning_app/services/word_mastery_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WordMasteryCloudSyncService', () {
    late SharedPreferences prefs;
    late UserDataService userDataService;
    late WordMasteryService masteryService;
    late WordMasteryCloudSyncService cloudSync;
    late LevelProgressService levelProgress;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      userDataService = UserDataService(firestore: FakeFirebaseFirestore());
      masteryService = WordMasteryService(prefs: prefs);
      cloudSync = WordMasteryCloudSyncService(userDataService: userDataService);
      levelProgress = LevelProgressService(
        wordMasteryService: masteryService,
        cloudSyncService: cloudSync,
      );
    });

    test('recordPronunciationScore pushes to Firestore for cloud users',
        () async {
      await levelProgress.recordPronunciationScore(
        userId: 'firebase_user',
        levelId: 'level1',
        word: 'Apple',
        stars: 3,
        isLocalUser: false,
      );

      final cloud = await userDataService.getLevelProgress(
        'firebase_user',
        'level1',
      );
      expect(cloud?.wordProgress['Apple']?.bestPronunciationStars, 3);
      expect(cloud?.wordProgress['Apple']?.isMastered, isTrue);
    });

    test('mergeCloudIntoLocal restores mastery and completion', () async {
      await userDataService.upsertWordProgress(
        userId: 'firebase_user',
        levelId: 'level1',
        word: 'Banana',
        progress: const WordProgressEntry(
          wordId: 'Banana',
          bestPronunciationStars: 3,
          isMastered: true,
          isCompleted: true,
        ),
        markWordCompleted: true,
      );

      await levelProgress.syncLevelProgressFromCloud(
        userId: 'firebase_user',
        levelId: 'level1',
        isLocalUser: false,
      );

      final mastery = await masteryService.getMastery(
        userId: 'firebase_user',
        levelId: 'level1',
        word: 'Banana',
      );
      expect(mastery.masteryLevel, 1.0);

      final completed = await levelProgress.isWordCompleted(
        'firebase_user',
        'level1',
        'Banana',
        isLocalUser: false,
      );
      expect(completed, isTrue);
    });

    test('recordPronunciationScore skips Firestore for local users', () async {
      await levelProgress.recordPronunciationScore(
        userId: 'local_user',
        levelId: 'level1',
        word: 'Cat',
        stars: 3,
        isLocalUser: true,
      );

      final cloud = await userDataService.getLevelProgress(
        'local_user',
        'level1',
      );
      expect(cloud, isNull);
    });
  });
}
