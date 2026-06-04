import 'package:english_learning_app/utils/level_target_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LevelTargetCategory', () {
    test('resolves fruits level category', () {
      final category = LevelTargetCategory.resolve('level_fruits');
      expect(category, isNotNull);
      expect(category!.geminiCategory, 'Fruits');
      expect(category.displayHe, 'פירות');
    });

    test('JSON override wins over built-in map', () {
      final category = LevelTargetCategory.resolve(
        'level_fruits',
        targetCategoryFromLevel: 'Citrus',
        categoryLabelHeFromLevel: 'הדרים',
      );
      expect(category!.geminiCategory, 'Citrus');
      expect(category.displayHe, 'הדרים');
    });

    test('final level has no category constraint', () {
      expect(LevelTargetCategory.resolve('level_final'), isNull);
    });
  });
}
