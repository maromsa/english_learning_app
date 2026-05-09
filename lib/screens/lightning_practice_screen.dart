import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_mission.dart';
import '../models/word_data.dart';
import '../providers/coin_provider.dart';
import '../providers/daily_mission_provider.dart';
import '../providers/spark_overlay_controller.dart';
import '../providers/user_session_provider.dart';
import '../services/level_progress_service.dart';
import '../services/sound_service.dart';
import '../services/telemetry_service.dart';
import '../services/word_mastery_service.dart';

/// Lightning-round practice screen — Phase 3 edition.
///
/// Sorting guarantee (spaced-repetition):
///   Words are sorted in **ascending masteryLevel** order before the session
///   starts. Words with masteryLevel < 0.5 ("weak words") are placed at the
///   front of the pool so the child encounters them first. The pool is then
///   consumed in a weighted-random fashion that keeps the last [_recentHistorySize]
///   words out of rotation, preventing immediate repeats while still honouring
///   the weak-first ordering on each cycle.
///
/// Integration:
///   - Every correct answer calls [LevelProgressService.markWordCompleted],
///     which in turn calls [WordMasteryService.recordSuccessfulReview] (+0.25
///     mastery) and fires the Map Bridge event so the 3D map can react.
///   - [SparkOverlayController] celebrates on correct answers and returns to
///     idle at session end.
class LightningPracticeScreen extends StatefulWidget {
  const LightningPracticeScreen({
    super.key,
    required this.words,
    required this.levelId,
    this.levelTitle,
    this.wordMasteryService,
    this.levelProgressService,
  });

  /// Raw words for this level, passed by the caller (e.g. [MyHomePage]).
  final List<WordData> words;

  /// Level identifier used for mastery look-ups and [LevelProgressService].
  final String levelId;

  final String? levelTitle;

  // Overridable for testing.
  final WordMasteryService? wordMasteryService;
  final LevelProgressService? levelProgressService;

  @override
  State<LightningPracticeScreen> createState() =>
      _LightningPracticeScreenState();
}

class _LightningPracticeScreenState extends State<LightningPracticeScreen> {
  static const int _sessionSeconds = 60;
  static const int _recentHistorySize = 4;

  final Random _random = Random();
  final Queue<String> _recentWords = Queue<String>();

  late final WordMasteryService _wordMasteryService;
  late final LevelProgressService _levelProgressService;

  /// The sorted, mastery-enriched word pool used for the session.
  List<WordData> _wordPool = [];
  bool _isLoading = true;
  String? _loadError;

  late TelemetryService? _telemetry;

  Timer? _timer;
  int _remainingSeconds = _sessionSeconds;
  bool _sessionActive = false;
  bool _sessionEnded = false;

  WordData? _currentWord;
  List<String> _currentOptions = <String>[];
  String? _selectedAnswer;
  bool? _lastAnswerCorrect;
  bool _awaitingNext = false;
  String? _feedback;

  int _score = 0;
  int _correctAnswers = 0;
  int _incorrectAnswers = 0;
  int _questionCount = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;

