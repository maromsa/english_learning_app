import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/learned_word.dart';
import 'package:english_learning_app/providers/word_bank_provider.dart';
import 'package:english_learning_app/services/tts_service.dart';
import 'package:english_learning_app/utils/aurora_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Grid of words the child has successfully practiced ("My Vocabulary").
///
/// Each card shows the English word, an optional translation, and a 🔊
/// button that re-plays the word through [TtsService] (on-device, offline).
class WordBankScreen extends StatelessWidget {
  const WordBankScreen({super.key, this.ttsService});

  /// Optional [TtsService] override. Production leaves this null and reads
  /// the instance registered on [MultiProvider] in `main.dart`.
  final TtsService? ttsService;

  static const Key emptyKey = ValueKey<String>('word_bank_empty');

  static Key cardKey(String word) => ValueKey<String>('word_bank_card_$word');

  static Key speakKey(String word) => ValueKey<String>('word_bank_speak_$word');

  @override
  Widget build(BuildContext context) {
    final words = context.watch<WordBankProvider>().words;
    return Scaffold(
      backgroundColor: AuroraTokens.paper,
      appBar: AppBar(
        backgroundColor: AuroraTokens.paper,
        elevation: 0,
        foregroundColor: AuroraTokens.ink,
        title: Text(
          SparkStrings.wordBankTitle,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            color: AuroraTokens.ink,
          ),
        ),
      ),
      body: words.isEmpty
          ? const _EmptyBank()
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                AuroraTokens.s8,
                AuroraTokens.s4,
                AuroraTokens.s8,
                AuroraTokens.s16,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AuroraTokens.s8,
                crossAxisSpacing: AuroraTokens.s8,
                childAspectRatio: 1.15,
              ),
              itemCount: words.length,
              itemBuilder: (context, index) {
                return _WordCard(
                  learned: words[index],
                  ttsService: ttsService,
                );
              },
            ),
    );
  }
}

class _EmptyBank extends StatelessWidget {
  const _EmptyBank();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: WordBankScreen.emptyKey,
      child: Padding(
        padding: const EdgeInsets.all(AuroraTokens.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 72,
              color: AuroraTokens.blueberry.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AuroraTokens.s8),
            Text(
              SparkStrings.wordBankEmpty,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AuroraTokens.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.learned, this.ttsService});

  final LearnedWord learned;
  final TtsService? ttsService;

  Future<void> _speak(BuildContext context) async {
    final tts = ttsService ?? _tryReadTts(context);
    await tts?.speak(learned.word);
  }

  TtsService? _tryReadTts(BuildContext context) {
    try {
      return context.read<TtsService>();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final translation = learned.translation;
    return Card(
      key: WordBankScreen.cardKey(learned.word),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuroraTokens.rMd),
        side: const BorderSide(color: AuroraTokens.hair, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuroraTokens.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                key: WordBankScreen.speakKey(learned.word),
                tooltip: SparkStrings.hearWordSemantics(learned.word),
                icon: const Icon(
                  Icons.volume_up_rounded,
                  color: AuroraTokens.blueberry,
                ),
                iconSize: 28,
                onPressed: () => _speak(context),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  learned.word,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AuroraTokens.ink,
                  ),
                ),
              ),
            ),
            if (translation != null && translation.isNotEmpty)
              Text(
                translation,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AuroraTokens.inkSoft,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
