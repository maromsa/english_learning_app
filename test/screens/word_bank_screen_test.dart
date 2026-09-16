import 'package:english_learning_app/models/learned_word.dart';
import 'package:english_learning_app/providers/word_bank_provider.dart';
import 'package:english_learning_app/screens/word_bank_screen.dart';
import 'package:english_learning_app/services/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTtsService extends TtsService {
  _FakeTtsService();

  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    spoken.add(trimmed);
  }
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required WordBankProvider bank,
  _FakeTtsService? tts,
}) async {
  final fakeTts = tts ?? _FakeTtsService();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: bank),
        Provider<TtsService>.value(value: fakeTts),
      ],
      child: MaterialApp(
        home: WordBankScreen(ttsService: fakeTts),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('empty bank shows the empty state', (tester) async {
    final bank = WordBankProvider(initial: const []);
    await _pumpScreen(tester, bank: bank);
    expect(find.byKey(WordBankScreen.emptyKey), findsOneWidget);
  });

  testWidgets('cards show the word, translation, and speak on tap',
      (tester) async {
    final tts = _FakeTtsService();
    final bank = WordBankProvider(
      initial: [
        LearnedWord(
          word: 'cat',
          translation: 'חתול',
          dateLearned: DateTime(2026, 9, 16),
        ),
      ],
    );
    await _pumpScreen(tester, bank: bank, tts: tts);

    expect(find.byKey(WordBankScreen.cardKey('cat')), findsOneWidget);
    expect(find.text('cat'), findsOneWidget);
    expect(find.text('חתול'), findsOneWidget);

    await tester.tap(find.byKey(WordBankScreen.speakKey('cat')));
    await tester.pump();
    expect(tts.spoken, ['cat']);
  });
}
