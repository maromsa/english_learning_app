/// Parsed lesson content from Gemini `scene_description` mode.
class SceneTeachingMoment {
  const SceneTeachingMoment({
    required this.description,
    required this.targetObjects,
    required this.hebrewTeachingPoints,
    this.quizQuestions = const [],
    this.safetyNote,
    this.isFallback = false,
  });

  final String description;
  final List<String> targetObjects;
  final List<String> hebrewTeachingPoints;
  final List<String> quizQuestions;
  final String? safetyNote;

  /// True when scene_description failed and we show minimal copy instead.
  final bool isFallback;

  factory SceneTeachingMoment.fromMap(Map<String, dynamic> map) {
    return SceneTeachingMoment(
      description: _stringField(map['description']),
      targetObjects: _stringList(map['targetObjects']),
      hebrewTeachingPoints: _stringList(map['hebrewTeachingPoints']),
      quizQuestions: _stringList(map['quizQuestions']),
      safetyNote: _optionalString(map['safetyNote']),
    );
  }

  /// Kid-safe minimal content so the hunt never blocks on AI latency.
  factory SceneTeachingMoment.fallback({
    required String description,
    List<String> targetObjects = const [],
  }) {
    return SceneTeachingMoment(
      description: description,
      targetObjects: targetObjects,
      hebrewTeachingPoints: const [],
      isFallback: true,
    );
  }

  bool get hasRichContent =>
      !isFallback &&
      (hebrewTeachingPoints.isNotEmpty || targetObjects.isNotEmpty);

  static String _stringField(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return '';
  }

  static String? _optionalString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
