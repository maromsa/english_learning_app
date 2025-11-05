import 'package:english_learning_app/services/adventure_story_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const baseContext = AdventureStoryContext(
    levelName: 'Fruits Fiesta',
    levelDescription: 'Learn juicy fruit words with Spark!',
    vocabularyWords: ['Apple', 'Banana', 'Orange'],
    levelStars: 2,
    totalStars: 8,
    coins: 120,
    mood: 'curious scientist',
  );

  group('AdventureStoryService', () {
    test('parses structured JSON responses', () async {
      final service = AdventureStoryService(
        generator: (prompt) async {
          expect(prompt, contains('Fruits Fiesta'));
          return '{"title":"Spark\'s Fruit Flight","scene":"Spark the mentor leads a shiny fruit parade.","challenge":"Name each fruit and make its sound!","encouragement":"Amazing explorer, your words are glowing!","vocabulary":["Apple","Banana"]}';
        },
      );

      final story = await service.generateAdventure(baseContext);

      expect(story.title, 'Spark\'s Fruit Flight');
      expect(story.scene, contains('fruit parade'));
      expect(story.challenge, contains('Name each fruit'));
      expect(story.vocabulary, containsAll(<String>['Apple', 'Banana']));
      expect(story.parsedFromJson, isTrue);
    });

      test('falls back to raw text when JSON parsing fails', () async {
        final service = AdventureStoryService(
          generator: (_) async => 'Let\'s imagine a floating fruit castle together!',
        );

        final story = await service.generateAdventure(baseContext);

        expect(story.scene, contains('fruit castle'));
        expect(story.parsedFromJson, isFalse);
        expect(story.title, 'הפתעת ספרק');
      });

      test('uses stub story when enabled and Gemini is unavailable', () async {
        final service = AdventureStoryService(enableStub: true);

        final story = await service.generateAdventure(baseContext);

        expect(story.title, contains('Fruits Fiesta'));
        expect(story.scene, contains('ספרק טס אל Fruits Fiesta'));
        expect(story.vocabulary, equals(baseContext.vocabularyWords));
        expect(story.prompt, 'stub');
      });

    test('throws when generator is unavailable', () async {
      final service = AdventureStoryService(enableStub: false);

      expect(
        () => service.generateAdventure(baseContext),
        throwsA(isA<AdventureStoryUnavailableException>()),
      );
    });
  });
}
