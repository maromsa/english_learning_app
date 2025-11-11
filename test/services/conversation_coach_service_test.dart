import 'package:english_learning_app/services/conversation_coach_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConversationCoachService', () {
    const setup = ConversationSetup(
      topic: 'space_mission',
      skillFocus: 'confidence',
      energyLevel: 'playful',
      focusWords: ['rocket', 'moon'],
      learnerName: 'אורי',
    );

    test('throws when the generator does not return a reply', () async {
      final service = ConversationCoachService(generator: (_) async => null);

      expect(
        () => service.startConversation(setup),
        throwsA(isA<ConversationGenerationException>()),
      );
    });

    test('parses structured JSON from the generator', () async {
      final service = ConversationCoachService(
        generator: (_) async =>
            '{"opening":"שלום!","sparkTip":"טיפ","vocabularyHighlights":["hello"],"suggestedLearnerReplies":["Hi Spark!"],"miniChallenge":"משימה קצרה"}',
      );

      final response = await service.startConversation(setup);
      expect(response.message, equals('שלום!'));
      expect(response.sparkTip, equals('טיפ'));
      expect(response.vocabularyHighlights, contains('hello'));
      expect(response.miniChallenge, equals('משימה קצרה'));
    });

    test('uses graceful fallback when follow-up JSON is malformed', () async {
      final service = ConversationCoachService(
        generator: (_) async => 'not json',
      );

      final history = [
        const ConversationTurn(
          speaker: ConversationSpeaker.spark,
          message: 'היי!',
        ),
        const ConversationTurn(
          speaker: ConversationSpeaker.learner,
          message: 'Hello Spark',
        ),
      ];

      final response = await service.continueConversation(
        setup: setup,
        history: history,
        learnerMessage: 'Hello Spark',
      );

      expect(response.message.isNotEmpty, isTrue);
      expect(response.suggestedLearnerReplies, isEmpty);
    });

    test('throws when generator is unavailable', () async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = previousPlatform;
      });

      final service = ConversationCoachService();

      expect(
        () => service.startConversation(setup),
        throwsA(isA<ConversationUnavailableException>()),
      );
    });
  });
}
