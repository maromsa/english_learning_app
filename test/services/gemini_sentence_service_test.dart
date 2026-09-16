import 'package:english_learning_app/models/sentence_question.dart';
import 'package:english_learning_app/services/gemini_sentence_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeminiSentenceService.parseResponse', () {
    test('parses a JSON array of playable sentences', () {
      const raw = '''
[
  {
    "fullEnglishSentence": "The cat is sleeping",
    "hebrewTranslation": "החתול ישן",
    "missingWord": "cat",
    "options": ["cat", "dog", "fish"]
  },
  {
    "fullEnglishSentence": "I drink water",
    "hebrewTranslation": "אני שותה מים",
    "missingWord": "water",
    "options": ["juice", "water", "milk"]
  }
]
''';
      final parsed = GeminiSentenceService.parseResponse(raw);
      expect(parsed, hasLength(2));
      expect(parsed.first.fullEnglishSentence, 'The cat is sleeping');
      expect(parsed.first.missingWord, 'cat');
      expect(parsed.first.isPlayable, isTrue);
    });

    test('strips markdown fences and accepts wrapped {sentences: []}', () {
      const raw = '''
```json
{"sentences":[
  {"sentence":"The sun is hot","hebrew":"השמש חמה","word":"hot","choices":["hot","cold","soft"]}
]}
```
''';
      final parsed = GeminiSentenceService.parseResponse(raw);
      expect(parsed, hasLength(1));
      expect(parsed.single.fullEnglishSentence, 'The sun is hot');
      expect(parsed.single.hebrewTranslation, 'השמש חמה');
      expect(parsed.single.missingWord, 'hot');
    });

    test('returns empty for malformed text', () {
      expect(GeminiSentenceService.parseResponse('not json at all'), isEmpty);
      expect(GeminiSentenceService.parseResponse(''), isEmpty);
      expect(GeminiSentenceService.parseResponse('{"oops": true}'), isEmpty);
    });

    test('drops unplayable entries and caps at count', () {
      const raw = '''
[
  {"fullEnglishSentence":"","missingWord":"cat","options":["cat","dog"]},
  {"fullEnglishSentence":"Hello there friend","missingWord":"friend","options":["friend","teacher","doctor"]},
  {"fullEnglishSentence":"We play ball","missingWord":"play","options":["play","run","sit"]},
  {"fullEnglishSentence":"She reads a book","missingWord":"book","options":["book","ball","box"]}
]
''';
      final parsed = GeminiSentenceService.parseResponse(raw, count: 2);
      expect(parsed, hasLength(2));
      expect(parsed.first.missingWord, 'friend');
      expect(parsed.last.missingWord, 'play');
    });
  });

  group('GeminiSentenceService.generateSentences', () {
    test('parses a successful generator reply', () async {
      final service = GeminiSentenceService(
        generator: (prompt, {systemInstruction}) async => '''
[{"fullEnglishSentence":"The bird sings","hebrewTranslation":"הציפור שרה","missingWord":"bird","options":["bird","bear","boat"]}]
''',
      );

      final result = await service.generateSentences(count: 3);

      expect(result, hasLength(1));
      expect(result.single.missingWord, 'bird');
    });

    test('returns an empty list when the generator throws or times out',
        () async {
      final failing = GeminiSentenceService(
        generator: (prompt, {systemInstruction}) async {
          throw StateError('proxy down');
        },
      );
      expect(await failing.generateSentences(), isEmpty);

      final timedOut = GeminiSentenceService(
        timeout: const Duration(milliseconds: 10),
        generator: (prompt, {systemInstruction}) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return '[]';
        },
      );
      expect(await timedOut.generateSentences(), isEmpty);
    });

    test('returns empty when the generator yields null or blank text',
        () async {
      final service = GeminiSentenceService(
        generator: (prompt, {systemInstruction}) async => '   ',
      );
      expect(await service.generateSentences(), isEmpty);
    });

    test('buildPrompt mentions the requested count and avoid list', () {
      final prompt = GeminiSentenceService.buildPrompt(
        count: 3,
        avoid: const ['The cat is sleeping'],
      );
      expect(prompt, contains('Create 3'));
      expect(prompt, contains('The cat is sleeping'));
      expect(prompt, contains('fullEnglishSentence'));
    });
  });

  group('SentenceQuestion playability of parsed AI rows', () {
    test('a parsed row with two options is playable', () {
      final parsed = GeminiSentenceService.parseResponse('''
[{"fullEnglishSentence":"I like soup","missingWord":"soup","options":["soup","snow"]}]
''');
      expect(parsed.single, isA<SentenceQuestion>());
      expect(parsed.single.isPlayable, isTrue);
    });
  });
}
