// lib/screens/voice_challenge_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:english_learning_app/widgets/pronunciation_mic_button.dart';
import 'package:english_learning_app/widgets/ui/_barrel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../app_config.dart';
import '../l10n/spark_strings.dart';
import '../models/pronunciation_feedback.dart';
import '../models/word_data.dart';
import '../providers/coin_provider.dart';
import '../providers/user_session_provider.dart';
import '../services/sound_service.dart';
import '../services/speech_feedback_service.dart';
import '../services/word_mastery_service.dart';
import '../utils/aurora_tokens.dart';

/// "אתגר דיבור" — Voice Pronunciation Challenge.
///
/// The child sees a picture (and the Hebrew meaning) of an English word and has
/// to say the word out loud. A [PronunciationMicButton] records the attempt and
/// [SpeechFeedbackService] grades it 1–3 stars via Gemini (with a local
/// fallback). Every graded attempt is fed into the SRS through
/// [WordMasteryService.recordPronunciationScore]; a strong attempt (≥ 2 stars)
/// clears the word, awards coins and fires a big celebration.
class VoiceChallengeScreen extends StatefulWidget {
  const VoiceChallengeScreen({
    super.key,
    required this.levelId,
    required this.wordsForLevel,
    this.levelTitle,
    this.roundSize = 5,
    this.wordMasteryService,
    this.speechFeedbackService,
    this.random,
  });

  final String levelId;
  final List<WordData> wordsForLevel;
  final String? levelTitle;

  /// How many words to challenge per round (clamped to the words available).
  final int roundSize;

  /// Overridable for tests.
  final WordMasteryService? wordMasteryService;

  /// Overridable for tests. When null the screen reads a
  /// [SpeechFeedbackService] from the widget tree (as wired in `main.dart`).
  final SpeechFeedbackService? speechFeedbackService;

  /// Overridable for deterministic shuffling in tests.
  final math.Random? random;

  /// Coins granted per word cleared with a strong pronunciation.
  static const int coinReward = 15;

  @override
  State<VoiceChallengeScreen> createState() => _VoiceChallengeScreenState();
}

class _VoiceChallengeScreenState extends State<VoiceChallengeScreen> {
  late final math.Random _random;
  late final WordMasteryService _wordMasteryService;

  SpeechFeedbackService? _speechService;
  String _userId = 'local_guest';

  List<WordData> _round = <WordData>[];
  int _currentIndex = 0;
  int _cleared = 0;
  bool _isComplete = false;
  bool _grading = false;
  bool _isListening = false;
  bool _isEvaluating = false;
  String? _retryHint;

  bool get _busy => _grading || _isListening || _isEvaluating;

  WordData? get _currentWord =>
      _currentIndex < _round.length ? _round[_currentIndex] : null;

