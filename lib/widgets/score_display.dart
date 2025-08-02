// lib/widgets/score_display.dart
import 'package:flutter/material.dart';

class ScoreDisplay extends StatelessWidget {
  final int coins;

  const ScoreDisplay({super.key, required this.coins});

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
              Text('$coins', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}