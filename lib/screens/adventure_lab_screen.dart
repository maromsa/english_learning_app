import 'package:english_learning_app/app_config.dart';
import 'package:english_learning_app/models/level_data.dart';
import 'package:english_learning_app/models/local_user.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/spark_overlay_controller.dart';
import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/services/adventure_lab_service.dart';
import 'package:english_learning_app/services/background_music_service.dart';
import 'package:english_learning_app/services/local_user_service.dart';
import 'package:english_learning_app/services/spark_voice_service.dart';
import 'package:english_learning_app/utils/aurora_tokens.dart';
import 'package:english_learning_app/utils/route_observer.dart';
import 'package:english_learning_app/widgets/living_spark.dart';
import 'package:english_learning_app/widgets/ui/_barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

/// Spark's Adventure Lab — AI story quests for unlocked worlds.
class AdventureLabScreen extends StatefulWidget {
  const AdventureLabScreen({
    super.key,
    required this.levels,
    required this.totalStars,
  });

  final List<LevelData> levels;
  final int totalStars;

  @override
  State<AdventureLabScreen> createState() => _AdventureLabScreenState();
}

class _AdventureLabScreenState extends State<AdventureLabScreen>
    with RouteAware, TickerProviderStateMixin {
  late final AdventureLabService _service;
  late LevelData _selectedLevel;
  final LocalUserService _localUserService = LocalUserService();

  String _selectedMood = _moods.first;
  bool _isGenerating = false;
  AdventureLabQuest? _quest;
  String? _error;
  final TextEditingController _nameController = TextEditingController();

  late final AnimationController _sparkFloatController;

  static const List<String> _moods = <String>[
    'brave explorer',
    'curious scientist',
    'kind helper',
    'silly comedian',
  ];

  static const Map<String, String> _moodLabels = <String, String>{
    'brave explorer': 'חוקר אמיץ',
    'curious scientist': 'מדען סקרן',
    'kind helper': 'עוזר טוב',
    'silly comedian': 'ליצן מצחיק',
  };

  static const Map<String, IconData> _moodIcons = <String, IconData>{
    'brave explorer': Icons.explore,
    'curious scientist': Icons.science_outlined,
    'kind helper': Icons.favorite_border,
    'silly comedian': Icons.sentiment_very_satisfied,
  };

  List<LevelData> get _unlockedLevels =>
      widget.levels.where((l) => l.isUnlocked).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _sparkFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    BackgroundMusicService()
        .fadeOut(duration: const Duration(milliseconds: 300))
        .then((_) => BackgroundMusicService().stop())
        .catchError((_) => BackgroundMusicService().stop());

    _service = AdventureLabService();
    _selectedLevel = _initialLevel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    RouteObserverService.routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  LevelData _initialLevel() {
    final unlocked = _unlockedLevels;
    if (unlocked.isNotEmpty) return unlocked.first;
    if (widget.levels.isNotEmpty) return widget.levels.first;
    return LevelData(
      id: 'placeholder_world',
      name: 'עולם ראשון',
      words: const <WordData>[],
      isUnlocked: true,
    );
  }

  @override
  void dispose() {
    RouteObserverService.routeObserver.unsubscribe(this);
    _nameController.dispose();
    _sparkFloatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sparkReady = AppConfig.hasGeminiProxy;
    final coins = context.watch<CoinProvider>().coins;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('מעבדת ההרפתקאות של ספרק'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2D1B69), AuroraTokens.plum, Color(0xFFB388FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSparkHeader(),
                const SizedBox(height: 20),
                if (!sparkReady) _buildConfigBanner() else ...[
                  _buildSetupCard(coins: coins),
                  const SizedBox(height: 20),
                  if (_isGenerating) _buildLoadingPanel(),
                  if (_error != null) _buildErrorBanner(_error!),
                  if (_quest != null && !_isGenerating)
                    _QuestReveal(quest: _quest!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSparkHeader() {
    return AnimatedBuilder(
      animation: _sparkFloatController,
      builder: (context, child) {
        final dy = 6 * (_sparkFloatController.value - 0.5) * 2;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: Column(
        children: [
          const LivingSpark(
            emotion: SparkEmotion.excited,
            size: 100,
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: 2400.ms,
                color: Colors.white.withValues(alpha: 0.35),
              ),
          const SizedBox(height: 12),
          Text(
            'ספרק ממציא משימות קסם רק בשבילכם!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigBanner() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'הגדירו GEMINI_PROXY_URL שמפנה לפונקציית הענן כדי לפתוח את מעבדת ההרפתקאות.',
          style: TextStyle(
            color: Colors.red.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSetupCard({required int coins}) {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: AuroraTokens.paper,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'שם המטייל/ת (לא חובה)',
                prefixIcon: Icon(Icons.person_outline, color: AuroraTokens.plum),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            _buildWorldPicker(),
            const SizedBox(height: 16),
            Text(
              'איזה מצב רוח?',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AuroraTokens.ink,
                  ),
            ),
            const SizedBox(height: 8),
            _buildMoodChips(),
            const SizedBox(height: 16),
            _buildStatsRow(coins: coins),
            const SizedBox(height: 20),
            KidButton.primary(
              label: _isGenerating ? 'ספרק חושב...' : 'צרו לי משימת קסם!',
              leadingIcon: Icons.auto_stories,
              isLoading: _isGenerating,
              fullWidth: true,
              onPressed: _isGenerating ? null : () => _generateQuest(coins),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorldPicker() {
    final options = _unlockedLevels.isNotEmpty ? _unlockedLevels : widget.levels;
    if (options.isEmpty) {
      return Text(
        'אין עדיין עולמות פתוחים. המשיכו במפה כדי לפתוח עולמות חדשים!',
        style: TextStyle(color: AuroraTokens.inkMute, fontSize: 14),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'בחרו עולם פתוח',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AuroraTokens.ink,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((level) {
            final selected = level.id == _selectedLevel.id;
            return FilterChip(
              selected: selected,
              avatar: Icon(
                level.isUnlocked ? Icons.public : Icons.lock_outline,
                size: 18,
                color: selected ? Colors.white : AuroraTokens.plum,
              ),
              label: Text(level.name),
              selectedColor: AuroraTokens.plum,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AuroraTokens.ink,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) {
                setState(() => _selectedLevel = level);
              },
            );
          }).toList(growable: false),
        ),
      ],
    );
  }

  Widget _buildMoodChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _moods.map((mood) {
        final selected = mood == _selectedMood;
        return ChoiceChip(
          selected: selected,
          avatar: Icon(
            _moodIcons[mood],
            size: 18,
            color: selected ? Colors.white : AuroraTokens.blueberry,
          ),
          label: Text(_moodLabels[mood] ?? mood),
          selectedColor: AuroraTokens.blueberry,
          labelStyle: TextStyle(
            color: selected ? Colors.white : AuroraTokens.ink,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) => setState(() => _selectedMood = mood),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildStatsRow({required int coins}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AuroraTokens.plum.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatChip(icon: Icons.monetization_on, label: 'מטבעות', value: '$coins'),
            _StatChip(
              icon: Icons.star_rate,
              label: 'כוכבים',
              value: '${widget.totalStars}',
            ),
            _StatChip(
              icon: Icons.stars,
              label: 'בעולם',
              value: '${_selectedLevel.stars}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingPanel() {
    return Column(
      children: [
        const SizedBox(height: 8),
        SparkOrb(state: OrbState.thinking, size: 140),
        const SizedBox(height: 16),
        Text(
          'ספרק טווה סיפור קסום...',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 16),
        const _ShimmerStorySkeleton(),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.orange.shade800, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  final coins = context.read<CoinProvider>().coins;
                  _generateQuest(coins);
                },
                child: const Text('נסו שוב'),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Future<void> _generateQuest(int coins) async {
    setState(() {
      _isGenerating = true;
      _error = null;
      _quest = null;
    });

    final sparkController =
        Provider.of<SparkOverlayController>(context, listen: false);
    sparkController.markThinking();

    final selected = _selectedLevel;
    final unlockedNames = _unlockedLevels.map((l) => l.name).toList(growable: false);

    final labContext = AdventureLabContext(
      levelName: selected.name,
      levelDescription:
          selected.description ?? 'שלב מפתיע מלא אוצרות למידה מרגשים.',
      vocabularyWords: selected.words
          .map((word) => word.word)
          .take(6)
          .toList(growable: false),
      levelStars: selected.stars,
      totalStars: widget.totalStars,
      coins: coins,
      mood: _selectedMood,
      playerName: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      unlockedWorldNames: unlockedNames,
    );

    try {
      final userSession =
          Provider.of<UserSessionProvider>(context, listen: false);
      final appUser = userSession.currentUser;
      LocalUser? localUser;

      if (appUser != null && !appUser.isGoogle) {
        localUser = await _localUserService.getUserById(appUser.id);
      }

      final quest = await _service.generateQuest(
        labContext,
        user: appUser,
        localUser: localUser,
      );
      if (!mounted) return;
      setState(() => _quest = quest);
      sparkController.markCelebrating();
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) sparkController.markIdle();
      });
    } on AdventureLabGenerationException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      sparkController.markIdle();
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}

class _QuestReveal extends StatelessWidget {
  const _QuestReveal({required this.quest});

  final AdventureLabQuest quest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuestCard(
          icon: Icons.menu_book_rounded,
          iconColor: AuroraTokens.plum,
          title: quest.title.isEmpty ? 'המשימה של ספרק' : quest.title,
          body: quest.scene,
          accent: AuroraTokens.plum,
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
        if (quest.challenge.isNotEmpty) ...[
          const SizedBox(height: 12),
          _QuestCard(
            icon: Icons.flash_on_rounded,
            iconColor: AuroraTokens.butter,
            title: 'האתגר שלכם',
            body: quest.challenge,
            accent: AuroraTokens.coral,
          )
              .animate(delay: 120.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.08, end: 0),
        ],
        if (quest.pepTalk.isNotEmpty) ...[
          const SizedBox(height: 12),
          _QuestCard(
            icon: Icons.favorite_rounded,
            iconColor: AuroraTokens.mint,
            title: 'ספרק אומר',
            body: quest.pepTalk,
            accent: AuroraTokens.mint,
          )
              .animate(delay: 220.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.08, end: 0),
        ],
        if (quest.vocabulary.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: quest.vocabulary
                .map(
                  (word) => Chip(
                    label: Text(
                      word,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    avatar: Icon(Icons.translate, color: AuroraTokens.plum, size: 18),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: AuroraTokens.plum.withValues(alpha: 0.4)),
                  )
                      .animate(delay: (300 + quest.vocabulary.indexOf(word) * 60).ms)
                      .scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1, 1),
                        curve: Curves.elasticOut,
                      ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border(left: BorderSide(color: accent, width: 5)),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: iconColor.withValues(alpha: 0.2),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AuroraTokens.ink,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: const TextStyle(fontSize: 16, height: 1.55, color: AuroraTokens.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerStorySkeleton extends StatefulWidget {
  const _ShimmerStorySkeleton();

  @override
  State<_ShimmerStorySkeleton> createState() => _ShimmerStorySkeletonState();
}

class _ShimmerStorySkeletonState extends State<_ShimmerStorySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Column(
          children: List<Widget>.generate(3, (index) {
            final phase = (_controller.value + index * 0.2) % 1.0;
            final opacity = 0.35 + 0.45 * (0.5 + 0.5 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2));
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                height: index == 0 ? 72 : 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AuroraTokens.plum, size: 22),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AuroraTokens.inkMute)),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AuroraTokens.ink),
        ),
      ],
    );
  }
}
