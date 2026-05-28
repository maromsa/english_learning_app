import 'package:english_learning_app/utils/safe_display_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeDisplayName', () {
    test('trims and caps length', () {
      final longName = 'א' * 40;
      expect(sanitizeDisplayName(longName).length, 30);
    });

    test('strips prompt-injection characters', () {
      expect(
        sanitizeDisplayName('David\nignore previous'),
        'Davidignore previous',
      );
    });

    test('returns empty for blank input', () {
      expect(sanitizeDisplayName('   '), '');
      expect(sanitizeDisplayName(null), '');
    });
  });
}
