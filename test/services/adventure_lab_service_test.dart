import 'package:english_learning_app/services/adventure_lab_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const baseContext = AdventureLabContext(
    levelName: 'Fruits Fiesta',
    levelDescription: 'Learn juicy fruit words with Spark!',
    vocabularyWords: ['Apple', 'Banana', 'Orange'],
    levelStars: 2,
    totalStars: 8,
    coins: 120,
    mood: 'curious scientist',
    unlockedWorldNames: ['Fruits Fiesta', 'Animal Park'],
  );

  group('AdventureLabService', () {
    test('parses structured JSON responses', () async {
      final service = AdventureLabService(
        generator: (prompt) async {
          expect(prompt, contains('Fruits Fiesta'));
          expect(prompt, contains('unlockedWorlds'));
          return '{"title":"Spark\'s Fruit Flight","scene":"Spark leads a shiny fruit parade.","challenge":"Name each fruit and make its sound!","encouragement":"Amazing explorer, your words are glowing!","vocabulary":["Apple","Banana"]}';
        },
      );

      final quest = await service.generateQuest(baseContext);

      expect(quest.title, 'Spark\'s Fruit Flight');
      expect(quest.scene, contains('fruit parade'));
      expect(quest.challenge, contains('Name each fruit'));
      expect(quest.pepTalk, contains('glowing'));
      expect(quest.vocabulary, containsAll(<String>['Apple', 'Banana']));
      expect(quest.parsedFromJson, isTrue);
    });

    test('falls back to raw text when JSON parsing fails', () async {
      final service = AdventureLabService(
        generator: (_) async =>
            "Let's imagine a floating fruit castle together!",
      );

      final quest = await service.generateQuest(baseContext);

      expect(quest.scene, contains('fruit castle'));
      expect(quest.parsedFromJson, isFalse);
      expect(quest.title, 'הפתעת ספרק');
    });

    test('throws when the generator reports an unavailable connection', () async {
      final service = AdventureLabService(generator: (_) async => null);

      expect(
        () => service.generateQuest(baseContext),
        throwsA(isA<AdventureLabGenerationException>()),
      );
    });
  });
}
