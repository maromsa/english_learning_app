import 'package:english_learning_app/models/pronunciation_feedback.dart';
import 'package:english_learning_app/services/kid_speech_service.dart';
import 'package:english_learning_app/services/speech_feedback_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpeechFeedbackService.evaluatePronunciation', () {
    test('parses Gemini JSON with stars and feedback_message', () async {
      final service = SpeechFeedbackService(
        kidSpeech: KidSpeechService(),
        geminiGenerator: (prompt, {systemInstruction}) async {
          expect(prompt, contains('apple'));
          expect(prompt, contains('aple'));
          return '{"stars":2,"feedback_message":"יפה מאוד! עוד קצת תרגול."}';
        },
      );

      final result = await service.evaluatePronunciation(
        targetWord: 'apple',
        transcribedText: 'aple',
      );

      expect(result.stars, 2);
      expect(result.feedbackMessage, contains('יפה'));
      expect(result.fromGemini, isTrue);
    });

    test('clamps stars to 1-3', () async {
      final service = SpeechFeedbackService(
        geminiGenerator: (_, {systemInstruction}) async =>
            '{"stars":9,"feedback_message":"מעולה!"}',
      );

      final result = await service.evaluatePronunciation(
        targetWord: 'cat',
        transcribedText: 'cat',
      );

      expect(result.stars, 3);
    });

    test('returns gentle message when transcript is empty', () async {
      final service = SpeechFeedbackService(
        geminiGenerator: (_, {systemInstruction}) async => '{"stars":3}',
      );

      final result = await service.evaluatePronunciation(
        targetWord: 'dog',
        transcribedText: '   ',
      );

      expect(result.stars, 1);
      expect(result.fromGemini, isFalse);
    });

    test('uses local fallback when Gemini returns null', () async {
      final service = SpeechFeedbackService(
        geminiGenerator: (_, {systemInstruction}) async => null,
      );

      final close = await service.evaluatePronunciation(
        targetWord: 'cat',
        transcribedText: 'cat',
      );
      expect(close.stars, greaterThanOrEqualTo(2));
      expect(close.fromGemini, isFalse);

      final far = await service.evaluatePronunciation(
        targetWord: 'elephant',
        transcribedText: 'zzz',
      );
      expect(far.stars, greaterThanOrEqualTo(1));
      expect(far.fromGemini, isFalse);
    });

    test('caches identical evaluations', () async {
      var calls = 0;
      final service = SpeechFeedbackService(
        geminiGenerator: (_, {systemInstruction}) async {
          calls++;
          return '{"stars":3,"feedback_message":"מצוין!"}';
        },
      );

      await service.evaluatePronunciation(
        targetWord: 'moon',
        transcribedText: 'moon',
      );
      await service.evaluatePronunciation(
        targetWord: 'moon',
        transcribedText: 'moon',
      );

      expect(calls, 1);
    });
  });

  group('PronunciationFeedback', () {
    test('isStrongAttempt when stars >= 2', () {
      expect(
        const PronunciationFeedback(stars: 2, feedbackMessage: 'x').isStrongAttempt,
        isTrue,
      );
      expect(
        const PronunciationFeedback(stars: 1, feedbackMessage: 'x').isStrongAttempt,
        isFalse,
      );
    });
  });
}
