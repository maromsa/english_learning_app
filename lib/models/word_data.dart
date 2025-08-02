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
}