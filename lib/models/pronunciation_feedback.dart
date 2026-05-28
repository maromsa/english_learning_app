/// AI pronunciation evaluation for a single spoken attempt.
class PronunciationFeedback {
  const PronunciationFeedback({
    required this.stars,
    required this.feedbackMessage,
    this.fromGemini = true,
  });

  /// 1 = keep practicing, 2 = good try, 3 = excellent.
  final int stars;
  final String feedbackMessage;

  /// `false` when a local fallback was used (offline / parse error).
  final bool fromGemini;

  bool get isStrongAttempt => stars >= 2;

  PronunciationFeedback copyWith({
    int? stars,
    String? feedbackMessage,
    bool? fromGemini,
  }) {
    return PronunciationFeedback(
      stars: stars ?? this.stars,
      feedbackMessage: feedbackMessage ?? this.feedbackMessage,
      fromGemini: fromGemini ?? this.fromGemini,
    );
  }
}
