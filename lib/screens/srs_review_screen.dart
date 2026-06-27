// lib/screens/srs_review_screen.dart
//
// SRS Review Screen — dedicated daily flashcard session.
//
// Flow:
//   1. Load all due SRS cards for the current user from SQLite.
//   2. Resolve each card → WordData (word text, image, translation) via LevelRepository.
//   3. Present cards as flip cards: front = image + English word, back = Hebrew translation.
//   4. User taps "Easy" (grade 5) or "Hard" (grade 2) to advance and update SM-2.
//   5. Session summary screen with correct/wrong counts + coin reward.
//
// Navigated to via DailyMissionsScreen returning 'lightning' on the map
// (we can later add a dedicated entry point).

import 'dart:async';
import 'dart:math' as math;

import 'package:english_learning_app/models/srs_card.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/daily_mission_provider.dart';
import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/services/achievement_service.dart';
import 'package:english_learning_app/services/app_database.dart';
import 'package:english_learning_app/services/level_repository.dart';
import 'package:english_learning_app/services/spark_voice_service.dart';
import 'package:english_learning_app/services/srs_service.dart';
import 'package:english_learning_app/utils/aurora_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------------------
// Data model for one flashcard in the session
// ---------------------------------------------------------------------------

class _ReviewCard {
  _ReviewCard({
    required this.wordId,
    required this.levelId,
    required this.displayWord,
    this.imageUrl,
    this.translation,
    required this.srsCard,
  });

  final String wordId;
  final String levelId;
  final String displayWord;
  final String? imageUrl;
  final String? translation;
  final SrsCard srsCard;

  /// Whether the card was already answered in this session.
  bool answered = false;
  /// true=easy, false=hard
  bool? wasEasy;
}

// ---------------------------------------------------------------------------
// Screen widget
// ---------------------------------------------------------------------------

class SrsReviewScreen extends StatefulWidget {
  const SrsReviewScreen({
    super.key,
    LevelRepository? levelRepository,
    SrsService? srsService,
    AppDatabase? db,
  })  : _levelRepository = levelRepository,
        _srsService = srsService,
        _db = db;

  final LevelRepository? _levelRepository;
  final SrsService? _srsService;
  final AppDatabase? _db;

  @override
  State<SrsReviewScreen> createState() => _SrsReviewScreenState();
}

