// lib/widgets/score_display.dart
import 'package:flutter/material.dart';

class ScoreDisplay extends StatelessWidget {
  final int score;
  final int streak;

  const ScoreDisplay({super.key, required this.score, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 30),
              const SizedBox(width: 8),
              Text('$score', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          Row(
            children: [
              Icon(Icons.whatshot, color: Colors.deepOrange, size: 30),
              const SizedBox(width: 8),
              Text('$streak', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}