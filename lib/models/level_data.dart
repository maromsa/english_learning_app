// lib/models/level_data.dart
import 'word_data.dart';

class LevelData {
  final String name;
  final List<WordData> words;
  bool isUnlocked;
  int stars;

  LevelData({
    required this.name,
    required this.words,
    this.isUnlocked = false,
    this.stars = 0,
  });
}