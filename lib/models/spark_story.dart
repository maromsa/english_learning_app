// lib/models/spark_story.dart
//
// SparkStory — a short Gemini-generated story adapted to the child's level.
//
// Each story contains 5–7 sentences. Every sentence has:
//   - English text (displayed large).
//   - Hebrew translation (shown on tap / toggle).
//   - A highlight word from the learner's vocabulary.
//   - An optional image URL from Pixabay for illustration.

class StoryPage {
  const StoryPage({
    required this.english,
    required this.hebrew,
    required this.highlightWord,
    this.imageUrl,
  });

  /// The English sentence displayed to the learner.
  final String english;

  /// Hebrew translation of the sentence.
  final String hebrew;

  /// The vocabulary word highlighted in this sentence (bold in UI).
  final String highlightWord;

  /// Pixabay image URL for this sentence. May be null.
  final String? imageUrl;

  factory StoryPage.fromJson(Map<String, dynamic> json) {
    return StoryPage(
      english: json['english'] as String? ?? '',
      hebrew: json['hebrew'] as String? ?? '',
      highlightWord: json['highlightWord'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'english': english,
        'hebrew': hebrew,
        'highlightWord': highlightWord,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };
}

class SparkStory {
  const SparkStory({
    required this.title,
    required this.titleHebrew,
    required this.pages,
    required this.words,
    required this.generatedAt,
  });

  /// English story title.
  final String title;

  /// Hebrew story title.
  final String titleHebrew;

  /// Story pages (one per sentence).
  final List<StoryPage> pages;

  /// The vocabulary words used in this story.
  final List<String> words;

  /// When the story was generated (used for caching).
  final DateTime generatedAt;

  bool get isEmpty => pages.isEmpty;

  factory SparkStory.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'] as List<dynamic>? ?? [];
    return SparkStory(
      title: json['title'] as String? ?? 'Spark\'s Story',
      titleHebrew: json['titleHebrew'] as String? ?? 'הסיפור של ספארק',
      pages: rawPages
          .whereType<Map<String, dynamic>>()
          .map(StoryPage.fromJson)
          .toList(),
      words: (json['words'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [],
      generatedAt: json['generatedAt'] != null
          ? DateTime.tryParse(json['generatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'titleHebrew': titleHebrew,
        'pages': pages.map((p) => p.toJson()).toList(),
        'words': words,
        'generatedAt': generatedAt.toIso8601String(),
      };
}
