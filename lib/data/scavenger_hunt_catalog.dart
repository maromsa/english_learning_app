import 'dart:math';

import 'package:english_learning_app/models/scavenger_hunt_challenge.dart';

/// Kid-friendly scavenger prompts. Validation words match the deployed proxy `validate` mode.
class ScavengerHuntCatalog {
  ScavengerHuntCatalog._();

  static final Random _random = Random();

  static const List<ScavengerHuntChallenge> all = [
    ScavengerHuntChallenge(
      id: 'color_blue',
      promptHebrew: 'מצאו משהו כחול! 💙',
      validationWord: 'blue',
      kind: ScavengerChallengeKind.color,
      emoji: '💙',
      englishHint: 'something blue',
    ),
    ScavengerHuntChallenge(
      id: 'color_red',
      promptHebrew: 'מצאו משהו אדום! ❤️',
      validationWord: 'red',
      kind: ScavengerChallengeKind.color,
      emoji: '❤️',
      englishHint: 'something red',
    ),
    ScavengerHuntChallenge(
      id: 'color_green',
      promptHebrew: 'מצאו משהו ירוק! 💚',
      validationWord: 'green',
      kind: ScavengerChallengeKind.color,
      emoji: '💚',
      englishHint: 'something green',
    ),
    ScavengerHuntChallenge(
      id: 'color_yellow',
      promptHebrew: 'מצאו משהו צהוב! 💛',
      validationWord: 'yellow',
      kind: ScavengerChallengeKind.color,
      emoji: '💛',
      englishHint: 'something yellow',
    ),
    ScavengerHuntChallenge(
      id: 'fruit',
      promptHebrew: 'מצאו פרי! 🍎',
      validationWord: 'fruit',
      kind: ScavengerChallengeKind.category,
      emoji: '🍎',
      englishHint: 'a fruit',
    ),
    ScavengerHuntChallenge(
      id: 'book',
      promptHebrew: 'מצאו ספר! 📚',
      validationWord: 'book',
      kind: ScavengerChallengeKind.object,
      emoji: '📚',
      englishHint: 'a book',
    ),
    ScavengerHuntChallenge(
      id: 'cup',
      promptHebrew: 'מצאו כוס! 🥤',
      validationWord: 'cup',
      kind: ScavengerChallengeKind.object,
      emoji: '🥤',
      englishHint: 'a cup',
    ),
    ScavengerHuntChallenge(
      id: 'shoe',
      promptHebrew: 'מצאו נעל! 👟',
      validationWord: 'shoe',
      kind: ScavengerChallengeKind.object,
      emoji: '👟',
      englishHint: 'a shoe',
    ),
    ScavengerHuntChallenge(
      id: 'toy',
      promptHebrew: 'מצאו צעצוע! 🧸',
      validationWord: 'toy',
      kind: ScavengerChallengeKind.object,
      emoji: '🧸',
      englishHint: 'a toy',
    ),
    ScavengerHuntChallenge(
      id: 'plant',
      promptHebrew: 'מצאו צמח! 🌿',
      validationWord: 'plant',
      kind: ScavengerChallengeKind.category,
      emoji: '🌿',
      englishHint: 'a plant',
    ),
    ScavengerHuntChallenge(
      id: 'ball',
      promptHebrew: 'מצאו כדור! ⚽',
      validationWord: 'ball',
      kind: ScavengerChallengeKind.object,
      emoji: '⚽',
      englishHint: 'a ball',
    ),
    ScavengerHuntChallenge(
      id: 'bottle',
      promptHebrew: 'מצאו בקבוק! 🍼',
      validationWord: 'bottle',
      kind: ScavengerChallengeKind.object,
      emoji: '🍼',
      englishHint: 'a bottle',
    ),
  ];

  /// Picks [count] distinct challenges in random order.
  static List<ScavengerHuntChallenge> pickSession({int count = 5}) {
    final pool = List<ScavengerHuntChallenge>.from(all)..shuffle(_random);
    return pool.take(count.clamp(1, pool.length)).toList();
  }
}
