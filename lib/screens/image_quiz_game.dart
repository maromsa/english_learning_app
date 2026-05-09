import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_config.dart';
import '../models/daily_mission.dart';
import '../models/word_data.dart';
import '../providers/coin_provider.dart';
import '../providers/daily_mission_provider.dart';
import '../providers/spark_overlay_controller.dart';
import '../providers/user_session_provider.dart';
import '../services/level_progress_service.dart';
import '../services/level_repository.dart';
import '../services/telemetry_service.dart';
import '../services/word_mastery_service.dart';
import '../services/word_repository.dart';

/// Legacy Image Quiz mini-game — Phase 3 refactor.
///
/// Previously relied on a hardcoded list of ~10 [QuizItem] entries. This
/// version dynamically fetches words from `levels.json` via [LevelRepository]
/// (and optionally enriches them from Cloudinary via [WordRepository]), then
/// applies [WordMasteryService] mastery scores so weak words are practised first.
///
/// Sorting guarantee (spaced repetition):
///   After loading, words are sorted in **ascending masteryLevel** order.
///   Words with masteryLevel < 0.5 ("weak words") lead the queue, ensuring the
///   quiz prioritises under-practised vocabulary. Each correct answer calls
///   [LevelProgressService.markWordCompleted], which increments mastery (+0.25)
///   and fires the Map Bridge so the 3D world can react in real-time.
///
/// Multiple-choice option construction:
///   The correct (target) word is always included; 3 additional distractors are
///   drawn at random from the same level pool, guaranteeing context-coherent
///   wrong answers instead of cross-level noise.
///
/// Spark integration:
///   [SparkOverlayController] enters `celebrating` state on a correct answer
///   and returns to `idle` when the learner advances to the next question.
class ImageQuizGame extends StatefulWidget {
  const ImageQuizGame({
    super.key,
    this.levelId,
    this.initialWords,
    this.wordRepository,
    this.wordMasteryService,
    this.levelProgressService,
    this.levelRepository,
  });

  /// Optional level identifier for mastery namespacing. Defaults to the first
  /// level in `levels.json` when not provided, matching the legacy behaviour.
  final String? levelId;

  /// Seed words for the quiz. When provided (e.g. from [MyHomePage] or a test),
  /// the [LevelRepository] fetch is skipped. When null, words are loaded from
  /// `levels.json` automatically.
  final List<WordData>? initialWords;

  // Overridable services for testing.
  final WordRepository? wordRepository;
  final WordMasteryService? wordMasteryService;
  final LevelProgressService? levelProgressService;
  final LevelRepository? levelRepository;

  @override
  State<ImageQuizGame> createState() => _ImageQuizGameState();
}

class _ImageQuizGameState extends State<ImageQuizGame> {
  static const int _baseReward = 10;
  static const int _streakBonusStep = 2;
  static const int _minWords = 4;

  final math.Random _random = math.Random();

  late final WordRepository _wordRepository;
  late final WordMasteryService _wordMasteryService;
  late final LevelProgressService _levelProgressService;
  late final LevelRepository _levelRepository;

  // ── Loading state ──────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _loadError;

  // ── Word pool (sorted ascending by mastery — weak first) ───────────────────
  List<WordData> _wordsWithMastery = [];
  String _resolvedLevelId = 'level_1';

