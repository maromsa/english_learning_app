// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import '../models/level_data.dart';
import '../models/word_data.dart';
import 'home_page.dart'; // נייבא את מסך הלמידה הקיים

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
    return Scaffold(
      appBar: AppBar(
        title: const Text("מסע המילים"),
        backgroundColor: Colors.amber,
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
                ? () {
              // ניווט למסך הלמידה עם המילים של השלב הספציפי
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyHomePage(
                    title: level.name,
                    wordsForLevel: level.words, // נעביר את רשימת המילים
                  ),
                ),
              );
            }
                : null, // אם השלב נעול, הכפתור לא יהיה לחיץ
          );
        },
      ),
    );
  }
}