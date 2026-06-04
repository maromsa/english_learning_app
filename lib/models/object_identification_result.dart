/// Result of Gemini image identification with optional level category constraint.
sealed class ObjectIdentificationResult {
  const ObjectIdentificationResult();
}

class ObjectIdentificationSuccess extends ObjectIdentificationResult {
  const ObjectIdentificationSuccess(this.word);

  final String word;
}

class ObjectIdentificationCategoryMismatch extends ObjectIdentificationResult {
  const ObjectIdentificationCategoryMismatch(this.identified);

  final String identified;
}

class ObjectIdentificationUnclear extends ObjectIdentificationResult {
  const ObjectIdentificationUnclear();
}
