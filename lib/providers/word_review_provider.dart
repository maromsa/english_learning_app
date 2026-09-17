import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/learned_word.dart';
import 'word_bank_provider.dart';

/// Active-recall quiz built from the child's [WordBankProvider].
///
/// [generateQuiz] picks a random learned word and 2–3 distractor
/// translations (falling back to [fallbackWords] when the bank is thin).
/// [checkAnswer] is case-insensitive and never advances the quiz — the UI
/// generates the next round after a correct tap.
class WordReviewProvider with ChangeNotifier {
  WordReviewProvider({
    required WordBankProvider wordBank,
    Random? random,
  })  : _wordBank = wordBank,
        _random = random ?? Random();

  /// Play is offered from the Word Bank only once this many words exist,
  /// so a quiz can usually fill 1 target + 3 distractors from the child's
  /// own vocabulary.
  static const int minBankSizeForPlay = 4;

  static const int _preferredDistractors = 3;
  static const int _minDistractors = 2;

  static final DateTime _fallbackDate = DateTime(2020, 1, 1);

  /// Offline Hebrew/English pairs used when the bank is too small or a
  /// word has no translation yet.
  static final List<LearnedWord> fallbackWords = [
    LearnedWord(
      word: 'cat',
      translation: 'חתול',
      dateLearned: _fallbackDate,
    ),
    LearnedWord(
      word: 'dog',
      translation: 'כלב',
      dateLearned: _fallbackDate,
    ),
    LearnedWord(
      word: 'sun',
      translation: 'שמש',
      dateLearned: _fallbackDate,
    ),
    LearnedWord(
      word: 'water',
      translation: 'מים',
      dateLearned: _fallbackDate,
    ),
  ];

  final WordBankProvider _wordBank;
  final Random _random;

  LearnedWord? _current;
  List<String> _options = const [];
  bool _disposed = false;

  LearnedWord? get currentWord => _current;
  List<String> get options => List.unmodifiable(_options);
  bool get hasQuiz => _current != null && _options.isNotEmpty;

  String? get correctTranslation =>
      _current == null ? null : _optionText(_current!);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Builds a new multiple-choice round. Safe to call with an empty bank:
  /// fallback words fill the target and distractors.
  void generateQuiz() {
    if (_disposed) return;

    final bankEligible = _wordBank.words.where(_hasTranslation).toList();
    final usedEnglish = {
      for (final w in bankEligible) w.word.toLowerCase(),
    };
    final extraFallbacks = [
      for (final fallback in fallbackWords)
        if (!usedEnglish.contains(fallback.word.toLowerCase())) fallback,
    ];

    final targetPool = bankEligible.isNotEmpty ? bankEligible : extraFallbacks;
    if (targetPool.isEmpty) {
      _current = null;
      _options = const [];
      _notify();
      return;
    }

    var candidates = List<LearnedWord>.from(targetPool);
    if (_current != null && candidates.length > 1) {
      final last = _current!.word.toLowerCase();
      candidates =
          candidates.where((w) => w.word.toLowerCase() != last).toList();
      if (candidates.isEmpty) {
        candidates = List<LearnedWord>.from(targetPool);
      }
    }
    _current = candidates[_random.nextInt(candidates.length)];
    final correct = _optionText(_current!);

    final distractorTexts = <String>{};
    for (final word in [...bankEligible, ...extraFallbacks]) {
      final text = _optionText(word);
      if (text.toLowerCase() == correct.toLowerCase()) continue;
      distractorTexts.add(text);
    }
    final shuffled = distractorTexts.toList()..shuffle(_random);
    var take = min(_preferredDistractors, shuffled.length);
    if (take < _minDistractors && shuffled.length >= _minDistractors) {
      take = _minDistractors;
    }

    _options = [correct, ...shuffled.take(take)]..shuffle(_random);
    _notify();
  }

  /// Whether [selectedTranslation] matches the current target. Does not
  /// mutate quiz state so a wrong tap can be retried.
  bool checkAnswer(String selectedTranslation) {
    final expected = correctTranslation;
    if (expected == null) return false;
    return selectedTranslation.trim().toLowerCase() ==
        expected.trim().toLowerCase();
  }

  static bool _hasTranslation(LearnedWord word) =>
      word.word.trim().isNotEmpty &&
      (word.translation?.trim().isNotEmpty ?? false);

  static String _optionText(LearnedWord word) {
    final translation = word.translation?.trim();
    if (translation != null && translation.isNotEmpty) return translation;
    return word.word.trim();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
