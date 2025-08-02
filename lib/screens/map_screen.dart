import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/level_data.dart';
import '../models/word_data.dart';
import '../providers/coin_provider.dart';
import 'home_page.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<LevelData> levels = [];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  void _loadLevels() {
    levels = [
      LevelData(
        name: "שלב 1: פירות",
        isUnlocked: true,
        words: [
          WordData(word: 'Apple', imageUrl: 'https://i.imgur.com/gAYAEa5.png'),
          WordData(word: 'Banana', imageUrl: 'https://i.imgur.com/r3yC4QG.png'),
        ],
      ),
      LevelData(
        name: "שלב 2: חיות",
        words: [
          WordData(word: 'Dog', imageUrl: 'https://i.imgur.com/v2p4EKC.png'),
          WordData(word: 'Cat', imageUrl: 'https://i.imgur.com/AU4Jj1z.png'),
        ],
      ),
      LevelData(
        name: "שלב 3: כלי תחבורה",
        words: [
          WordData(word: 'Car', imageUrl: 'https://i.imgur.com/mJ9f5gS.png'),
        ],
      ),
    ];
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);

    // Load the total coins into the provider
    coinProvider.setCoins(prefs.getInt('totalCoins') ?? 0);

    // Load the levels and then update their status from memory
    _loadLevels();

    setState(() {
      for (int i = 0; i < levels.length; i++) {
        levels[i].stars = prefs.getInt('level_${i}_stars') ?? 0;
        if (i > 0 && levels[i-1].stars > 0) {
          levels[i].isUnlocked = true;
        }
      }
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);

    await prefs.setInt('totalCoins', coinProvider.coins);
    for (int i = 0; i < levels.length; i++) {
      await prefs.setInt('level_${i}_stars', levels[i].stars);
    }
  }

  void _navigateToLevel(LevelData level, int levelIndex) async {
    // Before navigating, tell the CoinProvider to reset the current level's score to 0
    Provider.of<CoinProvider>(context, listen: false).startLevel();

    // Navigate to the learning screen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyHomePage(
          title: level.name,
          wordsForLevel: level.words,
        ),
      ),
    );

    // After returning, the CoinProvider will have the updated total.
    // We just need to check if the level is complete to unlock the next one.
    if (mounted) {
      setState(() {
        int coinsEarnedInLevel = Provider.of<CoinProvider>(context, listen: false).levelCoins;
        int starsEarned = (coinsEarnedInLevel / 10).floor();
        if (starsEarned > levels[levelIndex].stars) {
          levels[levelIndex].stars = starsEarned;
        }

        if (levels[levelIndex].stars > 0 && (levelIndex + 1) < levels.length) {
          levels[levelIndex + 1].isUnlocked = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final coinProvider = Provider.of<CoinProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("מסע המילים"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Row(
                children: [
                  Icon(Icons.monetization_on, color: Colors.yellow.shade700),
                  const SizedBox(width: 4),
                  Text('${coinProvider.coins}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          )
        ],
      ),
      body: ListView.builder(
        itemCount: levels.length,
        itemBuilder: (context, index) {
          final level = levels[index];
          return ListTile(
            leading: Icon(
              level.isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
              color: level.isUnlocked ? Colors.green : Colors.grey,
            ),
            title: Text(level.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${level.stars} כוכבים"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: level.isUnlocked
                ? () => _navigateToLevel(level, index)
                : null,
          );
        },
      ),
    );
  }
}