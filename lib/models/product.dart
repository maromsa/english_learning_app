import 'package:flutter/material.dart';

enum ProductCategory {
  accessories,
  powerUps,
  pets,
  magical,
  special,
}

enum ProductRarity {
  common,
  rare,
  epic,
  legendary,
}

class Product {
  final String id;
  final String name;
  final String englishName;
  final int price;
  final String assetImagePath;
  final ProductCategory category;
  final ProductRarity rarity;
  final String description;
  final String? specialEffect;

  Product({
    required this.id,
    required this.name,
    required this.englishName,
    required this.price,
    required this.assetImagePath,
    required this.category,
    required this.rarity,
    required this.description,
    this.specialEffect,
  });

  Color get rarityColor {
    switch (rarity) {
      case ProductRarity.common:
        return Colors.grey;
      case ProductRarity.rare:
        return Colors.blue;
      case ProductRarity.epic:
        return Colors.purple;
      case ProductRarity.legendary:
        return Colors.orange;
    }
  }

  String get rarityName {
    switch (rarity) {
      case ProductRarity.common:
        return 'רגיל';
      case ProductRarity.rare:
        return 'נדיר';
      case ProductRarity.epic:
        return 'אפי';
      case ProductRarity.legendary:
        return 'אגדי';
    }
  }

  String get categoryName {
    return category.categoryName;
  }
}

extension ProductCategoryExtension on ProductCategory {
  String get categoryName {
    switch (this) {
      case ProductCategory.accessories:
        return 'אביזרים';
      case ProductCategory.powerUps:
        return 'כוחות על';
      case ProductCategory.pets:
        return 'חיות מחמד';
      case ProductCategory.magical:
        return 'קסום';
      case ProductCategory.special:
        return 'מיוחד';
    }
  }
}