class _SrsReviewScreenState extends State<SrsReviewScreen>
    with SingleTickerProviderStateMixin {
  late final LevelRepository _levelRepo;
  late final SrsService _srsService;
  late final AppDatabase _db;
  final SparkVoiceService _voice = SparkVoiceService();

  // Session state
  bool _loading = true;
  String? _loadError;
  List<_ReviewCard> _cards = [];
  int _index = 0;
  bool _sessionDone = false;

  // Flip animation
  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;
  bool _isFlipped = false;

  // Counts
  int _easyCount = 0;
  int _hardCount = 0;

  @override
  void initState() {
    super.initState();
    _levelRepo = widget._levelRepository ?? LevelRepository();
    _srsService = widget._srsService ?? SrsService();
    _db = widget._db ?? AppDatabase.instance;

    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _flipAnim = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut),
    );

    _loadCards();
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadCards() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final session = context.read<UserSessionProvider>();
      final userId = session.currentUserId ?? 'local_guest';

      final dueRows = await _db.getAllDueCards(userId: userId, limit: 20);
      if (dueRows.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _cards = [];
        });
        return;
      }

      // Build a map of levelId → words for fast lookup.
      final levels = await _levelRepo.loadLevels();
      final wordMap = <String, Map<String, dynamic>>{};
      for (final level in levels) {
        final words = level.words.isNotEmpty
            ? level.words
            : await _levelRepo.loadWordsForLevel(level.id);
        for (final w in words) {
          final key = '${level.id}|${w.word.toLowerCase()}';
          wordMap[key] = {
            'displayWord': w.word,
            'imageUrl': w.imageUrl,
            'translation': w.translation,
          };
        }
      }

      final cards = <_ReviewCard>[];
      for (final row in dueRows) {
        final levelId = row['level_id'] as String? ?? '';
        final wordId = row['word_id'] as String? ?? '';
        final key = '$levelId|${wordId.toLowerCase()}';
        final wordInfo = wordMap[key];

        cards.add(_ReviewCard(
          wordId: wordId,
          levelId: levelId,
          displayWord: wordInfo?['displayWord'] as String? ?? wordId,
          imageUrl: wordInfo?['imageUrl'] as String?,
          translation: wordInfo?['translation'] as String?,
          srsCard: SrsCard(
            wordId: wordId,
            repetitions: (row['repetitions'] as int?) ?? 0,
            easeFactor: (row['ease_factor'] as num?)?.toDouble() ?? 2.5,
            intervalDays: (row['interval_days'] as int?) ?? 1,
            masteryLevel: (row['mastery_level'] as num?)?.toDouble() ?? 0.0,
            bestPronunciationStars: (row['best_stars'] as int?) ?? 0,
            nextReviewDate: row['next_review_ms'] != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    row['next_review_ms'] as int)
                : null,
          ),
        ));
      }

      // Shuffle so the session feels fresh.
      cards.shuffle(math.Random());

      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
      });

      // Auto-play the first word.
      if (cards.isNotEmpty) {
        unawaited(_speak(cards[0].displayWord));
      }
    } catch (e, st) {
      debugPrint('SrsReviewScreen._loadCards: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loadError = 'לא הצלחנו לטעון כרטיסיות. נסו שוב.';
        _loading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Card interaction
  // ---------------------------------------------------------------------------

  void _flipCard() {
    if (_isFlipped) return; // already revealed
    setState(() => _isFlipped = true);
    _flipCtrl.forward();
    unawaited(_speak(_cards[_index].displayWord));
  }

  Future<void> _answer({required bool easy}) async {
    if (_index >= _cards.length) return;
    final card = _cards[_index];
    card.answered = true;
    card.wasEasy = easy;

    if (easy) {
      _easyCount++;
    } else {
      _hardCount++;
    }

    // SM-2 grades: easy=5, hard=2
    final grade = easy ? 5 : 2;

    final session = context.read<UserSessionProvider>();
    final userId = session.currentUserId ?? 'local_guest';
    unawaited(_srsService.recordReview(
      userId: userId,
      levelId: card.levelId,
      word: card.displayWord,
      grade: grade,
    ));

    // Coin reward for easy answers.
    if (easy && mounted) {
      unawaited(context.read<CoinProvider>().addCoins(5));
    }

    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    if (_index + 1 >= _cards.length) {
      // Session done.
      _endSession();
    } else {
      setState(() {
        _index++;
        _isFlipped = false;
      });
      _flipCtrl.reset();
      unawaited(_speak(_cards[_index].displayWord));
    }
  }

  void _endSession() {
    // Fire daily mission increment.
    if (_easyCount + _hardCount > 0) {
      try {
        context.read<DailyMissionProvider>().incrementByType(
              DailyMissionType.srsReview,
            );
      } catch (_) {}
    }

    // Check mastered-words achievements asynchronously.
    unawaited(_checkMasteredAchievements());

    setState(() => _sessionDone = true);
  }

  Future<void> _checkMasteredAchievements() async {
    try {
      final session = context.read<UserSessionProvider>();
      final userId = session.currentUserId ?? 'local_guest';
      final masteredCount = await _db.getMasteredCount(userId: userId);
      if (!mounted) return;
      context.read<AchievementService>().checkForAchievements(
            streak: 0,
            masteredWords: masteredCount,
            wordsLearned: _easyCount + _hardCount,
          );
    } catch (_) {}
  }

  Future<void> _speak(String word) async {
    try {
      await _voice.speak(text: word, isEnglish: true);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuroraTokens.paper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'חזרה יומית',
          style: GoogleFonts.heebo(
            fontWeight: FontWeight.bold,
            color: AuroraTokens.ink,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _ErrorState(
        message: _loadError!,
        onRetry: _loadCards,
      );
    }
    if (_cards.isEmpty) {
      return const _NoDueCardsState();
    }
    if (_sessionDone) {
      return _SummaryState(
        easyCount: _easyCount,
        hardCount: _hardCount,
        total: _cards.length,
        onDone: () => Navigator.pop(context),
      );
    }
    return _buildReviewSession();
  }

  Widget _buildReviewSession() {
    final card = _cards[_index];
    final total = _cards.length;
    final progress = (_index + 1) / total;

    return SafeArea(
      child: Column(
        children: [
          // Progress bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_index + 1} / $total',
                      style: GoogleFonts.heebo(
                        fontSize: 13,
                        color: AuroraTokens.inkMute,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$_easyCount',
                          style: GoogleFonts.heebo(
                              color: Colors.green,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.refresh_rounded,
                            color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$_hardCount',
                          style: GoogleFonts.heebo(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor:
                        AuroraTokens.inkMute.withOpacity(0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AuroraTokens.blueberry),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Flashcard
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: _isFlipped ? null : _flipCard,
                child: AnimatedBuilder(
                  animation: _flipAnim,
                  builder: (context, child) {
                    final angle = _flipAnim.value;
                    final isFrontVisible = angle < math.pi / 2;

                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle),
                      alignment: Alignment.center,
                      child: isFrontVisible
                          ? _CardFront(card: card)
                          : Transform(
                              transform: Matrix4.rotationY(math.pi),
                              alignment: Alignment.center,
                              child: _CardBack(card: card),
                            ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Action buttons (only when flipped)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _isFlipped
                ? Padding(
                    key: const ValueKey('buttons'),
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(
                          child: _AnswerButton(
                            label: 'קשה',
                            icon: Icons.refresh_rounded,
                            color: Colors.orange.shade700,
                            onTap: () => _answer(easy: false),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _AnswerButton(
                            label: 'קל!',
                            icon: Icons.check_rounded,
                            color: Colors.green.shade600,
                            onTap: () => _answer(easy: true),
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    key: const ValueKey('hint'),
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'הקישו על הכרטיס לגילוי',
                      style: GoogleFonts.heebo(
                        color: AuroraTokens.inkMute,
                        fontSize: 15,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _CardFront extends StatelessWidget {
  const _CardFront({required this.card});
  final _ReviewCard card;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (card.imageUrl != null && card.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Image.network(
                card.imageUrl!,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(height: 180),
              ),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: AuroraTokens.blueberry.withOpacity(0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 64,
                  color: AuroraTokens.blueberry.withOpacity(0.4),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            card.displayWord,
            style: GoogleFonts.nunito(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AuroraTokens.ink,
            ),
          ),
          const SizedBox(height: 8),
          // Mastery dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < (card.srsCard.masteryLevel * 5).round();
              return Icon(
                filled ? Icons.circle : Icons.circle_outlined,
                size: 10,
                color: filled
                    ? AuroraTokens.blueberry
                    : AuroraTokens.inkMute.withOpacity(0.3),
              );
            }),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.card});
  final _ReviewCard card;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: AuroraTokens.blueberry.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.displayWord,
              style: GoogleFonts.nunito(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AuroraTokens.ink,
              ),
            ),
            const SizedBox(height: 16),
            if (card.translation != null && card.translation!.isNotEmpty) ...[
              Text(
                card.translation!,
                style: GoogleFonts.heebo(
                  fontSize: 28,
                  color: AuroraTokens.blueberry,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
            ],
            // SRS info
            _InfoRow(
              icon: Icons.repeat_rounded,
              label: 'חזרות',
              value: '${card.srsCard.repetitions}',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.event_rounded,
              label: 'מרווח',
              value: '${card.srsCard.intervalDays} ימים',
            ),
            if (card.srsCard.bestPronunciationStars > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (i) => Icon(
                    i < card.srsCard.bestPronunciationStars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 22,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AuroraTokens.inkMute),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: GoogleFonts.heebo(
            fontSize: 14,
            color: AuroraTokens.inkMute,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.heebo(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AuroraTokens.ink,
          ),
        ),
      ],
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: GoogleFonts.heebo(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 17,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _SummaryState extends StatelessWidget {
  const _SummaryState({
    required this.easyCount,
    required this.hardCount,
    required this.total,
    required this.onDone,
  });
  final int easyCount;
  final int hardCount;
  final int total;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (easyCount / total * 100).round() : 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'סיימת את החזרה!',
              style: GoogleFonts.heebo(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AuroraTokens.ink,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatBadge(
                  label: 'ידעתי',
                  value: '$easyCount',
                  color: Colors.green,
                  icon: Icons.check_circle_rounded,
                ),
                _StatBadge(
                  label: 'לחזור',
                  value: '$hardCount',
                  color: Colors.orange,
                  icon: Icons.refresh_rounded,
                ),
                _StatBadge(
                  label: 'ציון',
                  value: '$pct%',
                  color: AuroraTokens.blueberry,
                  icon: Icons.bar_chart_rounded,
                ),
              ],
            ),
            const SizedBox(height: 40),
            Text(
              'כרטיסיות שקשו יחזרו מחר 📚',
              textAlign: TextAlign.center,
              style: GoogleFonts.heebo(
                fontSize: 15,
                color: AuroraTokens.inkMute,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AuroraTokens.blueberry,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'חזרה למפה',
                  style: GoogleFonts.heebo(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.heebo(
            fontSize: 13,
            color: AuroraTokens.inkMute,
          ),
        ),
      ],
    );
  }
}

class _NoDueCardsState extends StatelessWidget {
  const _NoDueCardsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✨', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'אין כרטיסיות לחזרה כרגע!',
              style: GoogleFonts.heebo(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AuroraTokens.ink,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'כל הכרטיסיות שלך מעודכנות. חזרו מאוחר יותר.',
              textAlign: TextAlign.center,
              style: GoogleFonts.heebo(
                fontSize: 15,
                color: AuroraTokens.inkMute,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AuroraTokens.blueberry,
                padding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'חזרה למפה',
                style: GoogleFonts.heebo(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.heebo(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(
                'נסה שוב',
                style: GoogleFonts.heebo(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
