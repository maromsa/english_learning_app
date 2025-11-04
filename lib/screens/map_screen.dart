// lib/screens/map_screen.dart
import 'package:english_learning_app/models/level_data.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shop_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<LevelData> levels = [];

  final List<Offset> levelPositions = [
    const Offset(0.6, 0.85), // שלב 1 (60% מהרוחב, 85% מהגובה)
    const Offset(0.2, 0.65), // שלב 2
    const Offset(0.7, 0.45), // שלב 3
    const Offset(0.3, 0.25), // שלב 4
  ];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  void _loadLevels() {
    // This is your level data
    levels = [
        LevelData(
          name: "שלב 1: פירות",
          isUnlocked: true,
          words: [
            WordData(word: 'Apple', imageUrl: 'assets/images/words/apple.png'),
            WordData(word: 'Banana', imageUrl: 'assets/images/words/banana.png'),
          ],
        ),
        LevelData(
          name: "שלב 2: חיות",
          words: [
            WordData(word: 'Dog', imageUrl: 'assets/images/words/dog.png'),
            WordData(word: 'Cat', imageUrl: 'assets/images/words/cat.png'),
          ],
        ),
    ];
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);

    // Coins are already loaded in main.dart, but ensure we have the latest
    await coinProvider.loadCoins();
    _loadLevels();

    setState(() {
      for (int i = 0; i < levels.length; i++) {
        levels[i].stars = prefs.getInt('level_${i}_stars') ?? 0;
        if (i > 0 && levels[i - 1].stars > 0) {
          levels[i].isUnlocked = true;
        }
      }
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    // Coins are auto-saved by CoinProvider, so we don't need to save them here
    for (int i = 0; i < levels.length; i++) {
      await prefs.setInt('level_${i}_stars', levels[i].stars);
    }
  }

  void _navigateToLevel(LevelData level, int levelIndex) async {
    Provider.of<CoinProvider>(context, listen: false).startLevel();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyHomePage(
          title: level.name,
          wordsForLevel: level.words,
        ),
      ),
    );

    if (mounted) {
      int coinsEarnedInLevel = Provider.of<CoinProvider>(context, listen: false).levelCoins;
      setState(() {
        int starsEarned = (coinsEarnedInLevel / 10).floor();
        if (starsEarned > levels[levelIndex].stars) {
          levels[levelIndex].stars = starsEarned;
        }
        if (levels[levelIndex].stars > 0 && (levelIndex + 1) < levels.length) {
          levels[levelIndex + 1].isUnlocked = true;
        }
      });
      await _saveProgress();
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
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.yellow.shade700),
                const SizedBox(width: 4),
                Text('${coinProvider.coins}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
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
        ],
      ),
      // --- התיקון כאן ---
      // ה-body הוא רק ה-Stack. ה-ListView נמחק.
      body: Stack(
        children: [
          Image.asset(
            'assets/images/map/map_background.jpg',
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
          ),
          ..._buildLevelNodes(),
        ],
      ),
    );
  }

  List<Widget> _buildLevelNodes() {
    List<Widget> nodes = [];
    for (int i = 0; i < levels.length; i++) {
      if (i < levelPositions.length) {
        nodes.add(
          Align(
            alignment: Alignment(levelPositions[i].dx * 2 - 1, levelPositions[i].dy * 2 - 1),
            child: _LevelNode(
              level: levels[i],
              levelNumber: i + 1,
              onTap: () => _navigateToLevel(levels[i], i),
            ),
          ),
        );
      }
    }
    return nodes;
  }
}

class _LevelNode extends StatelessWidget {
  final LevelData level;
  final int levelNumber;
  final VoidCallback? onTap;

  const _LevelNode({required this.level, required this.levelNumber, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: level.isUnlocked ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: level.isUnlocked ? Colors.amber.shade600 : Colors.grey.shade600,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 6, spreadRadius: 2)],
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: level.isUnlocked
            ? Text(
            levelNumber.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)
        )
            : const Icon(Icons.lock, color: Colors.white, size: 28),
      ),
    );
  }
}