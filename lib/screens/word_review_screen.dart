import 'dart:async';

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/word_review_provider.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:english_learning_app/services/tts_service.dart';
import 'package:english_learning_app/utils/aurora_tokens.dart';
import 'package:english_learning_app/widgets/ui/_barrel.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Active-recall multiple-choice quiz for words in the child's Word Bank.
///
/// Shows the English prompt, auto-plays it through [TtsService], and offers
/// Hebrew translations as large tappable options. A correct tap awards a
/// small coin reward and deals the next card; a miss highlights red and
/// lets the child try again.
class WordReviewScreen extends StatefulWidget {
  const WordReviewScreen({
    super.key,
    this.ttsService,
    this.coinReward = defaultCoinReward,
  });

  final TtsService? ttsService;
  final int coinReward;

  static const int defaultCoinReward = 2;

  static const Key promptKey = ValueKey<String>('word_review_prompt');
  static const Key successKey = ValueKey<String>('word_review_success');

  static Key optionKey(String translation) =>
      ValueKey<String>('word_review_option_$translation');

  @override
  State<WordReviewScreen> createState() => _WordReviewScreenState();
}

class _WordReviewScreenState extends State<WordReviewScreen> {
  String? _wrongPick;
  bool _correctFlash = false;
  bool _advancing = false;
  String? _spokenFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final review = context.read<WordReviewProvider>();
      if (!review.hasQuiz) review.generateQuiz();
      unawaited(_speakCurrent());
    });
  }

  TtsService? _tts(BuildContext context) {
    if (widget.ttsService != null) return widget.ttsService;
    try {
      return context.read<TtsService>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _speakCurrent() async {
    if (!mounted) return;
    final word = context.read<WordReviewProvider>().currentWord?.word;
    if (word == null || word.isEmpty) return;
    if (_spokenFor == word) return;
    _spokenFor = word;
    try {
      await _tts(context)?.speak(word);
    } catch (_) {
      // Best-effort: TTS must never surface to a child.
    }
  }

  Future<void> _onPick(String option) async {
    if (_advancing || _correctFlash) return;
    final review = context.read<WordReviewProvider>();
    final correct = review.checkAnswer(option);
    if (!correct) {
      unawaited(SoundService().playSound('error'));
      setState(() => _wrongPick = option);
      return;
    }

    setState(() {
      _wrongPick = null;
      _correctFlash = true;
      _advancing = true;
    });
    SoundService().playSuccessSound();

    try {
      await context.read<CoinProvider>().addCoins(widget.coinReward);
    } catch (e) {
      debugPrint('WordReviewScreen coin award failed: $e');
    }
    if (!mounted) return;

    try {
      await Celebration.fire(
        context,
        tier: CelebrationTier.micro,
        word: review.currentWord?.word,
        coinsEarned: widget.coinReward,
      );
    } catch (e) {
      debugPrint('WordReviewScreen celebration failed: $e');
    }
    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    review.generateQuiz();
    _spokenFor = null;
    setState(() {
      _correctFlash = false;
      _advancing = false;
      _wrongPick = null;
    });
    unawaited(_speakCurrent());
  }

  @override
  Widget build(BuildContext context) {
    final review = context.watch<WordReviewProvider>();
    final word = review.currentWord?.word ?? '';

    return Scaffold(
      backgroundColor: AuroraTokens.paper,
      appBar: AppBar(
        backgroundColor: AuroraTokens.paper,
        elevation: 0,
        foregroundColor: AuroraTokens.ink,
        title: Text(
          SparkStrings.wordReviewTitle,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            color: AuroraTokens.ink,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AuroraTokens.s12,
          AuroraTokens.s8,
          AuroraTokens.s12,
          AuroraTokens.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              SparkStrings.wordReviewPrompt,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AuroraTokens.inkSoft,
              ),
            ),
            const SizedBox(height: AuroraTokens.s8),
            SizedBox(
              height: 88,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        word,
                        key: WordReviewScreen.promptKey,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: AuroraTokens.ink,
                        ),
                      ),
                      if (_correctFlash) ...[
                        const SizedBox(width: AuroraTokens.s8),
                        const Icon(
                          key: WordReviewScreen.successKey,
                          Icons.check_circle_rounded,
                          color: AuroraTokens.mint,
                          size: 48,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AuroraTokens.s8),
            Expanded(
              child: ListView(
                children: [
                  for (final option in review.options) ...[
                    _ReviewOptionButton(
                      key: WordReviewScreen.optionKey(option),
                      label: option,
                      state: _stateFor(option, review),
                      onTap:
                          _advancing ? null : () => unawaited(_onPick(option)),
                    ),
                    const SizedBox(height: AuroraTokens.s8),
                  ],
                  if (_wrongPick != null && !_correctFlash)
                    Text(
                      SparkStrings.tryAgain,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AuroraTokens.coral,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ReviewOptionState _stateFor(String option, WordReviewProvider review) {
    if (_correctFlash && review.checkAnswer(option)) {
      return _ReviewOptionState.correct;
    }
    if (_wrongPick == option) return _ReviewOptionState.wrong;
    return _ReviewOptionState.idle;
  }
}

enum _ReviewOptionState { idle, correct, wrong }

class _ReviewOptionButton extends StatelessWidget {
  const _ReviewOptionButton({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _ReviewOptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border) = switch (state) {
      _ReviewOptionState.correct => (
          AuroraTokens.mint.withValues(alpha: 0.22),
          AuroraTokens.mint,
        ),
      _ReviewOptionState.wrong => (
          AuroraTokens.coral.withValues(alpha: 0.22),
          AuroraTokens.coral,
        ),
      _ReviewOptionState.idle => (
          Colors.white,
          AuroraTokens.blueberry.withValues(alpha: 0.45),
        ),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AuroraTokens.rMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuroraTokens.rMd),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(
            horizontal: AuroraTokens.s8,
            vertical: AuroraTokens.s8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuroraTokens.rMd),
            border: Border.all(color: border, width: 2.5),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AuroraTokens.ink,
            ),
          ),
        ),
      ),
    );
  }
}
