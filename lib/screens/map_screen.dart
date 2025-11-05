// lib/screens/map_screen.dart
import 'package:english_learning_app/models/level_data.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/daily_reward_service.dart';
import '../services/level_repository.dart';
import 'ai_adventure_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<LevelData> levels = [];
  late final DailyRewardService _dailyRewardService;
  late final LevelRepository _levelRepository;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dailyRewardService = DailyRewardService();
    _levelRepository = LevelRepository();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final loadedLevels = await _levelRepository.loadLevels();
      levels = loadedLevels.isEmpty ? _fallbackLevels() : loadedLevels;
      await _loadProgress();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = loadedLevels.isEmpty
              ? 'נשתמש במסלול ברירת המחדל עד לחיבור לשרת.'
              : null;
        });
      }
    } catch (e) {
      levels = _fallbackLevels();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'לא ניתן לטעון את המפה מהקובץ. מוצג מסלול ברירת מחדל.';
        });
      }
    }
  }

  List<LevelData> _fallbackLevels() {
    return [
      LevelData(
        id: 'fallback_fruits',
        name: 'שלב 1: פירות',
        description: 'למדו מילים מתוקות של פירות צבעוניים',
        unlockStars: 0,
        reward: 30,
        positionX: 0.6,
        positionY: 0.85,
        isUnlocked: true,
        words: [
          WordData(word: 'Apple', searchHint: 'ripe red apple fruit'),
          WordData(word: 'Banana', searchHint: 'yellow banana fruit bunch'),
          WordData(word: 'Orange', searchHint: 'fresh orange citrus fruit'),
          WordData(word: 'Strawberry', searchHint: 'sweet strawberry fruit'),
          WordData(word: 'Pineapple', searchHint: 'pineapple tropical fruit'),
          WordData(word: 'Grapes', searchHint: 'grapes fruit bunch purple'),
        ],
      ),
      LevelData(
        id: 'fallback_animals',
        name: 'שלב 2: חיות',
        description: 'מי נובח ומי מגרגר?',
        unlockStars: 3,
        reward: 45,
        positionX: 0.2,
        positionY: 0.68,
        words: [
          WordData(word: 'Dog', searchHint: 'happy dog pet'),
          WordData(word: 'Cat', searchHint: 'curious cat kitty'),
          WordData(word: 'Elephant', searchHint: 'elephant safari animal'),
          WordData(word: 'Lion', searchHint: 'roaring lion wildlife'),
          WordData(word: 'Penguin', searchHint: 'penguin waddling arctic'),
          WordData(word: 'Monkey', searchHint: 'playful monkey jungle'),
        ],
      ),
      LevelData(
        id: 'fallback_magic_items',
        name: 'שלב 3: פריטי קסם',
        description: 'תלבשו את הפריט הנכון למשימה',
        unlockStars: 7,
        reward: 55,
        positionX: 0.74,
        positionY: 0.46,
        words: [
          WordData(word: 'Magic Hat', searchHint: 'wizard magic hat'),
          WordData(word: 'Crystal Ball', searchHint: 'glowing crystal ball magic'),
          WordData(word: 'Spell Book', searchHint: 'ancient spell book'),
          WordData(word: 'Magic Wand', searchHint: 'sparkling magic wand'),
          WordData(word: 'Potion', searchHint: 'magical potion bottle'),
          WordData(word: 'Flying Broom', searchHint: 'witch flying broomstick'),
        ],
      ),
      LevelData(
        id: 'fallback_power_items',
        name: 'שלב 4: כוח מיוחד',
        description: 'אספו פריטי כוח מיוחדים',
        unlockStars: 11,
        reward: 65,
        positionX: 0.32,
        positionY: 0.32,
        words: [
          WordData(word: 'Power Sword', searchHint: 'shining power sword'),
          WordData(word: 'Treasure Map', searchHint: 'ancient treasure map'),
          WordData(word: 'Hero Shield', searchHint: 'bright hero shield'),
          WordData(word: 'Energy Gauntlet', searchHint: 'futuristic energy gauntlet'),
          WordData(word: 'Magic Amulet', searchHint: 'glowing magic amulet'),
          WordData(word: 'Dragon Armor', searchHint: 'dragon scale armor'),
        ],
      ),
      LevelData(
        id: 'fallback_vehicles',
        name: 'שלב 5: כלי תחבורה',
        description: 'איזה כלי יביא אתכם להרפתקה הבאה?',
        unlockStars: 15,
        reward: 75,
        positionX: 0.15,
        positionY: 0.18,
        words: [
          WordData(word: 'Car', searchHint: 'red family car road'),
          WordData(word: 'Train', searchHint: 'passenger train railway'),
          WordData(word: 'Helicopter', searchHint: 'helicopter flying sky'),
          WordData(word: 'Submarine', searchHint: 'yellow submarine underwater'),
          WordData(word: 'Bicycle', searchHint: 'kid bicycle ride'),
          WordData(word: 'Hot Air Balloon', searchHint: 'colorful hot air balloon'),
        ],
      ),
      LevelData(
        id: 'fallback_space',
        name: 'שלב 6: חקר החלל',
        description: 'צאו למסע בין הכוכבים',
        unlockStars: 20,
        reward: 90,
        positionX: 0.85,
        positionY: 0.18,
        words: [
          WordData(word: 'Astronaut', searchHint: 'astronaut space suit'),
          WordData(word: 'Rocket', searchHint: 'rocket launch space'),
          WordData(word: 'Moon', searchHint: 'full moon night sky'),
          WordData(word: 'Space Station', searchHint: 'international space station'),
          WordData(word: 'Satellite', searchHint: 'satellite orbit earth'),
          WordData(word: 'Mars Rover', searchHint: 'mars rover exploration'),
        ],
      ),
    ];
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);

    await coinProvider.loadCoins();

    for (int i = 0; i < levels.length; i++) {
      final level = levels[i];
      final persistedStars = prefs.getInt(_starsKey(level.id)) ??
          prefs.getInt(_legacyStarsKey(i));
      if (persistedStars != null) {
        level.stars = persistedStars;
      }
    }

    _updateUnlockStatuses();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < levels.length; i++) {
      final level = levels[i];
      await prefs.setInt(_starsKey(level.id), level.stars);
      await prefs.remove(_legacyStarsKey(i));
    }
  }

  String _starsKey(String levelId) => 'level_${levelId}_stars';
  String _legacyStarsKey(int index) => 'level_${index}_stars';

  void _updateUnlockStatuses() {
    int accumulatedStars = 0;
    for (final level in levels) {
      level.isUnlocked = accumulatedStars >= level.unlockStars;
      accumulatedStars += level.stars;
    }
    if (levels.isNotEmpty) {
      levels.first.isUnlocked = true;
    }
  }

  int get _totalStars => levels.fold<int>(0, (sum, level) => sum + level.stars);

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (!mounted) return;
    await _loadProgress();
  }

  void _showLockedMessage(LevelData level) {
    int missingStars = level.unlockStars - _totalStars;
    if (missingStars < 0) {
      missingStars = 0;
    }
    final message = missingStars > 0
        ? 'אספו עוד $missingStars כוכבים כדי לפתוח את ${level.name}.'
        : 'סיימו את השלבים הקודמים כדי לפתוח את ${level.name}.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black87,
      ),
    );
  }

  Future<void> _claimDailyReward() async {
    final result = await _dailyRewardService.claimReward();
    if (!mounted) {
      return;
    }

    if (result.claimed) {
      await Provider.of<CoinProvider>(context, listen: false).addCoins(result.reward);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎁 קיבלת ${result.reward} מטבעות! רצף יומי: ${result.streak}'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('כבר אספת את המתנה היום! רצף יומי: ${result.streak}'),
          backgroundColor: Colors.orange.shade600,
        ),
      );
    }
  }

  void _navigateToLevel(LevelData level, int levelIndex) async {
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);
    coinProvider.startLevel();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyHomePage(
          title: level.name,
          levelId: level.id,
          wordsForLevel: level.words,
        ),
      ),
    );

    if (mounted) {
      final coinsEarnedInLevel = coinProvider.levelCoins;
      final levelData = levels[levelIndex];
      final previousStars = levelData.stars;
      final starsEarned = ((coinsEarnedInLevel / 10).floor())
          .clamp(0, 3) as int;

      final bool gainedMoreStars = starsEarned > previousStars;
      final bool shouldReward =
          gainedMoreStars && previousStars == 0 && levelData.reward > 0;

      if (gainedMoreStars) {
        levelData.stars = starsEarned;
      }

      _updateUnlockStatuses();
      setState(() {});
      await _saveProgress();

      if (shouldReward && mounted) {
        await coinProvider.addCoins(levelData.reward);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⭐ כל הכבוד! קיבלתם בונוס של ${levelData.reward} מטבעות.'),
            backgroundColor: Colors.blueGrey.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coinProvider = Provider.of<CoinProvider>(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("מסע המילים", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 4, color: Colors.black45)])),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'מסע קסם עם Spark',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiAdventureScreen(
                      levels: List<LevelData>.unmodifiable(levels),
                      totalStars: _totalStars,
                    ),
                  ),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.yellow.shade700),
                const SizedBox(width: 4),
                Text('${coinProvider.coins}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 4),
                Text('$_totalStars', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.card_giftcard),
            tooltip: 'מתנת היום',
            onPressed: _claimDailyReward,
          ),
          IconButton(
            icon: const Icon(Icons.store),
            tooltip: 'חנות',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'הגדרות',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Stack(
        children: [
          Image.asset(
            'assets/images/map/map_background.jpg',
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (levels.isEmpty)
            const Center(
              child: Text(
                'אין שלבים זמינים כרגע. נסו שוב מאוחר יותר.',
                style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            )
          else ..._buildLevelNodes(context),
          if (_errorMessage != null && !_isLoading)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: _InfoBanner(message: _errorMessage!),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildLevelNodes(BuildContext context) {
    final List<Widget> nodes = [];
    for (int i = 0; i < levels.length; i++) {
      final level = levels[i];
      nodes.add(
        Align(
          alignment: Alignment(level.positionX * 2 - 1, level.positionY * 2 - 1),
          child: _LevelNode(
            level: level,
            levelNumber: i + 1,
            onTap: () => _navigateToLevel(level, i),
            onLockedTap: () => _showLockedMessage(level),
          ),
        ),
      );
    }
    return nodes;
  }
}

class _LevelNode extends StatelessWidget {
  final LevelData level;
  final int levelNumber;
  final VoidCallback? onTap;
  final VoidCallback? onLockedTap;

  const _LevelNode({required this.level, required this.levelNumber, this.onTap, this.onLockedTap});

  @override
  Widget build(BuildContext context) {
    final int cappedStars = level.stars.clamp(0, 3) as int;
    return Tooltip(
      message: level.description ?? '${level.words.length} מילים בשלב',
      child: InkWell(
        onTap: () {
          if (level.isUnlocked) {
            onTap?.call();
          } else {
            onLockedTap?.call();
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: level.isUnlocked ? Colors.amber.shade600 : Colors.grey.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 6, spreadRadius: 2),
                ],
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: level.isUnlocked
                  ? Text(
                      levelNumber.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    )
                  : const Icon(Icons.lock, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return Icon(
                  index < cappedStars ? Icons.star : Icons.star_border,
                  color: index < cappedStars ? Colors.amber : Colors.white,
                  size: 18,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;

  const _InfoBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}