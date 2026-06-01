import 'package:english_learning_app/services/kid_speech_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KidSpeechService.isSessionEndStatus', () {
    test('recognizes terminal speech statuses', () {
      expect(KidSpeechService.isSessionEndStatus('done'), isTrue);
      expect(KidSpeechService.isSessionEndStatus('notListening'), isTrue);
      expect(KidSpeechService.isSessionEndStatus('doneNoResult'), isTrue);
    });

    test('ignores active listening status', () {
      expect(KidSpeechService.isSessionEndStatus('listening'), isFalse);
    });
  });
}
