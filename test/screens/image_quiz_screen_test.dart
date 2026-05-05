import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/spark_overlay_controller.dart';
import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/screens/image_quiz_screen.dart';
import 'package:english_learning_app/services/level_progress_service.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:english_learning_app/services/word_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake [LevelProgressService] that records [markWordCompleted] calls.
class FakeLevelProgressService extends LevelProgressService {
  FakeLevelProgressService() : super();

  final List<({String userId, String levelId, String word, bool isLocalUser})>
      markWordCompletedCalls = [];

  @override
  Future<void> markWordCompleted(
    String userId,
    String levelId,
    String word, {
    bool isLocalUser = false,
  }) async {
    markWordCompletedCalls.add((
      userId: userId,
      levelId: levelId,
      word: word,
      isLocalUser: isLocalUser,
    ));
  }
}

List<WordData> _testWords() => [
      WordData(word: 'Apple', publicId: 'apple', imageUrl: null),
      WordData(word: 'Banana', publicId: 'banana', imageUrl: null),
      WordData(word: 'Orange', publicId: 'orange', imageUrl: null),
      WordData(word: 'Grape', publicId: 'grape', imageUrl: null),
    ];

/// Returns words immediately for tests (no network/cache).
class FakeWordRepository extends WordRepository {
  FakeWordRepository(this.words, {SharedPreferences? prefs})
      : super(prefs: prefs);

  final List<WordData> words;

  @override
  Future<List<WordData>> loadWords({
    required bool remoteEnabled,
    required List<WordData> fallbackWords,
    String cloudName = '',
    String tagName = '',
    int maxResults = 50,
    String cacheNamespace = 'default',
  }) async => List<WordData>.from(words);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ImageQuizScreen shows loading then content when words loaded',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final coinProvider = CoinProvider(
      userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
    );
    final sparkController = SparkOverlayController();
    final userSession = UserSessionProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CoinProvider>.value(value: coinProvider),
          ChangeNotifierProvider<SparkOverlayController>.value(
            value: sparkController,
          ),
          ChangeNotifierProvider<UserSessionProvider>.value(value: userSession),
        ],
        child: MaterialApp(
          home: ImageQuizScreen(
            levelId: 'test_level',
            wordsForLevel: _testWords(),
            wordRepository: FakeWordRepository(_testWords()),
          ),
        ),
      ),
    );

    await tester.pump();
    // With FakeWordRepository load may complete in same frame; allow one more frame for async
    await tester.pump(const Duration(milliseconds: 200));

    // After load we should see the question area (target word)
    expect(find.text('Apple'), findsWidgets);
  });

  testWidgets('correct answer calls markWordCompleted and addCoins', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fakeProgress = FakeLevelProgressService();
    final coinProvider = CoinProvider(
      userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
    );
    final sparkController = SparkOverlayController();
    final userSession = UserSessionProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CoinProvider>.value(value: coinProvider),
          ChangeNotifierProvider<SparkOverlayController>.value(
            value: sparkController,
          ),
          ChangeNotifierProvider<UserSessionProvider>.value(value: userSession),
        ],
        child: MaterialApp(
          home: ImageQuizScreen(
            levelId: 'test_level',
            wordsForLevel: _testWords(),
            wordRepository: FakeWordRepository(_testWords()),
            levelProgressService: fakeProgress,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    final initialCoins = coinProvider.coins;

    // Tap the correct option (target word for first question is first in list = Apple)
    final optionApple = find.byKey(const Key('option_Apple'));
    expect(optionApple, findsOneWidget);
    await tester.ensureVisible(optionApple);
    await tester.tap(optionApple);
    await tester.pump(const Duration(milliseconds: 500));

    expect(fakeProgress.markWordCompletedCalls.length, 1);
    expect(fakeProgress.markWordCompletedCalls.first.levelId, 'test_level');
    expect(fakeProgress.markWordCompletedCalls.first.word, 'Apple');
    expect(coinProvider.coins, greaterThanOrEqualTo(initialCoins + 10));
  });
}
