/// A single scavenger-hunt round: Spark asks the child to find something in the real world.
enum ScavengerChallengeKind {
  /// e.g. "Find something blue" — validated via [validationWord].
  color,

  /// e.g. "Find a fruit" — category noun for Gemini validate mode.
  category,

  /// e.g. "Find a dog" — concrete object name.
  object,
}

class ScavengerHuntChallenge {
  const ScavengerHuntChallenge({
    required this.id,
    required this.promptHebrew,
    required this.validationWord,
    required this.kind,
    this.emoji = '🔍',
    this.englishHint,
  });

  final String id;
  final String promptHebrew;

  /// English word sent to the proxy validate handler (e.g. `blue`, `fruit`, `dog`).
  final String validationWord;
  final ScavengerChallengeKind kind;
  final String emoji;

  /// Optional short English label shown under the Hebrew prompt.
  final String? englishHint;
}

/// Outcome of checking a captured photo against a challenge.
class ScavengerValidationResult {
  const ScavengerValidationResult({
    required this.approved,
    this.confidence,
    this.feedbackHebrew,
  });

  final bool approved;
  final double? confidence;
  final String? feedbackHebrew;
}
