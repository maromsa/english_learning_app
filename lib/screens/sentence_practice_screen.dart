// lib/screens/sentence_practice_screen.dart
import 'dart:async';

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/sentence_question.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:english_learning_app/utils/aurora_tokens.dart';
import 'package:english_learning_app/widgets/ui/_barrel.dart';
import 'package:english_learning_app/widgets/word_speaker_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Sentence-level ("fill in the blank") practice — Phase 3.
///
/// The child reads a Hebrew translation, taps 🔊 to hear the **full** English
/// sentence (via `SparkVoiceService`, through [WordSpeakerButton]), and picks
/// the missing word from a set of option cards. A correct pick plays the
/// victory sound, awards coins through
/// [CoinProvider], fires a micro [Celebration], and advances to the next
/// sentence. A wrong pick nudges the child to try again.
///
/// The screen is self-contained: it takes its [questions] directly (mirroring
/// `MemoryMatchScreen.wordsForLevel`) so it stays trivial to widget-test.
class SentencePracticeScreen extends StatefulWidget {
  const SentencePracticeScreen({
    super.key,
    required this.questions,
    this.coinReward = defaultCoinReward,
    this.speak,
  });

  /// The sentence exercises for this session. Unplayable entries (missing
  /// sentence / word / too few options) are filtered out on init.
  final List<SentenceQuestion> questions;

  /// Coins granted per correctly-completed sentence.
  final int coinReward;

  /// Test seam forwarded to [WordSpeakerButton]. Production leaves this null,
  /// so the button uses `SparkVoiceService`.
  final Future<bool> Function(String sentence)? speak;

  static const int defaultCoinReward = 15;

  @override
  State<SentencePracticeScreen> createState() => _SentencePracticeScreenState();
}

class _SentencePracticeScreenState extends State<SentencePracticeScreen> {
  late final List<SentenceQuestion> _questions =
      widget.questions.where((q) => q.isPlayable).toList(growable: false);

  int _index = 0;
  String? _selected;
  bool _answeredCorrectly = false;
  bool _advancing = false;
  int _correctCount = 0;
  bool _finished = false;

  SentenceQuestion get _current => _questions[_index];