  // ---------------------------------------------------------------------------
  // Fallback word pool used when the level does not have enough words.
  // ---------------------------------------------------------------------------
  static const List<Map<String, String>> _fallbackWordEntries = [
    {'word': 'Rainbow', 'hint': 'כל הצבעים שמופיעים אחרי הגשם'},
    {'word': 'Pirate', 'hint': 'שודד ים עם כובע וטלאי עין'},
    {'word': 'Robot', 'hint': 'מכונה חכמה שמדברת ומזיזה ידיים'},
    {'word': 'Castle', 'hint': 'בית גדול של מלך ומלכה'},
    {
      'word': 'Rocket',
      'hint': 'טיל שטס אל החלל',
      'asset': 'assets/images/words/rocket.png',
    },
    {'word': 'Puppy', 'hint': 'כלבלב קטן וחמוד'},
    {'word': 'Galaxy', 'hint': 'אוסף ענק של כוכבים וחלליות'},
    {'word': 'Treasure', 'hint': 'תיבת מטבעות ואבני חן נוצצות'},
    {
      'word': 'Magic Hat',
      'hint': 'כובע קסם שמסתיר הפתעות.',
      'asset': 'assets/images/words/magic_hat.png',
    },
    {
      'word': 'Magic Wand',
      'hint': 'מצית ניצוצות קסם ביד של קוסם.',
      'asset': 'assets/images/words/magic_wand.png',
    },
    {
      'word': 'Dragon Armor',
      'hint': 'שריון נוצץ מקשקשי דרקון.',
      'asset': 'assets/images/words/dragon_armor.png',
    },
    {
      'word': 'Energy Gauntlet',
      'hint': 'כפפה זוהרת שמטעינה כוח מיוחד.',
      'asset': 'assets/images/words/energy_gauntlet.png',
    },
    {
      'word': 'Flying Broom',
      'hint': 'כלי תחבורה קסום שממריא לשמיים.',
      'asset': 'assets/images/words/flying_broom.png',
    },
    {
      'word': 'Hero Shield',
      'hint': 'מגן נוצץ שמגן על גיבורים אמיצים.',
      'asset': 'assets/images/words/hero_shield.png',
    },
    {
      'word': 'Hot Air Balloon',
      'hint': 'בלון צבעוני שעולה גבוה מעל העננים.',
      'asset': 'assets/images/words/hot_air_balloon.png',
    },
    {
      'word': 'Submarine',
      'hint': 'סירה שצוללת ושטה עמוק בים.',
      'asset': 'assets/images/words/submarine.png',
    },
    {
      'word': 'Astronaut',
      'hint': 'חוקר אמיץ שמרחף בחלל.',
      'asset': 'assets/images/words/astronaut.png',
    },
    {
      'word': 'Penguin',
      'hint': 'ציפור שמעדיפה לרקוד על הקרח.',
      'asset': 'assets/images/words/penguin.png',
    },
    {
      'word': 'Banana',
      'hint': 'פרי צהוב ומתוק שמתקלף בקלות.',
      'asset': 'assets/images/words/banana.png',
    },
    {
      'word': 'Strawberry',
      'hint': 'פרי אדום עם המון נקודות קטנות.',
      'asset': 'assets/images/words/strawberry.png',
    },
  ];

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _wordMasteryService = widget.wordMasteryService ?? WordMasteryService();
    _levelProgressService = widget.levelProgressService ?? LevelProgressService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _telemetry = TelemetryService.maybeOf(context);
      _telemetry?.startScreenSession('lightning');
      _loadAndSortWords();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _telemetry?.endScreenSession(
      'lightning',
      extra: {
        'score': _score,
        'correct': _correctAnswers,
        'incorrect': _incorrectAnswers,
        'best_streak': _bestStreak,
        'questions': _questionCount,
      },
    );
    // Return Spark to idle when leaving the screen.
    if (mounted) {
      try {
        context.read<SparkOverlayController>().markIdle();
      } catch (_) {}
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Phase 3: Mastery-sorted word loading
  // ---------------------------------------------------------------------------

  /// Fetches mastery data for every word and sorts the pool so the weakest
  /// words (lowest masteryLevel) appear first.
  ///
  /// **Sorting guarantee:**
  /// After this method completes, `_wordPool[0]` has the lowest mastery score
  /// and `_wordPool[last]` has the highest. Words not yet seen by the learner
  /// default to masteryLevel = 0.0, so brand-new words are always prioritised.
  /// Words below the 0.5 threshold are considered "weak" and form the leading
  /// segment of the queue, ensuring the 60-second round covers the most
  /// under-practised vocabulary first.
  Future<void> _loadAndSortWords() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final session = context.read<UserSessionProvider>();
      final userId = session.currentUser?.id ?? 'local_guest';

      // Step 1: Sanitize and de-duplicate the raw word list from the level.
      final List<WordData> cleaned = _sanitizeWords(widget.words);

      // Step 2: Fetch each word's persisted mastery and merge it in.
      final List<WordData> withMastery = [];
      for (final word in cleaned) {
        final entry = await _wordMasteryService.getMastery(
          userId: userId,
          levelId: widget.levelId,
          word: word.word,
        );
        withMastery.add(_wordMasteryService.applyToWord(word, entry));
      }

      // Step 3: Sort ascending by masteryLevel (weak words first).
      //   - masteryLevel 0.0  → brand-new / never reviewed
      //   - masteryLevel < 0.5 → weak, needs repetition
      //   - masteryLevel ≥ 0.5 → progressing / strong
      withMastery.sort((a, b) => a.masteryLevel.compareTo(b.masteryLevel));

      // Step 4: Pad with fallback words when the level pool is too small.
      final pool = _padWithFallbacks(withMastery);

      if (!mounted) return;
      setState(() {
        _wordPool = pool;
        _isLoading = false;
      });
      _startSession();
    } catch (error, stackTrace) {
      debugPrint('LightningPracticeScreen: failed to load words: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'שגיאה בטעינת המילים. נסו שוב.';
      });
    }
  }

  List<WordData> _sanitizeWords(List<WordData> raw) {
    final seen = <String>{};
    final List<WordData> out = [];
    for (final w in raw) {
      final trimmed = w.word.trim();
      if (trimmed.isEmpty) continue;
      if (!seen.add(trimmed.toLowerCase())) continue;
      out.add(WordData(
        word: trimmed,
        searchHint: w.searchHint,
        imageUrl: w.imageUrl,
        publicId: w.publicId,
        isCompleted: w.isCompleted,
        stickerUnlocked: w.stickerUnlocked,
        masteryLevel: w.masteryLevel,
        lastReviewed: w.lastReviewed,
      ));
    }
    return out;
  }

  /// Appends fallback words (mastery = 0.0) when the pool has fewer than 4
  /// entries. Fallback words are appended *after* the real words so they don't
  /// displace genuinely weak level words at the front of the queue.
  List<WordData> _padWithFallbacks(List<WordData> pool) {
    if (pool.length >= 4) return pool;
    final existing = pool.map((w) => w.word.toLowerCase()).toSet();
    final padded = List<WordData>.from(pool);
    for (final entry in _fallbackWordEntries) {
      final word = entry['word']!;
      if (existing.contains(word.toLowerCase())) continue;
      padded.add(WordData(
        word: word,
        searchHint: entry['hint'],
        imageUrl: entry['asset'],
        masteryLevel: 0.0, // Treat fallback words as unseen.
      ));
      if (padded.length >= 8) break;
    }
    return padded;
  }

  // ---------------------------------------------------------------------------
  // Session management
  // ---------------------------------------------------------------------------

  void _startSession() {
    if (_wordPool.length < 2) {
      setState(() {
        _sessionActive = false;
        _sessionEnded = true;
        _feedback = 'אין מספיק מילים כדי להתחיל ריצת ברק. הוסיפו עוד מילים בשלב!';
      });
      return;
    }

    _timer?.cancel();
    setState(() {
      _sessionActive = true;
      _sessionEnded = false;
      _awaitingNext = false;
      _selectedAnswer = null;
      _lastAnswerCorrect = null;
      _feedback = null;
      _remainingSeconds = _sessionSeconds;
      _score = 0;
      _correctAnswers = 0;
      _incorrectAnswers = 0;
      _questionCount = 0;
      _currentStreak = 0;
      _bestStreak = 0;
      _recentWords.clear();
    });

    // Notify Spark that a new session is starting.
    _notifySpark(SparkOverlayAnimationState.idle);

    _prepareNextQuestion();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _endSession(triggeredByTimer: true);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Question preparation
  // ---------------------------------------------------------------------------

  /// Picks the next word respecting recent-history deduplication.
  ///
  /// Weak-first ordering is baked in via the sorted [_wordPool]; we simply
  /// avoid the [_recentHistorySize] most-recent words to prevent immediate
  /// repeats. When all candidates have been shown recently (small pools),
  /// the full pool is used.
  void _prepareNextQuestion() {
    if (_wordPool.isEmpty) return;

    final List<WordData> candidates = _wordPool
        .where((w) => !_recentWords.contains(w.word))
        .toList(growable: false);
    final List<WordData> source = candidates.isNotEmpty ? candidates : _wordPool;

    // Among candidates, bias toward lower-mastery words: pick from the first
    // half of the sorted list 70 % of the time to reinforce weak words.
    final WordData nextWord = _pickWeakBiased(source);

    _recentWords.addLast(nextWord.word);
    if (_recentWords.length > _recentHistorySize) {
      _recentWords.removeFirst();
    }

    setState(() {
      _currentWord = nextWord;
      _currentOptions = _buildOptions(nextWord.word);
      _selectedAnswer = null;
      _awaitingNext = false;
      _lastAnswerCorrect = null;
      _feedback = null;
    });
  }

  /// Picks a word with a 70 / 30 bias toward the weak (lower mastery) half.
  WordData _pickWeakBiased(List<WordData> source) {
    if (source.length <= 2) return source[_random.nextInt(source.length)];
    final int halfPoint = (source.length / 2).ceil();
    // source is already sorted ascending by mastery, so the first half is weaker.
    if (_random.nextDouble() < 0.70) {
      return source[_random.nextInt(halfPoint)];
    }
    return source[_random.nextInt(source.length)];
  }

  List<String> _buildOptions(String correctWord) {
    final Set<String> options = <String>{correctWord};
    final List<String> pool = _wordPool
        .map((w) => w.word)
        .where((w) => !w.equalsIgnoreCase(correctWord))
        .toList(growable: true);

    while (options.length < 4 && pool.isNotEmpty) {
      options.add(pool.removeAt(_random.nextInt(pool.length)));
    }

    // Pad with fallback entries if the level pool is very small.
    while (options.length < 4) {
      final fallback =
          _fallbackWordEntries[_random.nextInt(_fallbackWordEntries.length)]['word']!;
      if (!options.contains(fallback)) options.add(fallback);
    }

    final List<String> shuffled = options.toList(growable: false);
    shuffled.shuffle(_random);
    return shuffled;
  }

  // ---------------------------------------------------------------------------
  // Answer handling
  // ---------------------------------------------------------------------------

  Future<void> _handleAnswer(String option) async {
    if (!_sessionActive || _sessionEnded || _awaitingNext || _currentWord == null) {
      return;
    }

    setState(() {
      _awaitingNext = true;
      _selectedAnswer = option;
      _questionCount++;
    });

    final bool isCorrect = option == _currentWord!.word;
    int reward = 0;
    String feedback;

    if (isCorrect) {
      _currentStreak += 1;
      _bestStreak = max(_bestStreak, _currentStreak);
      reward = 5 + ((_currentStreak - 1) * 2);
      _score += reward;
      _correctAnswers += 1;
      feedback = 'מעולה! הרווחתם $reward מטבעות ⚡️';

      if (mounted) {
        await context.read<CoinProvider>().addCoins(reward);
        // ── Phase 3 Integration ──────────────────────────────────────────────
        // markWordCompleted handles three responsibilities atomically:
        //   1. Persists the word as completed in SharedPreferences.
        //   2. Calls WordMasteryService.recordSuccessfulReview (+0.25 mastery).
        //   3. Fires MapBridgeService.emitWordMastered → 3D map reacts.
        await _markWordCompleted(_currentWord!.word);
        // Play success sound — fire-and-forget, does not block UI thread.
        SoundService().playSuccessSound();
        // Spark celebrates on correct answer.
        _notifySpark(SparkOverlayAnimationState.celebrating);
      }
    } else {
      _currentStreak = 0;
      _incorrectAnswers += 1;
      feedback = 'כמעט! התשובה הנכונה: "${_currentWord!.word}".';
    }

    final int elapsed = _sessionSeconds - _remainingSeconds;
    _telemetry?.logLightningAnswer(
      word: _currentWord!.word,
      correct: isCorrect,
      streak: _currentStreak,
      elapsedSeconds: elapsed < 0 ? 0 : elapsed,
      remainingSeconds: _remainingSeconds,
      reward: reward,
    );

    if (!mounted) return;

    setState(() {
      _feedback = feedback;
      _lastAnswerCorrect = isCorrect;
    });

    if (_remainingSeconds <= 0) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      _endSession();
      return;
    }

    Future<void>.delayed(const Duration(milliseconds: 750), () {
      if (!mounted || _sessionEnded) return;
      // Return Spark to idle after celebrating.
      if (isCorrect) _notifySpark(SparkOverlayAnimationState.idle);
      setState(() {
        _awaitingNext = false;
        _selectedAnswer = null;
        _lastAnswerCorrect = null;
        _feedback = null;
      });
      _prepareNextQuestion();
    });
  }

  /// Calls [LevelProgressService.markWordCompleted] with the current user
  /// context, feeding mastery + Map Bridge in one call. Non-fatal on error.
  Future<void> _markWordCompleted(String word) async {
    try {
      final session = context.read<UserSessionProvider>();
      final userId = session.currentUser?.id ?? 'local_guest';
      final isLocalUser =
          session.currentUser == null || !session.currentUser!.isGoogle;
      await _levelProgressService.markWordCompleted(
        userId,
        widget.levelId,
        word,
        isLocalUser: isLocalUser,
      );
    } catch (error, stackTrace) {
      debugPrint('LightningPracticeScreen: markWordCompleted error: $error');
      debugPrint('$stackTrace');
    }
  }

  void _endSession({bool triggeredByTimer = false}) {
    if (_sessionEnded) return;

    _timer?.cancel();
    setState(() {
      _sessionActive = false;
      _sessionEnded = true;
    });

    _notifySpark(SparkOverlayAnimationState.idle);

    try {
      context.read<DailyMissionProvider>().incrementByType(
        DailyMissionType.lightningRound,
      );
    } catch (_) {}

    _telemetry?.logLightningSession(
      score: _score,
      correct: _correctAnswers,
      incorrect: _incorrectAnswers,
      bestStreak: _bestStreak,
      totalQuestions: _questionCount,
    );

    if (triggeredByTimer && mounted) {
      setState(() {
        _feedback = _feedback ?? 'הזמן נגמר! בואו נסקור את ההצלחה שלכם.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Spark helpers
  // ---------------------------------------------------------------------------

  void _notifySpark(SparkOverlayAnimationState state) {
    if (!mounted) return;
    try {
      final controller = context.read<SparkOverlayController>();
      switch (state) {
        case SparkOverlayAnimationState.celebrating:
          controller.markCelebrating();
        case SparkOverlayAnimationState.thinking:
          controller.markThinking();
        case SparkOverlayAnimationState.idle:
          controller.markIdle();
      }
    } catch (_) {
      // SparkOverlayController not in tree during tests — ignore.
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.levelTitle == null
                ? 'ריצת ברק'
                : 'ריצת ברק - ${widget.levelTitle}',
          ),
          backgroundColor: Colors.deepOrange.shade400,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ריצת ברק'),
          backgroundColor: Colors.deepOrange.shade400,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    final bool insufficientWords = _wordPool.length < 2;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.levelTitle == null
              ? 'ריצת ברק'
              : 'ריצת ברק - ${widget.levelTitle}',
        ),
        backgroundColor: Colors.deepOrange.shade400,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: insufficientWords
              ? _buildEmptyState()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusRow(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _sessionEnded
                            ? _buildSummaryCard()
                            : _buildQuestionCard(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildBottomControls(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStatusRow() {
    final double accuracy = _questionCount == 0
        ? 0
        : (_correctAnswers / _questionCount) * 100;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: const Color(0xFFFFF3E0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StatusChip(
              icon: Icons.timer_outlined,
              label: 'זמן',
              value: '${_remainingSeconds}s',
              color: Colors.deepOrange.shade500,
            ),
            _StatusChip(
              icon: Icons.flash_on,
              label: 'ניקוד',
              value: '$_score',
              color: Colors.amber.shade800,
            ),
            _StatusChip(
              icon: Icons.whatshot,
              label: 'רצף',
              value: '$_currentStreak',
              color: Colors.redAccent.shade200,
            ),
            _StatusChip(
              icon: Icons.insights,
              label: 'דיוק',
              value: '${accuracy.round()}%',
              color: Colors.blue.shade500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard() {
    final word = _currentWord;
    if (word == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final Widget? visual = _buildVisual(word);

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mastery indicator badge for the current word.
            _MasteryBadge(masteryLevel: word.masteryLevel),
            const SizedBox(height: 8),
            Text(
              'רמז קסם:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _clueForWord(word),
              style: const TextStyle(fontSize: 18, height: 1.4),
            ),
            if (visual != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(height: 160, child: visual),
              ),
            ],
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: _currentOptions
                      .map(
                        (option) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LightningOptionButton(
                            option: option,
                            isSelected: _selectedAnswer == option,
                            isCorrectAnswer: word.word == option,
                            awaitingNext: _awaitingNext,
                            onTap: () => _handleAnswer(option),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
            if (_feedback != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: 1,
                  child: Text(
                    _feedback!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _lastAnswerCorrect == true
                          ? Colors.green.shade700
                          : Colors.redAccent.shade200,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      color: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'סיכום ריצת הברק',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange.shade600,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                _SummaryStat(
                  label: 'ניקוד',
                  value: '$_score',
                  icon: Icons.flash_on,
                  color: Colors.deepOrange,
                ),
                _SummaryStat(
                  label: 'תשובות נכונות',
                  value: '$_correctAnswers',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
                _SummaryStat(
                  label: 'טעויות',
                  value: '$_incorrectAnswers',
                  icon: Icons.close_rounded,
                  color: Colors.redAccent,
                ),
                _SummaryStat(
                  label: 'רצף שיא',
                  value: '$_bestStreak',
                  icon: Icons.whatshot,
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _loadAndSortWords,
              icon: const Icon(Icons.refresh),
              label: const Text('שחקו שוב'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('חזרה למסע'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    if (_sessionEnded) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton.icon(
          onPressed: _sessionActive ? () => _endSession() : null,
          icon: const Icon(Icons.flag_circle_outlined),
          label: const Text('סיימו מוקדם'),
        ),
        TextButton.icon(
          onPressed: _awaitingNext || _sessionEnded
              ? null
              : () => _prepareNextQuestion(),
          icon: const Icon(Icons.shuffle),
          label: const Text('דלגו לרמז חדש'),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.psychology, size: 64, color: Colors.deepOrange.shade300),
              const SizedBox(height: 16),
              const Text(
                'זקוקים לעוד מילים כדי להתחיל את ריצת הברק!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'הוסיפו מילים חדשות בשלב או צלמו חפצים חדשים במצלמה.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildVisual(WordData word) {
    final String? path = word.imageUrl;
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.contain);
    }
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        memCacheWidth: 600,
        memCacheHeight: 600,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade300,
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
        fadeInDuration: const Duration(milliseconds: 200),
      );
    }
    if (!kIsWeb) {
      final file = File(path);
      if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
    }
    return null;
  }

  String _clueForWord(WordData word) {
    final hint = word.searchHint?.trim();
    if (hint != null && hint.isNotEmpty) {
      return hint.endsWith('.') ? hint : '$hint.';
    }
    final cleaned = word.word.trim();
    if (cleaned.length <= 2) return 'איזו מילה אתם מזהים? היא קצרה ומהירה!';
    final first = cleaned.characters.first.toUpperCase();
    final last = cleaned.characters.last.toUpperCase();
    return 'המילה מתחילה באות $first ונגמרת באות $last.';
  }
}

// =============================================================================
// Private widgets
// =============================================================================

/// Small badge that communicates the current word's mastery to the learner.
class _MasteryBadge extends StatelessWidget {
  const _MasteryBadge({required this.masteryLevel});
  final double masteryLevel;

  @override
  Widget build(BuildContext context) {
    final bool isWeak = masteryLevel < 0.5;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isWeak
              ? Colors.orange.withValues(alpha: 0.15)
              : Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isWeak ? Colors.orange.shade300 : Colors.green.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isWeak ? Icons.fitness_center : Icons.star,
              size: 14,
              color: isWeak ? Colors.orange.shade700 : Colors.green.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              isWeak ? 'תרגלו עוד' : 'מכירים טוב',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isWeak ? Colors.orange.shade700 : Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LightningOptionButton extends StatelessWidget {
  const _LightningOptionButton({
    required this.option,
    required this.isSelected,
    required this.isCorrectAnswer,
    required this.awaitingNext,
    required this.onTap,
  });

  final String option;
  final bool isSelected;
  final bool isCorrectAnswer;
  final bool awaitingNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color background = Colors.white;
    Color borderColor = Colors.deepOrange.shade100;
    Color textColor = Colors.deepOrange.shade800;

    if (awaitingNext) {
      if (isCorrectAnswer) {
        background = Colors.green.shade100;
        borderColor = Colors.green.shade400;
        textColor = Colors.green.shade800;
      } else if (isSelected) {
        background = Colors.red.shade100;
        borderColor = Colors.redAccent;
        textColor = Colors.red.shade700;
      } else {
        background = Colors.white;
      }
    } else if (isSelected) {
      background = Colors.deepOrange.shade100;
      borderColor = Colors.deepOrange.shade400;
    }

    return ElevatedButton(
      onPressed: awaitingNext ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        disabledBackgroundColor: background,
        foregroundColor: textColor,
        elevation: awaitingNext ? 0 : 3,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 2),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          option,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension StringCaseCompare on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
