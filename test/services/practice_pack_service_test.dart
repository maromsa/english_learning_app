import 'package:english_learning_app/services/practice_pack_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PracticePackService', () {
    const request = PracticePackRequest(
      skillFocus: 'speaking',
      timeAvailable: '10_minutes',
      energyLevel: 'balanced',
      playMode: 'family',
      focusWords: ['friend', 'play'],
      learnerName: 'נועה',
    );

    test('builds stub pack when generator is not available', () async {
      final service = PracticePackService(
        generator: null,
        enableStub: true,
      );

      final pack = await service.generatePack(request);
      expect(pack.activities, isNotEmpty);
      expect(pack.pepTalk, contains('ספרק'));
      expect(pack.activities.first.steps.length, greaterThan(1));
    });

    test('parses JSON pack from the generator', () async {
      final json = '''
{
  "pepTalk":"בוקר טוב!",
  "celebration":"🎈",
  "activities":[
    {
      "title":"משחק ראשון",
      "goal":"אימון מהיר",
      "steps":["צעד 1","צעד 2","צעד 3"],
      "englishFocus":["hello","sun"],
      "boost":"הוסיפו ריקוד"
    },
    {
      "title":"משחק שני",
      "goal":"משפטים",
      "steps":["אב","ב"],
      "englishFocus":["play"],
      "boost":"הוסיפו צבע"
    },
    {
      "title":"משחק שלישי",
      "goal":"קצב",
      "steps":["ג"],
      "englishFocus":["jump"],
      "boost":"הוסיפו מחיאת כף"
    }
  ]
}
''';

      final service = PracticePackService(
        generator: (_) async => json,
        enableStub: false,
      );

      final pack = await service.generatePack(request);
      expect(pack.pepTalk, equals('בוקר טוב!'));
      expect(pack.celebration, equals('🎈'));
      expect(pack.activities, hasLength(3));
      expect(pack.activities.first.englishFocus, contains('hello'));
    });

    test('falls back to stub when JSON cannot be parsed', () async {
      final service = PracticePackService(
        generator: (_) async => 'oops',
        enableStub: false,
      );

      final pack = await service.generatePack(request);
      expect(pack.activities, isNotEmpty);
      expect(pack.parsedFromJson, isFalse);
    });
  });
}
