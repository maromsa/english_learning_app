// test/models/product_test.dart
import 'package:english_learning_app/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Product', () {
    test('should create Product with all fields', () {
      final product = Product(
        id: 'test_id',
        name: 'Test Product',
        englishName: 'Test Product',
        price: 100,
        assetImagePath: 'assets/test.jpg',
        category: ProductCategory.accessories,
        rarity: ProductRarity.common,
        description: 'A test product',
      );
      expect(product.id, 'test_id');
      expect(product.name, 'Test Product');
      expect(product.price, 100);
      expect(product.assetImagePath, 'assets/test.jpg');
    });

    test('should create Product with different values', () {
      final product = Product(
        id: 'magic_hat',
        name: 'Magic Hat',
        englishName: 'Magic Hat',
        price: 50,
        assetImagePath: 'assets/images/magic_hat.jpg',
        category: ProductCategory.magical,
        rarity: ProductRarity.rare,
        description: 'A magical hat',
      );
      expect(product.id, 'magic_hat');
      expect(product.name, 'Magic Hat');
      expect(product.price, 50);
      expect(product.assetImagePath, 'assets/images/magic_hat.jpg');
    });
  });
}
