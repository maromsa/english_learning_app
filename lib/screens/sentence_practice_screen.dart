// lib/screens/sentence_practice_screen.dart
import 'dart:async';

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/sentence_question.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/daily_streak_provider.dart';
import 'package:english_learning_app/providers/sentence_practice_provider.dart';
import 'package:english_learning_app/providers/word_bank_provider.dart';
import 'package:english_learning_app/services/audio_settings.dart';
import 'package:english_learning_app/services/gemini_sentence_service.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:english_learning_app/services/speech_service.dart';
import 'package:english_learning_app/services/tts_service.dart';
import 'package:english_learning_app/utils/aurora_tokens.dart';
import 'package:english_learning_app/widgets/streak_milestone_dialog.dart';
import 'package:english_learning_app/widgets/ui/_barrel.dart';
import 'package:english_learning_app/widgets/word_speaker_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Sentence-level ("fill in the blank") practice — Phase 3.
///
/// The child reads a Hebrew translation, taps 🔊 to hear the **full** English
/// sentence (via [TtsService] / on-device TTS, through [WordSpeakerButton]),
/// taps 🎤 to **say** the sentence (via [SpeechService] / on-device STT),
/// and picks the missing word from a set of option cards. A new sentence is
/// also auto-read when it first appears. A correct pick plays the victory
/// sound, awards coins through [CoinProvider], fires a micro [Celebration],
/// and advances to the next sentence. A close spoken match awards a small
/// bonus and a green check. A wrong pick / missed pronunciation nudges the
/// child to try again.
///
/// The screen is self-contained: it takes its [questions] directly (mirroring
/// `MemoryMatchScreen.wordsForLevel`) so it stays trivial to widget-test.
/// When the static queue runs out, [SentencePracticeProvider] asks
/// [GeminiSentenceService] (authenticated proxy — no client API key) for more.
/// If the proxy is unreachable the child still finishes on the catalog.
class SentencePracticeScreen extends StatefulWidget {
  const SentencePracticeScreen({
    super.key,
    required this.questions,
    this.coinReward = defaultCoinReward,
    this.speak,
    this.ttsService,
    this.speechService,
    this.geminiSentenceService,
    this.practiceProvider,
  });

  /// The sentence exercises for this session. Unplayable entries (missing
  /// sentence / word / too few options) are filtered out on init.
  final List<SentenceQuestion> questions;

  /// Coins granted per correctly-completed sentence.
  final int coinReward;

  /// Test seam forwarded to [WordSpeakerButton]. Production leaves this null
  /// so the button / auto-play use [ttsService] or `context.read<TtsService>()`.
  final Future<bool> Function(String sentence)? speak;

  /// Optional [TtsService] override. Production leaves this null and reads
  /// the instance registered on [MultiProvider] in `main.dart`.
  final TtsService? ttsService;

  /// Optional [SpeechService] override. Production leaves this null and reads
  /// the instance registered on [MultiProvider] in `main.dart`.
  final SpeechService? speechService;

  /// Optional [GeminiSentenceService] override. Production leaves this null
  /// and reads the instance registered on [MultiProvider] in `main.dart`.
  final GeminiSentenceService? geminiSentenceService;

  /// Optional session queue. Production and most tests leave this null so
  /// the screen owns a [SentencePracticeProvider] seeded from [questions].
  final SentencePracticeProvider? practiceProvider;

  /// Key on the 🔊 control, so tests can tap pronunciation without hunting
  /// through the tree.
  static const Key speakerKey = ValueKey<String>('sentence_tts_button');

  /// Key on the 🎤 control, so tests can start listening without hunting.
  static const Key micKey = ValueKey<String>('sentence_mic_button');

  /// Visible while the recognizer is capturing audio.
  static const Key listeningBadgeKey =
      ValueKey<String>('sentence_mic_listening');

  /// Green check shown after a successful spoken match.
  static const Key pronunciationSuccessKey =
      ValueKey<String>('sentence_pronunciation_success');

  /// Shown while Spark is fetching extra sentences from the Gemini proxy.
  static const Key generatingKey =
      ValueKey<String>('sentence_generating_indicator');

  static const int defaultCoinReward = 15;

  /// Extra coins for saying the English sentence clearly. Awarded at most
  /// once per sentence so retries stay encouraging, not farmable.
  static const int pronunciationBonusCoins = 5;

  @override
  State<SentencePracticeScreen> createState() => _SentencePracticeScreenState();
}