  // ── Question state ─────────────────────────────────────────────────────────
  int _currentIndex = 0;
  bool _answered = false;
  String? _selectedAnswer;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  bool _hintUsed = false;
  String? _feedbackMessage;
  late List<WordData> _currentOptions;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _wordRepository = widget.wordRepository ?? WordRepository();
    _wordMasteryService = widget.wordMasteryService ?? WordMasteryService();
    _levelProgressService = widget.levelProgressService ?? LevelProgressService();
    _levelRepository = widget.levelRepository ?? LevelRepository();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifySparkHappy();
      _loadAndSortWords();
    });
  }

  void _notifySparkHappy() {
    if (!mounted) return;
    try {
      context.read<SparkOverlayController>().setEmotion(SparkEmotion.happy);
    } catch (_) {}
  }

  @override
  void dispose() {
    if (mounted) {
      try {
        context.read<SparkOverlayController>().markIdle();
      } catch (_) {}
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Phase 3: Dynamic word loading + mastery sort
  // ---------------------------------------------------------------------------

  /// Loads words from [LevelRepository] (via `levels.json`) or uses
  /// [widget.initialWords] when provided, enriches them with Cloudinary images
  /// via [WordRepository], then merges and sorts by mastery ascending.
  ///
  /// **Why this is the core of spaced repetition:**
  ///   After this method runs, `_wordsWithMastery[0]` is the word the child
  ///   knows least and `_wordsWithMastery[last]` is the one they know best.
  ///   The quiz iterates this list in order, so the child always works on
  ///   their weakest vocabulary first before revisiting stronger words.
  Future<void> _loadAndSortWords() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final session = context.read<UserSessionProvider>();
      final userId = session.currentUser?.id ?? 'local_guest';

      // ── Step 1: Resolve the base word list ──────────────────────────────
      List<WordData> baseWords;
      String levelId;

      if (widget.initialWords != null && widget.initialWords!.isNotEmpty) {
        // Caller already supplied words — use them directly.
        baseWords = widget.initialWords!;
        levelId = widget.levelId ?? 'image_quiz_default';
      } else {
        // Dynamically load from levels.json.
        final levels = await _levelRepository.loadLevels();
        if (levels.isEmpty) {
          throw StateError('levels.json returned no levels');
        }
        // If a specific levelId was requested, find it; otherwise use the first.
        final targetLevel = widget.levelId != null
            ? levels.firstWhere(
                (l) => l.id == widget.levelId,
                orElse: () => levels.first,
              )
            : levels.first;
        baseWords = targetLevel.words;
        levelId = targetLevel.id;
      }
      _resolvedLevelId = levelId;

      // ── Step 2: Optionally enrich with Cloudinary images ───────────────
      // WordRepository.loadWords handles caching and fallback gracefully.
      final List<WordData> enrichedWords = await _wordRepository.loadWords(
        remoteEnabled: AppConfig.hasCloudinary,
        fallbackWords: baseWords,
        cloudName: AppConfig.cloudinaryCloudName,
        tagName: 'english_kids_app',
        maxResults: 50,
        cacheNamespace: levelId,
      );

      // ── Step 3: Merge persisted mastery into each word ──────────────────
      final List<WordData> withMastery = [];
      for (final word in enrichedWords) {
        final entry = await _wordMasteryService.getMastery(
          userId: userId,
          levelId: levelId,
          word: word.word,
        );
        withMastery.add(_wordMasteryService.applyToWord(word, entry));
      }

      // ── Step 4: Sort ascending by masteryLevel (weak words first) ───────
      //   masteryLevel 0.0 → never seen (highest priority)
      //   masteryLevel < 0.5 → still weak, needs repetition
      //   masteryLevel ≥ 0.5 → progressing toward mastery
      withMastery.sort((a, b) => a.masteryLevel.compareTo(b.masteryLevel));

      if (!mounted) return;

      setState(() {
        _wordsWithMastery = withMastery;
        _currentIndex = 0;
        _isLoading = false;
        _loadError = null;
      });

      if (_wordsWithMastery.length >= _minWords) {
        _prepareNextQuestion();
      }
    } catch (error, stackTrace) {
      debugPrint('ImageQuizGame: loadWords error: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'לא ניתן לטעון מילים. נסו שוב.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Question management
  // ---------------------------------------------------------------------------

  void _prepareNextQuestion() {
    if (_wordsWithMastery.length < _minWords) return;

    final target = _wordsWithMastery[_currentIndex];

    // Build 3 distractors from the same level pool (context-coherent).
    final others = _wordsWithMastery
        .where((w) => w.word != target.word)
        .toList()
      ..shuffle(_random);
    final distractors = others.take(3).toList();
    final options = [target, ...distractors]..shuffle(_random);

    setState(() {
      _currentOptions = options;
      _answered = false;
      _selectedAnswer = null;
      _hintUsed = false;
      _feedbackMessage = null;
    });
  }

  void _nextQuestion() {
    try {
      context.read<SparkOverlayController>().markIdle();
    } catch (_) {}

    setState(() {
      _currentIndex = (_currentIndex + 1) % _wordsWithMastery.length;
    });
    _prepareNextQuestion();
  }

  void _useHint() {
    if (_answered || _hintUsed) return;
    final target = _wordsWithMastery[_currentIndex];
    final wrongOptions = _currentOptions
        .where((w) => w.word != target.word)
        .toList();
    if (wrongOptions.isEmpty) return;

    final toRemove = wrongOptions[_random.nextInt(wrongOptions.length)];
    final remainingCount = _currentOptions.length - 1;
    final telemetry = TelemetryService.maybeOf(context);

    setState(() {
      _currentOptions = List<WordData>.from(_currentOptions)..remove(toRemove);
      _hintUsed = true;
      _feedbackMessage = 'הסרתי אפשרות שגויה אחת 😉';
    });

    telemetry?.logHintUsed(
      word: target.word,
      optionsRemaining: remainingCount,
    );
  }

  // ---------------------------------------------------------------------------
  // Answer handling
  // ---------------------------------------------------------------------------

  Future<void> _answerQuestion(String answer) async {
    if (_answered) return;

    final target = _wordsWithMastery[_currentIndex];
    final isCorrect = answer == target.word;
    final telemetry = TelemetryService.maybeOf(context);

    int reward = 0;
    int newScore = _score;
    int newStreak = _streak;
    String feedback;

    if (isCorrect) {
      newStreak = _streak + 1;
      reward = _baseReward + (newStreak - 1) * _streakBonusStep;
      newScore += reward;
      feedback = 'כל הכבוד! הרווחת +$reward מטבעות';

      if (mounted) {
        await context.read<CoinProvider>().addCoins(reward);

        // ── Phase 3 Integration ──────────────────────────────────────────
        // markWordCompleted performs all three of:
        //   1. Persists completion in SharedPreferences.
        //   2. WordMasteryService.recordSuccessfulReview (+0.25 mastery).
        //   3. MapBridgeService.emitWordMastered → 3D map reacts.
        await _markWordCompleted(target.word);

        // Spark celebrates the correct answer.
        try {
          context.read<SparkOverlayController>().markCelebrating();
        } catch (_) {}
      }
    } else {
      newStreak = 0;
      feedback = 'לא הפעם. המילה הנכונה: ${target.word}.';
    }

    setState(() {
      _answered = true;
      _selectedAnswer = answer;
      _streak = newStreak;
      _bestStreak = math.max(_bestStreak, newStreak);
      _score = newScore;
      _feedbackMessage = feedback;
    });

    telemetry?.logQuizAnswered(
      word: target.word,
      correct: isCorrect,
      reward: reward,
      streak: newStreak,
      questionIndex: _currentIndex,
      hintUsed: _hintUsed,
    );

    try {
      if (mounted) {
        context.read<DailyMissionProvider>().incrementByType(
          DailyMissionType.quizPlay,
        );
      }
    } on ProviderNotFoundException {
      // Standalone/test context without DailyMissionProvider — safe to ignore.
    }
  }

  /// Delegates to [LevelProgressService.markWordCompleted] with the current
  /// session user, wiring mastery + Map Bridge in one call.
  Future<void> _markWordCompleted(String word) async {
    try {
      final session = context.read<UserSessionProvider>();
      final userId = session.currentUser?.id ?? 'local_guest';
      final isLocalUser =
          session.currentUser == null || !session.currentUser!.isGoogle;
      await _levelProgressService.markWordCompleted(
        userId,
        _resolvedLevelId,
        word,
        isLocalUser: isLocalUser,
      );
    } catch (error, stackTrace) {
      debugPrint('ImageQuizGame: markWordCompleted error: $error');
      debugPrint('$stackTrace');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // ── Loading ──────────────────────────────────────────────────────────────
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.green.shade50,
        appBar: AppBar(
          title: const Text('Image Quiz'),
          backgroundColor: Colors.green.shade700,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // ── Error / insufficient words ───────────────────────────────────────────
    if (_loadError != null || _wordsWithMastery.length < _minWords) {
      return Scaffold(
        backgroundColor: Colors.green.shade50,
        appBar: AppBar(
          title: const Text('Image Quiz'),
          backgroundColor: Colors.green.shade700,
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_search,
                    size: 64, color: Colors.green.shade300),
                const SizedBox(height: 16),
                Text(
                  _loadError ??
                      'נדרשות לפחות $_minWords מילים כדי לשחק בבוחן התמונות.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadAndSortWords,
                  icon: const Icon(Icons.refresh),
                  label: const Text('נסו שוב'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Main quiz UI ─────────────────────────────────────────────────────────
    final target = _wordsWithMastery[_currentIndex];
    final totalCoins = context.watch<CoinProvider>().coins;

    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text('Image Quiz'),
        backgroundColor: Colors.green.shade700,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Stats header ────────────────────────────────────────────
              _buildScoreHeader(totalCoins),
              const SizedBox(height: 16),

              // ── Mastery progress bar ────────────────────────────────────
              _MasteryProgressBar(
                currentIndex: _currentIndex,
                total: _wordsWithMastery.length,
                masteryLevel: target.masteryLevel,
              ),
              const SizedBox(height: 16),

              // ── Target word display ─────────────────────────────────────
              _buildTargetWordCard(target),
              const SizedBox(height: 16),

              // ── Hint button ─────────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: (!_answered && !_hintUsed &&
                          _currentOptions.length > 2)
                      ? _useHint
                      : null,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(_hintUsed ? 'Hint used' : 'Get a hint'),
                ),
              ),
              const SizedBox(height: 16),

              // ── 2×2 image option grid ───────────────────────────────────
              _buildOptionGrid(target),

              const SizedBox(height: 12),

              // ── Feedback message ────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _feedbackMessage == null
                    ? const SizedBox.shrink()
                    : Container(
                        key: ValueKey(_feedbackMessage),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          _feedbackMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _answered &&
                                    _selectedAnswer == target.word
                                ? Colors.green.shade700
                                : Colors.purple,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),

              // ── Next question button ────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _answered
                        ? Colors.green.shade700
                        : Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 6,
                  ),
                  onPressed: _answered ? _nextQuestion : null,
                  child: Text(
                    _answered
                        ? 'Next question'
                        : 'Choose an answer to continue',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreHeader(int totalCoins) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 12,
          children: [
            _StatBadge(label: 'Score', value: _score, icon: Icons.emoji_events),
            _StatBadge(
              label: 'Streak',
              value: _streak,
              icon: Icons.local_fire_department,
            ),
            _StatBadge(
              label: 'Best',
              value: _bestStreak,
              icon: Icons.military_tech,
            ),
            _StatBadge(
              label: 'Coins',
              value: totalCoins,
              icon: Icons.attach_money,
            ),
          ],
        ),
      ),
    );
  }

  /// Displays the target word name and a speaker icon so the child can hear it.
  Widget _buildTargetWordCard(WordData target) {
    return Card(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Which image shows:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              target.word,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (target.searchHint != null &&
                target.searchHint!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                target.searchHint!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionGrid(WordData target) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.95,
      children: _currentOptions.map((option) {
        final imageUrl = _resolveImageUrl(option);
        return _ImageOptionTile(
          key: ValueKey(option.word),
          word: option,
          imageUrl: imageUrl,
          isSelected: _selectedAnswer == option.word,
          isCorrect: option.word == target.word,
          answered: _answered,
          onTap: () => _answerQuestion(option.word),
        );
      }).toList(),
    );
  }

  String? _resolveImageUrl(WordData word) {
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
}

// =============================================================================
// Private widgets
// =============================================================================

/// Shows where in the sorted weak→strong queue the learner currently is,
/// and highlights the current word's mastery level.
class _MasteryProgressBar extends StatelessWidget {
  const _MasteryProgressBar({
    required this.currentIndex,
    required this.total,
    required this.masteryLevel,
  });

  final int currentIndex;
  final int total;
  final double masteryLevel;

  @override
  Widget build(BuildContext context) {
    final bool isWeak = masteryLevel < 0.5;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total > 0 ? (currentIndex + 1) / total : 0,
              backgroundColor: Colors.green.shade100,
              valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.green.shade600),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isWeak
                ? Colors.orange.withValues(alpha: 0.15)
                : Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isWeak ? Colors.orange.shade300 : Colors.green.shade300,
            ),
          ),
          child: Text(
            isWeak ? 'תרגלו עוד' : 'מכירים טוב',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isWeak
                  ? Colors.orange.shade700
                  : Colors.green.shade700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${currentIndex + 1}/$total',
          style: TextStyle(
            fontSize: 13,
            color: Colors.green.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Image tile used as a multiple-choice option.
/// Renders asset URLs, http(s) URLs, and local file paths.
class _ImageOptionTile extends StatelessWidget {
  const _ImageOptionTile({
    super.key,
    required this.word,
    required this.imageUrl,
    required this.isSelected,
    required this.isCorrect,
    required this.answered,
    required this.onTap,
  });

  final WordData word;
  final String? imageUrl;
  final bool isSelected;
  final bool isCorrect;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget imageWidget = _buildImage();

    Color? borderColor;
    if (answered) {
      if (isCorrect) {
        borderColor = Colors.green.shade500;
      } else if (isSelected) {
        borderColor = Colors.orange.shade500;
      }
    } else if (isSelected) {
      borderColor = Colors.blue.shade400;
    }

    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: InkWell(
        onTap: answered ? null : onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: borderColor != null
                ? Border.all(color: borderColor, width: 3)
                : Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: SizedBox(width: double.infinity, child: imageWidget),
              ),
              // Always show word label, highlighted on answer reveal.
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Text(
                  answered ? word.word : '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: answered
                        ? (isCorrect
                            ? Colors.green.shade700
                            : Colors.orange.shade700)
                        : Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
        ),
      );
    }
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image, size: 48)),
      );
    }
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image, size: 48)),
      );
    }
    // Local file path (e.g. from the camera).
    if (!kIsWeb) {
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return Container(
      color: Colors.grey.shade200,
      child: const Center(child: Icon(Icons.image_not_supported, size: 48)),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.green.shade700),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Text(
          '$value',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
