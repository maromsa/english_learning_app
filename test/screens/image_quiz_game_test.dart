import 'package:english_learning_app/screens/image_quiz_game.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('quiz items use image assets that exist', () async {
    for (final item in quizItems) {
      final data = await rootBundle.load(item.imageAsset);
      expect(data.lengthInBytes, greaterThan(0), reason: 'Asset ${item.imageAsset} should not be empty');
    }
  });

  test('quiz items include the correct answer among the options', () {
    for (final item in quizItems) {
      final options = item.getShuffledAnswers();
      expect(options, contains(item.correctAnswer));
      expect(options.length, item.wrongAnswers.length + 1);
    }
  });
}
