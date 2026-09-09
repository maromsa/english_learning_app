// lib/models/sentence_question.dart

/// A single fill-in-the-blank sentence exercise used by
/// [SentencePracticeScreen].
///
/// The child sees [hebrewTranslation] for meaning, hears [fullEnglishSentence]
/// read aloud, and picks [missingWord] out of [options] to complete the
/// sentence.
///
/// Deserialization is tolerant (§2.3): a document written before a field
/// existed must still parse — unknown / missing keys default rather than
/// throw. A question that ends up with no usable options is surfaced via
/// [isPlayable] so callers can skip it instead of crashing.
class SentenceQuestion {
  const SentenceQuestion({
    required this.fullEnglishSentence,
    required this.hebrewTranslation,
    required this.missingWord,
    required this.options,
  });

  /// The complete English sentence, including [missingWord] in place.
  final String fullEnglishSentence;

  /// Hebrew translation of [fullEnglishSentence], shown as a comprehension aid.
  final String hebrewTranslation;

  /// The word removed from the sentence — the correct answer.
  final String missingWord;

  /// Answer choices offered to the child. May or may not already contain
  /// [missingWord]; use [optionsWithAnswer] for a display-ready list.
  final List<String> options;

  /// Placeholder rendered where [missingWord] belongs. The surrounding
  /// sentence already supplies its own spacing.
  static const String blank = '____';

  factory SentenceQuestion.fromJson(Map<String, dynamic> json) {
    return SentenceQuestion(
      fullEnglishSentence:
          (json['fullEnglishSentence'] as String? ?? '').trim(),
      hebrewTranslation: (json['hebrewTranslation'] as String? ?? '').trim(),
      missingWord: (json['missingWord'] as String? ?? '').trim(),
      options: _parseOptions(json['options']),
    );
  }

  Map<String, dynamic> toJson() => {
        'fullEnglishSentence': fullEnglishSentence,
        'hebrewTranslation': hebrewTranslation,
        'missingWord': missingWord,
        'options': options,
      };

  /// [fullEnglishSentence] with the first whole-word occurrence of
  /// [missingWord] replaced by [blank]. Falls back to appending the blank when
  /// the word can't be located (e.g. an inflected form), so the child always
  /// sees a gap to fill.
  String get displaySentence {
    if (fullEnglishSentence.isEmpty) return blank;
    if (missingWord.isEmpty) return fullEnglishSentence;
    final pattern = RegExp(
      r'\b' + RegExp.escape(missingWord) + r'\b',
      caseSensitive: false,
    );
    if (pattern.hasMatch(fullEnglishSentence)) {
      return fullEnglishSentence.replaceFirst(pattern, blank);
    }
    return '$fullEnglishSentence $blank';
  }

  /// [options] guaranteed to contain [missingWord] exactly once, with
  /// case-insensitive duplicates removed and original order preserved.
  List<String> get optionsWithAnswer {
    final seen = <String>{};
    final out = <String>[];
    for (final option in [...options, missingWord]) {
      final trimmed = option.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed.toLowerCase())) out.add(trimmed);
    }
    return out;
  }

  /// Whether this question can be presented: it needs a sentence, a missing
  /// word, and at least two distinct choices.
  bool get isPlayable =>
      fullEnglishSentence.isNotEmpty &&
      missingWord.isNotEmpty &&
      optionsWithAnswer.length >= 2;

  /// Whether [candidate] is the correct answer (case-insensitive, trimmed).
  bool isCorrect(String candidate) =>
      candidate.trim().toLowerCase() == missingWord.trim().toLowerCase();

  static List<String> _parseOptions(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Object>()
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
}