  Future<void> _handleOption(String option) async {
    if (_answeredCorrectly || _advancing) return;

    final bool correct = _current.isCorrect(option);
    setState(() => _selected = option);

    if (!correct) {
      unawaited(SoundService().playSound('error'));
      return;
    }

    setState(() {
      _answeredCorrectly = true;
      _correctCount++;
    });
    SoundService().playSuccessSound();

    await context.read<CoinProvider>().addCoins(widget.coinReward);
    if (!mounted) return;

    await Celebration.fire(
      context,
      tier: CelebrationTier.micro,
      word: _current.missingWord,
    );
    if (!mounted) return;

    _advancing = true;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() {
      _advancing = false;
      if (_index + 1 >= _questions.length) {
        _finished = true;
      } else {
        _index++;
        _selected = null;
        _answeredCorrectly = false;
      }
    });
  }

  void _restart() {
    setState(() {
      _index = 0;
      _selected = null;
      _answeredCorrectly = false;
      _advancing = false;
      _correctCount = 0;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuroraTokens.paper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          SparkStrings.sentencePracticeTitle,
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.w800,
            color: AuroraTokens.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: _questions.isEmpty
            ? _buildEmptyState()
            : _finished
                ? _buildSummary()
                : _buildQuestion(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuroraTokens.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_rounded,
              size: 64,
              color: AuroraTokens.inkMute,
            ),
            const SizedBox(height: AuroraTokens.s8),
            Text(
              SparkStrings.sentencePracticeEmpty,
              textAlign: TextAlign.center,
              style: GoogleFonts.heebo(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AuroraTokens.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final question = _current;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AuroraTokens.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProgressLabel(current: _index + 1, total: _questions.length),
          const SizedBox(height: AuroraTokens.s8),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AuroraTokens.rLg),
            ),
            color: AuroraTokens.paper2,
            child: Padding(
              padding: const EdgeInsets.all(AuroraTokens.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    question.hebrewTranslation,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.heebo(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AuroraTokens.inkSoft,
                    ),
                  ),
                  const SizedBox(height: AuroraTokens.s8),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      _answeredCorrectly
                          ? question.fullEnglishSentence
                          : question.displaySentence,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                        color: AuroraTokens.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: AuroraTokens.s8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      WordSpeakerButton(
                        word: question.fullEnglishSentence,
                        semanticLabel: SparkStrings.hearSentenceSemantics(
                          question.fullEnglishSentence,
                        ),
                        speak: widget.speak,
                        color: AuroraTokens.plum,
                      ),
                      const SizedBox(width: AuroraTokens.s4),
                      Text(
                        SparkStrings.sentenceListenPrompt,
                        style: GoogleFonts.heebo(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AuroraTokens.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AuroraTokens.s12),
          Text(
            SparkStrings.sentencePracticeInstruction,
            textAlign: TextAlign.center,
            style: GoogleFonts.heebo(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AuroraTokens.inkSoft,
            ),
          ),
          const SizedBox(height: AuroraTokens.s8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AuroraTokens.s4,
            runSpacing: AuroraTokens.s4,
            children: [
              for (final option in question.optionsWithAnswer)
                _OptionCard(
                  key: ValueKey('option_$option'),
                  label: option,
                  state: _stateFor(option),
                  onTap: _answeredCorrectly || _advancing
                      ? null
                      : () => _handleOption(option),
                ),
            ],
          ),
          if (_selected != null && !_answeredCorrectly) ...[
            const SizedBox(height: AuroraTokens.s8),
            Text(
              SparkStrings.tryAgain,
              textAlign: TextAlign.center,
              style: GoogleFonts.heebo(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AuroraTokens.coral,
              ),
            ),
          ],
        ],
      ),
    );
  }

  _OptionState _stateFor(String option) {
    if (_answeredCorrectly && _current.isCorrect(option)) {
      return _OptionState.correct;
    }
    if (_selected == option) {
      return _current.isCorrect(option)
          ? _OptionState.correct
          : _OptionState.wrong;
    }
    return _OptionState.idle;
  }

  Widget _buildSummary() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AuroraTokens.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              size: 72,
              color: AuroraTokens.butter,
            ),
            const SizedBox(height: AuroraTokens.s8),
            Text(
              SparkStrings.sentencePracticeSummaryTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AuroraTokens.ink,
              ),
            ),
            const SizedBox(height: AuroraTokens.s4),
            Text(
              SparkStrings.sentencePracticeScore(
                _correctCount,
                _questions.length,
              ),
              style: GoogleFonts.heebo(
                fontSize: 16,
                color: AuroraTokens.inkSoft,
              ),
            ),
            const SizedBox(height: AuroraTokens.s16),
            KidButton.success(
              label: SparkStrings.levelPlayAgain,
              leadingIcon: Icons.replay_rounded,
              onPressed: _restart,
            ),
            const SizedBox(height: AuroraTokens.s4),
            KidButton.primary(
              label: SparkStrings.backToJourney,
              leadingIcon: Icons.home_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressLabel extends StatelessWidget {
  const _ProgressLabel({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Text(
      SparkStrings.sentencePracticeProgress(current, total),
      textAlign: TextAlign.center,
      style: GoogleFonts.heebo(
        fontSize: 13,
        color: AuroraTokens.inkMute,
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong }

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, Color fg) = switch (state) {
      _OptionState.correct => (
          AuroraTokens.mint.withValues(alpha: 0.18),
          AuroraTokens.mint,
          AuroraTokens.ink,
        ),
      _OptionState.wrong => (
          AuroraTokens.coral.withValues(alpha: 0.18),
          AuroraTokens.coral,
          AuroraTokens.ink,
        ),
      _OptionState.idle => (
          Colors.white,
          AuroraTokens.sky,
          AuroraTokens.ink,
        ),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AuroraTokens.rMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuroraTokens.rMd),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52, minWidth: 88),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuroraTokens.rMd),
            border: Border.all(color: border, width: 2),
          ),
          alignment: Alignment.center,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              label,
              style: GoogleFonts.baloo2(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