  @override
  void initState() {
    super.initState();
    _random = widget.random ?? math.Random();
    _wordMasteryService = widget.wordMasteryService ?? WordMasteryService();
    _round = _dealRound();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _speechService = widget.speechFeedbackService ?? _readSpeechService();
      try {
        _userId =
            context.read<UserSessionProvider>().currentUser?.id ?? 'local_guest';
      } catch (_) {
        _userId = 'local_guest';
      }
      if (mounted) setState(() {});
    });
  }

  SpeechFeedbackService? _readSpeechService() {
    try {
      return context.read<SpeechFeedbackService>();
    } catch (_) {
      return null;
    }
  }

  List<WordData> _dealRound() {
    final pool = widget.wordsForLevel
        .where((w) => w.word.trim().isNotEmpty)
        .toList(growable: false);
    final shuffled = List<WordData>.of(pool)..shuffle(_random);
    final take = math.min(widget.roundSize, shuffled.length);
    return shuffled.take(take).toList();
  }

  void _playAgain() {
    setState(() {
      _round = _dealRound();
      _currentIndex = 0;
      _cleared = 0;
      _isComplete = false;
      _grading = false;
      _retryHint = null;
    });
  }

  Future<void> _onFeedback(
    PronunciationFeedback feedback,
    String transcript,
  ) async {
    final word = _currentWord;
    if (word == null || _isComplete || _grading) return;
    _grading = true;

    // Feed every attempt into the SRS, regardless of the outcome.
    unawaited(
      _wordMasteryService.recordPronunciationScore(
        userId: _userId,
        levelId: widget.levelId,
        word: word.word,
        stars: feedback.stars,
      ),
    );

    if (!feedback.isStrongAttempt) {
      if (mounted) {
        setState(() {
          _retryHint = SparkStrings.micRetry;
          _grading = false;
        });
      } else {
        _grading = false;
      }
      return;
    }

    final bool wasLast = _currentIndex >= _round.length - 1;
    if (mounted) {
      setState(() {
        _cleared++;
        _retryHint = null;
        if (wasLast) {
          _isComplete = true;
        } else {
          _currentIndex++;
        }
      });
    }

    SoundService().playSuccessSound();

    if (mounted) {
      await context.read<CoinProvider>().addCoins(VoiceChallengeScreen.coinReward);
    }
    if (!mounted) {
      _grading = false;
      return;
    }

    await Celebration.fire(
      context,
      tier: CelebrationTier.big,
      word: word.word,
      compliment: 'הגייה מצוינת!',
      coinsEarned: VoiceChallengeScreen.coinReward,
      starsEarned: feedback.stars,
    );

    if (mounted) {
      setState(() => _grading = false);
    } else {
      _grading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuroraTokens.paper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.levelTitle == null
              ? 'אתגר דיבור'
              : 'אתגר דיבור · ${widget.levelTitle}',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.w800,
            color: AuroraTokens.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: _round.isEmpty
            ? _buildEmptyState()
            : _isComplete
                ? _buildVictoryPanel()
                : _buildChallenge(),
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
              Icons.mic_off_rounded,
              size: 64,
              color: AuroraTokens.inkMute,
            ),
            const SizedBox(height: AuroraTokens.s8),
            Text(
              'אין מספיק מילים לאתגר הזה',
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

  Widget _buildChallenge() {
    final word = _currentWord!;
    final service = _speechService;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AuroraTokens.s8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AuroraTokens.s4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'אמרו את המילה באנגלית 🎤',
                    style: GoogleFonts.heebo(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AuroraTokens.inkSoft,
                    ),
                  ),
                ),
                Text(
                  'מילה ${_currentIndex + 1} מתוך ${_round.length}',
                  style: GoogleFonts.heebo(
                    fontSize: 14,
                    color: AuroraTokens.inkMute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AuroraTokens.s4),
          _WordPrompt(word: word),
          const SizedBox(height: AuroraTokens.s8),
          if (service == null)
            _buildSpeechUnavailable()
          else
            PronunciationMicButton(
              key: ValueKey('mic_${word.word}'),
              targetWord: word.word,
              speechService: service,
              enabled: !_isComplete && !_grading,
              // Tall enough for the transcript + feedback bubbles + star row
              // + orb without overflowing the button's own fixed-height box.
              height: 340,
              onListeningChanged: (listening) {
                if (!mounted) return;
                setState(() => _isListening = listening);
              },
              onEvaluatingChanged: (evaluating) {
                if (!mounted) return;
                setState(() => _isEvaluating = evaluating);
              },
              onFeedback: _onFeedback,
            ),
          if (_retryHint != null && !_busy)
            Padding(
              padding: const EdgeInsets.only(top: AuroraTokens.s8),
              child: Text(
                _retryHint!,
                textAlign: TextAlign.center,
                style: GoogleFonts.heebo(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AuroraTokens.coral,
                ),
              ),
            ),
          const SizedBox(height: AuroraTokens.s4),
          TextButton.icon(
            onPressed: _busy || _isComplete ? null : _skipWord,
            icon: const Icon(Icons.skip_next_rounded),
            label: const Text('דלגו למילה הבאה'),
          ),
        ],
      ),
    );
  }

  void _skipWord() {
    setState(() {
      _retryHint = null;
      if (_currentIndex >= _round.length - 1) {
        _isComplete = true;
      } else {
        _currentIndex++;
      }
    });
  }

  Widget _buildSpeechUnavailable() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AuroraTokens.s8),
      padding: const EdgeInsets.all(AuroraTokens.s12),
      decoration: BoxDecoration(
        color: AuroraTokens.paper2,
        borderRadius: BorderRadius.circular(AuroraTokens.rLg),
        border: Border.all(color: AuroraTokens.sky, width: 2),
      ),
      child: Column(
        children: [
          const Icon(Icons.mic_off_rounded, size: 40, color: AuroraTokens.inkMute),
          const SizedBox(height: AuroraTokens.s4),
          Text(
            SparkStrings.micStartFailed,
            textAlign: TextAlign.center,
            style: GoogleFonts.heebo(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AuroraTokens.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVictoryPanel() {
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
              'סיימתם את האתגר!',
              style: GoogleFonts.baloo2(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AuroraTokens.ink,
              ),
            ),
            const SizedBox(height: AuroraTokens.s4),
            Text(
              'הגיתם נכון $_cleared מתוך ${_round.length} מילים',
              style: GoogleFonts.heebo(
                fontSize: 16,
                color: AuroraTokens.inkSoft,
              ),
            ),
            const SizedBox(height: AuroraTokens.s16),
            KidButton.success(
              label: SparkStrings.levelPlayAgain,
              leadingIcon: Icons.replay_rounded,
              onPressed: _playAgain,
              fullWidth: true,
            ),
            const SizedBox(height: AuroraTokens.s4),
            KidButton.primary(
              label: SparkStrings.backToJourney,
              leadingIcon: Icons.home_rounded,
              onPressed: () => Navigator.of(context).pop(),
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Picture + Hebrew meaning + the English word the child needs to say.
class _WordPrompt extends StatelessWidget {
  const _WordPrompt({required this.word});

  final WordData word;

  String? _resolveImageUrl() {
    if (word.imageUrl != null && word.imageUrl!.isNotEmpty) {
      return word.imageUrl;
    }
    if (word.publicId != null && word.publicId!.isNotEmpty) {
      final cloudName = AppConfig.cloudinaryCloudName;
      if (cloudName.isNotEmpty) {
        return 'https://res.cloudinary.com/$cloudName/image/upload/${word.publicId}';
      }
    }
    return null;
  }

  Widget _buildImage(String url) {
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image, size: 40)),
      );
    }
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image, size: 40)),
      );
    }
    if (!kIsWeb) {
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return const Center(
      child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolveImageUrl();
    final meaning = word.translation?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuroraTokens.s12),
      decoration: BoxDecoration(
        color: AuroraTokens.paper2,
        borderRadius: BorderRadius.circular(AuroraTokens.rXl),
        border: Border.all(color: AuroraTokens.sky, width: 2),
      ),
      child: Column(
        children: [
          if (url != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AuroraTokens.rMd),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: _buildImage(url),
              ),
            ),
          if (url != null) const SizedBox(height: AuroraTokens.s8),
          Text(
            word.word,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: AuroraTokens.ink,
            ),
          ),
          if (meaning != null && meaning.isNotEmpty) ...[
            const SizedBox(height: AuroraTokens.s4),
            Text(
              meaning,
              textAlign: TextAlign.center,
              style: GoogleFonts.heebo(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AuroraTokens.inkSoft,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