class _SentencePracticeScreenState extends State<SentencePracticeScreen> {
  late final SentencePracticeProvider _practice;
  SentencePracticeProvider? _ownedPractice;
  late bool _waitingForFirstQuestion;

  int _index = 0;
  String? _selected;
  bool _answeredCorrectly = false;
  bool _advancing = false;
  int _correctCount = 0;
  bool _finished = false;
  TtsService? _tts;
  SpeechService? _speech;
  bool _listening = false;
  bool _pronunciationSuccess = false;
  bool _pronunciationFailed = false;
  bool _pronunciationBonusAwarded = false;
  bool _handlingSpeech = false;
  bool _permissionDenied = false;
  String _transcript = '';

  List<SentenceQuestion> get _questions => _practice.questions;

  SentenceQuestion get _current => _questions[_index];

  @override
  void initState() {
    super.initState();
    _practice = widget.practiceProvider ??
        SentencePracticeProvider(
          initial: widget.questions,
          gemini: widget.geminiSentenceService,
        );
    if (widget.practiceProvider == null) {
      _ownedPractice = _practice;
    }
    _waitingForFirstQuestion = _questions.isEmpty;
    _practice.addListener(_onPracticeUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tts = widget.ttsService ?? _tryReadTts();
      _speech = widget.speechService ?? _tryReadSpeech();
      _practice.attachGemini(
        widget.geminiSentenceService ?? _tryReadGemini(),
      );
      if (_questions.isEmpty) {
        unawaited(_practice.refillIfNeeded());
      }
      unawaited(_speakCurrent());
    });
  }

  void _onPracticeUpdate() {
    if (!mounted) return;
    final becameReady = _waitingForFirstQuestion && _questions.isNotEmpty;
    if (becameReady) {
      _waitingForFirstQuestion = false;
    }
    setState(() {});
    if (becameReady) {
      unawaited(_speakCurrent());
    }
  }

  @override
  void dispose() {
    _practice.removeListener(_onPracticeUpdate);
    _ownedPractice?.dispose();
    unawaited(_tts?.stop());
    unawaited(_speech?.stopListening());
    super.dispose();
  }

  TtsService? _tryReadTts() {
    try {
      return context.read<TtsService>();
    } catch (_) {
      return null;
    }
  }

  SpeechService? _tryReadSpeech() {
    try {
      return context.read<SpeechService>();
    } catch (_) {
      return null;
    }
  }

  GeminiSentenceService? _tryReadGemini() {
    try {
      return context.read<GeminiSentenceService>();
    } catch (_) {
      return null;
    }
  }

  void _resetPronunciationState() {
    _listening = false;
    _pronunciationSuccess = false;
    _pronunciationFailed = false;
    _pronunciationBonusAwarded = false;
    _handlingSpeech = false;
    _permissionDenied = false;
    _transcript = '';
    unawaited(_speech?.stopListening());
  }

  Future<void> _onMicPressed() async {
    if (_advancing || _finished) return;
    if (_listening) {
      await _stopListening();
      return;
    }
    await _startListening();
  }

  Future<void> _startListening() async {
    if (_listening || _advancing || _finished) return;
    final speech = _speech ?? widget.speechService ?? _tryReadSpeech();
    _speech = speech;
    if (speech == null) {
      if (!mounted) return;
      setState(() {
        _permissionDenied = true;
        _pronunciationFailed = false;
      });
      return;
    }

    await _tts?.stop();
    if (!mounted) return;
    setState(() {
      _listening = true;
      _pronunciationFailed = false;
      _permissionDenied = false;
      _transcript = '';
    });

    final ready = await speech.initialize();
    if (!mounted) return;
    if (!ready) {
      setState(() {
        _listening = false;
        _permissionDenied = true;
      });
      return;
    }

    try {
      await speech.startListening(
        _onSpeechResult,
        onDone: _onListenDone,
      );
    } catch (e) {
      debugPrint('SentencePracticeScreen listen failed: $e');
      if (!mounted) return;
      setState(() => _listening = false);
    }
  }

  Future<void> _stopListening() async {
    if (!_listening) return;
    await _speech?.stopListening();
    if (!mounted) return;
    await _handleRecognized(_transcript);
  }

  void _onSpeechResult(String recognized) {
    unawaited(_handleRecognized(recognized));
  }

  void _onListenDone() {
    if (_handlingSpeech || _pronunciationSuccess || !_listening) return;
    unawaited(_handleRecognized(_transcript));
  }

  Future<void> _handleRecognized(String recognized) async {
    if (_handlingSpeech || _finished) return;
    _handlingSpeech = true;
    try {
      await _speech?.stopListening();
      if (!mounted) return;

      final heard = recognized.trim();
      if (heard.isEmpty) {
        setState(() {
          _listening = false;
          _pronunciationFailed = true;
        });
        return;
      }

      final matched = SpeechService.matches(
        _current.fullEnglishSentence,
        heard,
      );
      setState(() {
        _listening = false;
        _transcript = heard;
        _pronunciationSuccess = matched;
        _pronunciationFailed = !matched;
      });
      if (!matched) return;
      await _awardPronunciationBonus();
    } finally {
      _handlingSpeech = false;
    }
  }

  Future<void> _awardPronunciationBonus() async {
    if (_pronunciationBonusAwarded) return;
    _pronunciationBonusAwarded = true;
    SoundService().playSuccessSound();
    await context.read<CoinProvider>().addCoins(
          SentencePracticeScreen.pronunciationBonusCoins,
        );
    SoundService().playCoinSound();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(SparkStrings.sentencePronunciationSuccess),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _speakCurrent() async {
    if (!mounted || _questions.isEmpty || _finished) return;
    await _speakSentence(_current.fullEnglishSentence);
  }

  Future<void> _speakSentence(String sentence) async {
    if (AudioSettings().muted) return;
    try {
      if (widget.speak != null) {
        await widget.speak!(sentence);
        return;
      }
      await (_tts ?? widget.ttsService ?? _tryReadTts())?.speak(sentence);
    } catch (_) {
      // Best-effort: TTS must never surface to a child.
    }
  }

  Future<bool> _onSpeakerTap(String sentence) async {
    await _speakSentence(sentence);
    return true;
  }

  WordBankProvider? _tryReadWordBank() {
    try {
      return context.read<WordBankProvider>();
    } catch (_) {
      return null;
    }
  }

  /// Records the missing (target) word in the child's Word Bank. Best-effort:
  /// a missing provider or a duplicate is a silent no-op.
  Future<void> _addCurrentWordToBank() async {
    final bank = _tryReadWordBank();
    if (bank == null) return;
    try {
      await bank.addWord(
        _current.missingWord,
        translation: _current.hebrewTranslation,
      );
    } catch (e) {
      debugPrint('WordBankProvider.addWord failed: $e');
    }
  }

  Future<void> _handleOption(String option) async {
    if (_answeredCorrectly || _advancing) return;

    final bool correct = _current.isCorrect(option);
    setState(() => _selected = option);

    if (!correct) {
      SoundService().playErrorSound();
      return;
    }

    setState(() {
      _answeredCorrectly = true;
      _correctCount++;
    });
    SoundService().playSuccessSound();

    await context.read<CoinProvider>().addCoins(widget.coinReward);
    SoundService().playCoinSound();
    if (!mounted) return;
    await _addCurrentWordToBank();
    if (!mounted) return;
    final streak = context.read<DailyStreakProvider>();
    await streak.recordPractice();
    if (!mounted) return;
    final milestone = streak.consumePendingMilestone();
    if (milestone != null) {
      await StreakMilestoneDialog.show(
        context,
        day: milestone.day,
        coins: milestone.coins,
      );
      if (!mounted) return;
    }

    await Celebration.fire(
      context,
      tier: CelebrationTier.micro,
      word: _current.missingWord,
    );
    if (!mounted) return;

    _advancing = true;
    if (_index + 1 >= _questions.length) {
      unawaited(_practice.refillIfNeeded());
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    if (_index + 1 >= _questions.length) {
      await _practice.refillIfNeeded();
      if (!mounted) return;
    }

    setState(() {
      _advancing = false;
      if (_index + 1 >= _questions.length) {
        _finished = true;
        _resetPronunciationState();
      } else {
        _index++;
        _selected = null;
        _answeredCorrectly = false;
        _resetPronunciationState();
      }
    });
    if (_finished) {
      unawaited(_tts?.stop());
    } else {
      unawaited(_speakCurrent());
    }
  }

  void _restart() {
    setState(() {
      _index = 0;
      _selected = null;
      _answeredCorrectly = false;
      _advancing = false;
      _correctCount = 0;
      _finished = false;
      _resetPronunciationState();
    });
    unawaited(_speakCurrent());
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
        child: Stack(
          children: [
            _questions.isEmpty
                ? _buildEmptyState()
                : _finished
                    ? _buildSummary()
                    : _buildQuestion(),
            if (_practice.isLoadingAi) _buildGeneratingOverlay(),
          ],
        ),
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

  Widget _buildGeneratingOverlay() {
    return ColoredBox(
      key: SentencePracticeScreen.generatingKey,
      color: AuroraTokens.paper.withValues(alpha: 0.92),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AuroraTokens.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AuroraTokens.plum),
              const SizedBox(height: AuroraTokens.s8),
              Text(
                SparkStrings.sentenceGenerating,
                textAlign: TextAlign.center,
                style: GoogleFonts.heebo(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AuroraTokens.inkSoft,
                ),
              ),
            ],
          ),
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
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AuroraTokens.s8,
                    runSpacing: AuroraTokens.s4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          WordSpeakerButton(
                            key: SentencePracticeScreen.speakerKey,
                            word: question.fullEnglishSentence,
                            semanticLabel: SparkStrings.hearSentenceSemantics(
                              question.fullEnglishSentence,
                            ),
                            speak: _onSpeakerTap,
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SentenceMicButton(
                            key: SentencePracticeScreen.micKey,
                            listening: _listening,
                            success: _pronunciationSuccess,
                            semanticLabel: SparkStrings.speakSentenceSemantics(
                              question.fullEnglishSentence,
                            ),
                            onPressed: _advancing
                                ? null
                                : () => unawaited(_onMicPressed()),
                            onLongPressStart: _advancing
                                ? null
                                : () => unawaited(_startListening()),
                            onLongPressEnd: _advancing
                                ? null
                                : () => unawaited(_stopListening()),
                          ),
                          const SizedBox(width: AuroraTokens.s4),
                          Text(
                            SparkStrings.sentenceSpeakPrompt,
                            style: GoogleFonts.heebo(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AuroraTokens.inkSoft,
                            ),
                          ),
                          if (_listening) ...[
                            const SizedBox(width: AuroraTokens.s4),
                            Text(
                              key: SentencePracticeScreen.listeningBadgeKey,
                              SparkStrings.micListening,
                              style: GoogleFonts.heebo(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFE53935),
                              ),
                            ),
                          ],
                        ],
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
          if (_permissionDenied) ...[
            const SizedBox(height: AuroraTokens.s8),
            Text(
              SparkStrings.micPermissionAsk,
              textAlign: TextAlign.center,
              style: GoogleFonts.heebo(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AuroraTokens.coral,
              ),
            ),
          ] else if (_pronunciationFailed && !_pronunciationSuccess) ...[
            const SizedBox(height: AuroraTokens.s8),
            Text(
              SparkStrings.sentencePronunciationTryAgain,
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

class _SentenceMicButton extends StatefulWidget {
  const _SentenceMicButton({
    super.key,
    required this.listening,
    required this.success,
    required this.semanticLabel,
    this.onPressed,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final bool listening;
  final bool success;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;

  @override
  State<_SentenceMicButton> createState() => _SentenceMicButtonState();
}

class _SentenceMicButtonState extends State<_SentenceMicButton>
    with SingleTickerProviderStateMixin {
  static const Color _listeningRed = Color(0xFFE53935);

  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    if (widget.listening) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_SentenceMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening && !oldWidget.listening) {
      _pulse.repeat(reverse: true);
    } else if (!widget.listening && oldWidget.listening) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.success
        ? AuroraTokens.mint
        : widget.listening
            ? _listeningRed
            : AuroraTokens.plum;
    final IconData icon = widget.success
        ? Icons.check_circle_rounded
        : widget.listening
            ? Icons.mic_rounded
            : Icons.mic_none_rounded;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: Material(
        color: color.withValues(alpha: 0.10),
        shape: const CircleBorder(),
        child: GestureDetector(
          onTap: widget.onPressed,
          onLongPressStart: widget.onLongPressStart == null
              ? null
              : (_) => widget.onLongPressStart!(),
          onLongPressEnd: widget.onLongPressEnd == null
              ? null
              : (_) => widget.onLongPressEnd!(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: ScaleTransition(
                scale: _scale,
                child: Icon(
                  icon,
                  key: widget.success
                      ? SentencePracticeScreen.pronunciationSuccessKey
                      : null,
                  size: 26,
                  color: color,
                ),
              ),
            ),
          ),
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
