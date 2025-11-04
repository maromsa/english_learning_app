// lib/models/word_data.dart
class WordData {
  final String word;
  final String? publicId; // From Cloudinary
  final String? imageUrl; // For local files from camera
  bool isCompleted;
  bool stickerUnlocked;

  WordData({
    required this.word,
    this.publicId,
    this.imageUrl,
    this.isCompleted = false,
    this.stickerUnlocked = false,
  });

  factory WordData.fromJson(Map<String, dynamic> json) {
    final word = json['word'] as String?;
    if (word == null || word.isEmpty) {
      throw ArgumentError('WordData JSON is missing a "word" field: $json');
    }

    return WordData(
      word: word,
      publicId: json['publicId'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      stickerUnlocked: json['stickerUnlocked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'word': word,
        if (publicId != null) 'publicId': publicId,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'isCompleted': isCompleted,
        'stickerUnlocked': stickerUnlocked,
      };
}