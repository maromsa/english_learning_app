/// Simple emoji hints for common English nouns shown in teaching moments.
String emojiForEnglishWord(String word) {
  const map = <String, String>{
    'apple': '🍎',
    'ball': '⚽',
    'book': '📚',
    'bottle': '🍼',
    'car': '🚗',
    'cat': '🐱',
    'chair': '🪑',
    'cup': '🥤',
    'dog': '🐕',
    'flower': '🌸',
    'fruit': '🍎',
    'plant': '🌿',
    'shoe': '👟',
    'table': '🪑',
    'toy': '🧸',
    'tree': '🌳',
    'blue': '💙',
    'red': '❤️',
    'green': '💚',
    'yellow': '💛',
    'orange': '🟠',
    'black': '⬛',
    'white': '⬜',
  };

  final key = word.trim().toLowerCase();
  return map[key] ?? '✨';
}
