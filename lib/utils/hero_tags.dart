/// Stable [Hero] tag strings for shared-element transitions between screens.
abstract final class HeroTags {
  static String level(String levelId) => 'level_$levelId';

  static String wordImage(String levelId, String word) =>
      'word_image_${levelId}_$word';

  static String wordTitle(String levelId, String word) =>
      'word_title_${levelId}_$word';
}
