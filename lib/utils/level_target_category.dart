/// Maps level ids to Gemini [targetCategory] and a kid-friendly Hebrew label for UI.
class LevelTargetCategory {
  const LevelTargetCategory({
    required this.geminiCategory,
    required this.displayHe,
  });

  final String geminiCategory;
  final String displayHe;

  static const Map<String, LevelTargetCategory> byLevelId = {
    'level_fruits': LevelTargetCategory(
      geminiCategory: 'Fruits',
      displayHe: 'פירות',
    ),
    'level_animals': LevelTargetCategory(
      geminiCategory: 'Animals',
      displayHe: 'חיות',
    ),
    'level_magic_items': LevelTargetCategory(
      geminiCategory: 'Magic items',
      displayHe: 'פריטי קסם',
    ),
    'level_power_items': LevelTargetCategory(
      geminiCategory: 'Power items',
      displayHe: 'פריטי כוח',
    ),
    'level_vehicles': LevelTargetCategory(
      geminiCategory: 'Vehicles',
      displayHe: 'כלי תחבורה',
    ),
    'level_space': LevelTargetCategory(
      geminiCategory: 'Space',
      displayHe: 'חלל',
    ),
    'level_colors': LevelTargetCategory(
      geminiCategory: 'Colors',
      displayHe: 'צבעים',
    ),
    'level_food': LevelTargetCategory(
      geminiCategory: 'Food',
      displayHe: 'אוכל',
    ),
    'level_home': LevelTargetCategory(
      geminiCategory: 'Home',
      displayHe: 'דברים בבית',
    ),
    'level_sports': LevelTargetCategory(
      geminiCategory: 'Sports',
      displayHe: 'ספורט',
    ),
    'level_ocean': LevelTargetCategory(
      geminiCategory: 'Ocean',
      displayHe: 'עולם הים',
    ),
    'level_nature': LevelTargetCategory(
      geminiCategory: 'Nature',
      displayHe: 'טבע',
    ),
    'level_music': LevelTargetCategory(
      geminiCategory: 'Music',
      displayHe: 'מוזיקה',
    ),
    'level_clothing': LevelTargetCategory(
      geminiCategory: 'Clothing',
      displayHe: 'בגדים',
    ),
    'level_professions': LevelTargetCategory(
      geminiCategory: 'Professions',
      displayHe: 'מקצועות',
    ),
    'level_emotions': LevelTargetCategory(
      geminiCategory: 'Emotions',
      displayHe: 'רגשות',
    ),
    'level_weather': LevelTargetCategory(
      geminiCategory: 'Weather',
      displayHe: 'מזג אוויר',
    ),
    'level_body': LevelTargetCategory(
      geminiCategory: 'Human body',
      displayHe: 'גוף האדם',
    ),
    'level_family': LevelTargetCategory(
      geminiCategory: 'Family',
      displayHe: 'משפחה',
    ),
    'level_school': LevelTargetCategory(
      geminiCategory: 'School',
      displayHe: 'בית ספר',
    ),
    'level_shapes': LevelTargetCategory(
      geminiCategory: 'Shapes',
      displayHe: 'צורות',
    ),
    'level_time': LevelTargetCategory(
      geminiCategory: 'Time',
      displayHe: 'זמן',
    ),
    'level_actions': LevelTargetCategory(
      geminiCategory: 'Actions',
      displayHe: 'פעולות',
    ),
    'fallback_fruits': LevelTargetCategory(
      geminiCategory: 'Fruits',
      displayHe: 'פירות',
    ),
    'fallback_animals': LevelTargetCategory(
      geminiCategory: 'Animals',
      displayHe: 'חיות',
    ),
    'fallback_magic_items': LevelTargetCategory(
      geminiCategory: 'Magic items',
      displayHe: 'פריטי קסם',
    ),
  };

  static LevelTargetCategory? resolve(
    String levelId, {
    String? targetCategoryFromLevel,
    String? categoryLabelHeFromLevel,
  }) {
    if (targetCategoryFromLevel != null &&
        targetCategoryFromLevel.trim().isNotEmpty) {
      return LevelTargetCategory(
        geminiCategory: targetCategoryFromLevel.trim(),
        displayHe: (categoryLabelHeFromLevel?.trim().isNotEmpty ?? false)
            ? categoryLabelHeFromLevel!.trim()
            : targetCategoryFromLevel.trim(),
      );
    }
    return byLevelId[levelId];
  }
}
