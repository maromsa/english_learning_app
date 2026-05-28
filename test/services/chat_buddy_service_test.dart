import 'package:english_learning_app/services/chat_buddy_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const context = ChatBuddyContext(
    focusWords: ['rocket', 'moon'],
    topic: 'space_mission',
    learnerName: 'אורי',
  );

  group('ChatBuddyService', () {
    test('parses opening JSON with scaffolding words', () async {
      final service = ChatBuddyService(
        geminiGenerator: (_, {systemInstruction}) async =>
            '{"opening":"שלום אורי!","sparkTip":"נסו לומר hello","scaffoldingWords":["hello","rocket","moon"]}',
      );

      final turn = await service.startSession(context);

      expect(turn.message, 'שלום אורי!');
      expect(turn.sparkTip, 'נסו לומר hello');
      expect(turn.scaffoldingWords, ['hello', 'rocket', 'moon']);
      expect(turn.parsedFromJson, isTrue);
    });

    test('parses follow-up JSON with 2 scaffolding words', () async {
      final service = ChatBuddyService(
        geminiGenerator: (_, {systemInstruction}) async =>
            '{"reply":"מעולה!","sparkTip":"כל הכבוד","scaffoldingWords":["star","fly"]}',
      );

      final history = [
        const ChatBuddyMessage(
          speaker: ChatBuddySpeaker.spark,
          text: 'היי!',
        ),
        const ChatBuddyMessage(
          speaker: ChatBuddySpeaker.learner,
          text: 'Hello Spark',
        ),
      ];

      final turn = await service.continueChat(
        context: context,
        history: history,
        learnerMessage: 'Hello Spark',
      );

      expect(turn.message, 'מעולה!');
      expect(turn.scaffoldingWords, ['star', 'fly']);
    });

    test('falls back when JSON is malformed', () async {
      final service = ChatBuddyService(
        geminiGenerator: (_, {systemInstruction}) async => 'plain text reply',
      );

      final turn = await service.startSession(context);

      expect(turn.message, contains('plain text'));
      expect(turn.scaffoldingWords, isEmpty);
      expect(turn.parsedFromJson, isFalse);
    });

    test('throws when generator returns null', () async {
      final service = ChatBuddyService(
        geminiGenerator: (_, {systemInstruction}) async => null,
      );

      expect(
        () => service.startSession(context),
        throwsA(isA<ChatBuddyGenerationException>()),
      );
    });
  });
}
