// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import '../models/level_data.dart';
import '../models/word_data.dart';
import 'home_page.dart'; // נייבא את מסך הלמידה הקיים
import 'package:provider/provider.dart';
import '../providers/coin_provider.dart';

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
    _loadLevels();
  }

  // Add this function inside your _MapScreenState class
  void _navigateToLevel(LevelData level, int levelIndex) async {

    Provider.of<CoinProvider>(context, listen: false).coins;

    final result = await Navigator.push<Map<String, int>>(
      context,
      MaterialPageRoute(
        builder: (context) => MyHomePage(
          title: level.name,
          wordsForLevel: level.words,
        ),
      ),
    );

    // After returning from the level, update the coins and unlock the next level
    if (result != null && mounted) {
      setState(() {
        // You can update the total score if you have a variable for it
        int coinsEarnedInLevel = Provider.of<CoinProvider>(context, listen: false).coins;
        final int coinsFromLevel = result['coins'] ?? 0;
        Provider.of<CoinProvider>(context, listen: false).addCoins(coinsFromLevel);

        int starsEarned = (result['coins'] ?? 0) ~/ 10; // 1 star per 10 points
        if (starsEarned > levels[levelIndex].stars) {
          levels[levelIndex].stars = starsEarned;
        }

        // Unlock the next level if the current one has at least one star
        if (levels[levelIndex].stars > 0 && (levelIndex + 1) < levels.length) {
          levels[levelIndex + 1].isUnlocked = true;
        }
      });
    }
  }

  void _loadLevels() {
    // כאן נגדיר את השלבים והמילים שלנו באופן זמני
    // בהמשך נוכל לטעון אותם מהענן
    levels = [
      LevelData(
        name: "שלב 1: פירות",
        isUnlocked: true, // השלב הראשון תמיד פתוח
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
            title: Text(level.name, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${level.stars} כוכבים"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: level.isUnlocked
                ? () => _navigateToLevel(level, index)
                : null, // אם השלב נעול, הכפתור לא יהיה לחיץ
          );
        },
      ),
    );
  }
}