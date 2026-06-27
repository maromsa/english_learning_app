// lib/models/level_data.dart
import 'word_data.dart';

class LevelData {
  final String id;
  final String name;
  final String? description;
  /// English category sent to Gemini for camera capture (e.g. "Fruits").
  final String? targetCategory;
  /// Hebrew label shown when category validation fails.
  final String? categoryLabelHe;
  final int reward;
  final int unlockStars;
  final double positionX;
  final double positionY;
  final List<WordData> words;
  bool isUnlocked;
  int stars;

  /// True when this level is the last in its chapter — triggers epic celebration.
  final bool isChapterEnd;

  LevelData({
    required this.id,
    required this.name,
    required this.words,
    this.description,
    this.targetCategory,
    this.categoryLabelHe,
    this.reward = 0,
    this.unlockStars = 0,
    this.positionX = 0.5,
    this.positionY = 0.5,
    this.isUnlocked = false,
    this.stars = 0,
    this.isChapterEnd = false,
  });

  factory LevelData.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    if (id == null || id.isEmpty) {
      throw ArgumentError('LevelData JSON missing "id": $json');
    }
    if (name == null || name.isEmpty) {
      throw ArgumentError('LevelData JSON missing "name": $json');
    }

    final wordsJson = (json['words'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(WordData.fromJson)
        .toList();

    return LevelData(
      id: id,
      name: name,
      description: json['description'] as String?,
      targetCategory: json['targetCategory'] as String?,
      categoryLabelHe: json['categoryLabelHe'] as String?,
      reward: json['reward'] as int? ?? 0,
      unlockStars: json['unlockStars'] as int? ?? 0,
      positionX: ((json['position'] as Map<String, dynamic>?)?['x'] as num?)
              ?.toDouble() ??
          0.5,
      positionY: ((json['position'] as Map<String, dynamic>?)?['y'] as num?)
              ?.toDouble() ??
          0.5,
      words: wordsJson,
      isChapterEnd: json['isChapterEnd'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        if (targetCategory != null) 'targetCategory': targetCategory,
        if (categoryLabelHe != null) 'categoryLabelHe': categoryLabelHe,
        'reward': reward,
        'unlockStars': unlockStars,
        'position': {'x': positionX, 'y': positionY},
        'words': words.map((w) => w.toJson()).toList(),
        'isUnlocked': isUnlocked,
        'stars': stars,
      };
}
