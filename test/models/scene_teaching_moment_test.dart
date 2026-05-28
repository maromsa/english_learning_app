import 'package:english_learning_app/models/scene_teaching_moment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SceneTeachingMoment', () {
    test('fromMap parses scene_description fields', () {
      final moment = SceneTeachingMoment.fromMap({
        'description': 'רואה שולחן וספר',
        'targetObjects': ['table', 'book'],
        'hebrewTeachingPoints': ['table = שולחן', 'book = ספר'],
        'quizQuestions': ['איפה הספר?'],
        'safetyNote': 'נראה בטוח',
      });

      expect(moment.description, 'רואה שולחן וספר');
      expect(moment.targetObjects, ['table', 'book']);
      expect(moment.hebrewTeachingPoints.length, 2);
      expect(moment.quizQuestions, ['איפה הספר?']);
      expect(moment.safetyNote, 'נראה בטוח');
      expect(moment.isFallback, isFalse);
      expect(moment.hasRichContent, isTrue);
    });

    test('fallback marks isFallback and skips rich flag', () {
      final moment = SceneTeachingMoment.fallback(
        description: 'כל הכבוד!',
        targetObjects: ['ball'],
      );

      expect(moment.isFallback, isTrue);
      expect(moment.hasRichContent, isFalse);
    });
  });
}
