/// One vocabulary entry a child has successfully practiced (local-first).
///
/// Deserialization is tolerant (§2.3): a missing or malformed document
/// parses to an empty word / epoch date rather than throwing.
class LearnedWord {
  const LearnedWord({
    required this.word,
    this.translation,
    required this.dateLearned,
  });

  final String word;
  final String? translation;
  final DateTime dateLearned;

  factory LearnedWord.fromJson(Map<String, dynamic> json) {
    return LearnedWord(
      word: _toWord(json['word']),
      translation: _toNonEmptyString(json['translation']),
      dateLearned: _toDate(json['dateLearned']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
        'word': word,
        if (translation != null && translation!.isNotEmpty)
          'translation': translation,
        'dateLearned': dateLearned.toIso8601String(),
      };

  LearnedWord copyWith({
    String? word,
    String? translation,
    DateTime? dateLearned,
    bool clearTranslation = false,
  }) {
    return LearnedWord(
      word: word ?? this.word,
      translation: clearTranslation ? null : (translation ?? this.translation),
      dateLearned: dateLearned ?? this.dateLearned,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearnedWord &&
          other.word == word &&
          other.translation == translation &&
          other.dateLearned == dateLearned);

  @override
  int get hashCode => Object.hash(word, translation, dateLearned);

  static String _toWord(dynamic value) {
    if (value is String) return value.trim();
    return '';
  }

  static String? _toNonEmptyString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static DateTime? _toDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }
}
