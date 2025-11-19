/// Model for player character/avatar
class PlayerCharacter {
  PlayerCharacter({
    required this.characterId,
    required this.characterName,
    this.avatarUrl,
    this.color,
  });

  factory PlayerCharacter.fromMap(Map<String, dynamic> map) {
    return PlayerCharacter(
      characterId: map['characterId'] as String? ?? 'default',
      characterName: map['characterName'] as String? ?? 'שחקן',
      avatarUrl: map['avatarUrl'] as String?,
      color: map['color'] as int?,
    );
  }

  final String characterId;
  final String characterName;
  final String? avatarUrl;
  final int? color; // Color as int value

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'characterId': characterId,
      'characterName': characterName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (color != null) 'color': color,
    };
  }

  PlayerCharacter copyWith({
    String? characterId,
    String? characterName,
    String? avatarUrl,
    int? color,
  }) {
    return PlayerCharacter(
      characterId: characterId ?? this.characterId,
      characterName: characterName ?? this.characterName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      color: color ?? this.color,
    );
  }
}

/// Available character options
class CharacterOption {
  const CharacterOption({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    this.description,
  });

  final String id;
  final String name;
  final String emoji; // Emoji or icon identifier
  final int color; // Color value
  final String? description;

  static const List<CharacterOption> availableCharacters = [
    CharacterOption(
      id: 'spark',
      name: 'ספרק',
      emoji: '✨',
      color: 0xFFFFD700, // Gold
      description: 'החבר הקסום שלך!',
    ),
    CharacterOption(
      id: 'star',
      name: 'כוכב',
      emoji: '⭐',
      color: 0xFFFFA500, // Orange
      description: 'כוכב זוהר ומבריק!',
    ),
    CharacterOption(
      id: 'rainbow',
      name: 'קשת',
      emoji: '🌈',
      color: 0xFF9370DB, // MediumPurple
      description: 'צבעוני ומשמח!',
    ),
    CharacterOption(
      id: 'rocket',
      name: 'טיל',
      emoji: '🚀',
      color: 0xFF4169E1, // RoyalBlue
      description: 'מהיר וחזק!',
    ),
    CharacterOption(
      id: 'dragon',
      name: 'דרקון',
      emoji: '🐉',
      color: 0xFFDC143C, // Crimson
      description: 'אמיץ וחזק!',
    ),
    CharacterOption(
      id: 'wizard',
      name: 'קוסם',
      emoji: '🧙',
      color: 0xFF8B00FF, // Violet
      description: 'חכם וקסום!',
    ),
    CharacterOption(
      id: 'robot',
      name: 'רובוט',
      emoji: '🤖',
      color: 0xFF00CED1, // DarkTurquoise
      description: 'חכם וטכנולוגי!',
    ),
    CharacterOption(
      id: 'unicorn',
      name: 'חד-קרן',
      emoji: '🦄',
      color: 0xFFFF69B4, // HotPink
      description: 'קסום וייחודי!',
    ),
  ];

  static CharacterOption? getById(String id) {
    try {
      return availableCharacters.firstWhere((char) => char.id == id);
    } catch (e) {
      return null;
    }
  }
}

