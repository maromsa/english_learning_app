import 'package:english_learning_app/utils/english_word_emoji.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('emojiForEnglishWord returns mapped emoji or default', () {
    expect(emojiForEnglishWord('ball'), '⚽');
    expect(emojiForEnglishWord('Ball'), '⚽');
    expect(emojiForEnglishWord('unknown_word'), '✨');
  });
}
