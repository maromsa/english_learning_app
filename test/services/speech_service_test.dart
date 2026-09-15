import 'package:english_learning_app/services/speech_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpeechService.normalize', () {
    test('lowercases, strips punctuation, and collapses spaces', () {
      expect(
        SpeechService.normalize('  The CAT, is sleeping! '),
        'the cat is sleeping',
      );
    });

    test('returns empty for punctuation-only input', () {
      expect(SpeechService.normalize('...!!!'), isEmpty);
    });
  });

  group('SpeechService.matches', () {
    const target = 'The cat is sleeping';

    test('accepts an exact match ignoring case and punctuation', () {
      expect(SpeechService.matches(target, 'THE CAT IS SLEEPING!'), isTrue);
    });

    test('accepts a close child pronunciation', () {
      expect(SpeechService.matches(target, 'the cat is sleepin'), isTrue);
    });

    test('accepts extra filler words around the sentence', () {
      expect(
        SpeechService.matches(target, 'um the cat is sleeping please'),
        isTrue,
      );
    });

    test('rejects an unrelated phrase', () {
      expect(SpeechService.matches(target, 'I drink water'), isFalse);
    });

    test('rejects a single target word spoken alone', () {
      expect(SpeechService.matches(target, 'cat'), isFalse);
    });

    test('rejects empty or whitespace transcripts', () {
      expect(SpeechService.matches(target, '   '), isFalse);
      expect(SpeechService.matches(target, ''), isFalse);
    });
  });

  group('SpeechService.similarity', () {
    test('is 1 for identical strings', () {
      expect(SpeechService.similarity('hello', 'hello'), 1);
    });

    test('is 0 when either side is empty', () {
      expect(SpeechService.similarity('hello', ''), 0);
      expect(SpeechService.similarity('', 'hello'), 0);
    });
  });

  group('SpeechService.isTerminalStatus', () {
    test('recognizes session-end statuses', () {
      expect(SpeechService.isTerminalStatus('done'), isTrue);
      expect(SpeechService.isTerminalStatus('notListening'), isTrue);
      expect(SpeechService.isTerminalStatus('doneNoResult'), isTrue);
    });

    test('ignores an active listening status', () {
      expect(SpeechService.isTerminalStatus('listening'), isFalse);
    });
  });
}
