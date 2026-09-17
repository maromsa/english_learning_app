import 'dart:async';

import 'package:english_learning_app/models/sentence_question.dart';
import 'package:english_learning_app/providers/sentence_practice_provider.dart';
import 'package:english_learning_app/services/gemini_sentence_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _seed = SentenceQuestion(
  fullEnglishSentence: 'The cat is sleeping',
  hebrewTranslation: 'החתול ישן',
  missingWord: 'cat',
  options: ['cat', 'dog', 'fish'],
);

const _ai = SentenceQuestion(
  fullEnglishSentence: 'I drink water',
  hebrewTranslation: 'אני שותה מים',
  missingWord: 'water',
  options: ['juice', 'water', 'milk'],
);

class _FakeGemini extends GeminiSentenceService {
  _FakeGemini({this.sentences = const [_ai], this.onGenerate})
      : super(generator: (prompt, {systemInstruction}) async => null);

  final List<SentenceQuestion> sentences;
  final Future<void> Function()? onGenerate;
  int calls = 0;

  @override
  Future<List<SentenceQuestion>> generateSentences({
    int count = GeminiSentenceService.defaultCount,
    List<String> avoid = const [],
  }) async {
    calls++;
    await onGenerate?.call();
    return sentences;
  }
}

void main() {
  group('SentencePracticeProvider', () {
    test('starts with the playable seed queue and is not loading', () {
      final provider = SentencePracticeProvider(initial: [_seed]);
      expect(provider.questions, [_seed]);
      expect(provider.isLoadingAi, isFalse);
      expect(provider.canRefill, isFalse);
    });

    test('refillIfNeeded is a no-op without Gemini', () async {
      final provider = SentencePracticeProvider(initial: [_seed]);
      expect(await provider.refillIfNeeded(), isFalse);
      expect(provider.questions, hasLength(1));
    });

    test('appends Gemini sentences and clears the loading flag', () async {
      final gemini = _FakeGemini();
      final provider = SentencePracticeProvider(
        initial: [_seed],
        gemini: gemini,
      );

      final added = await provider.refillIfNeeded();

      expect(added, isTrue);
      expect(gemini.calls, 1);
      expect(provider.isLoadingAi, isFalse);
      expect(provider.questions, [_seed, _ai]);
    });

    test('toggles isLoadingAi while the proxy is in flight', () async {
      final started = Completer<void>();
      final finish = Completer<void>();
      final gemini = _FakeGemini(
        onGenerate: () async {
          started.complete();
          await finish.future;
        },
      );
      final provider = SentencePracticeProvider(
        initial: [_seed],
        gemini: gemini,
      );

      final future = provider.refillIfNeeded();
      await started.future;
      expect(provider.isLoadingAi, isTrue);

      finish.complete();
      expect(await future, isTrue);
      expect(provider.isLoadingAi, isFalse);
    });

    test('malformed / empty Gemini replies leave the static queue intact',
        () async {
      final gemini = _FakeGemini(sentences: const []);
      final provider = SentencePracticeProvider(
        initial: [_seed],
        gemini: gemini,
      );

      expect(await provider.refillIfNeeded(), isFalse);
      expect(provider.questions, [_seed]);
      expect(provider.canRefill, isFalse);
    });

    test('coalesces concurrent refill calls into one request', () async {
      final finish = Completer<void>();
      final gemini = _FakeGemini(
        onGenerate: () => finish.future,
      );
      final provider = SentencePracticeProvider(
        initial: [_seed],
        gemini: gemini,
      );

      final first = provider.refillIfNeeded();
      final second = provider.refillIfNeeded();
      finish.complete();

      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(gemini.calls, 1);
    });
  });
}
