// test/models/achievement_test.dart
import 'package:english_learning_app/models/achievement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Achievement', () {
    test('stores title and requirementValue', () {
      final a = Achievement(
        id: 'coin_collector',
        title: 'Coin Collector',
        description: 'Earn 500 coins',
        icon: Icons.star,
        requirementValue: 500,
      );
      expect(a.title, 'Coin Collector');
      expect(a.requirementValue, 500);
      expect(a.name, 'Coin Collector');
    });

    test('name getter returns title', () {
      const title = 'First Word Learned';
      final a = Achievement(
        id: 'first',
        title: title,
        description: 'Desc',
        icon: Icons.flag,
      );
      expect(a.name, title);
    });

    test('requirementValue can be null', () {
      final a = Achievement(
        id: 'add_word',
        title: 'Add Word',
        description: 'Add a word',
        icon: Icons.add,
      );
      expect(a.requirementValue, isNull);
    });
  });
}
