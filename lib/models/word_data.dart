// lib/models/word_data.dart
class WordData {
  final String word;
  final String imageUrl;
  bool isCompleted;

  WordData({
    required this.word,
    required this.imageUrl,
    this.isCompleted = false,
  });

  factory WordData.fromJson(Map<String, dynamic> json) {
    return WordData(
      word: json['word'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
    );
  }
}