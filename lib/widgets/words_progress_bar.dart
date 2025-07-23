// lib/widgets/words_progress_bar.dart
import 'package:flutter/material.dart';

class WordsProgressBar extends StatelessWidget {
  final int totalWords;
  final int completedWords;

  const WordsProgressBar({
    super.key,
    required this.totalWords,
    required this.completedWords,
  });

  @override
  Widget build(BuildContext context) {
    // מונע חלוקה באפס אם אין מילים
    final double progress = totalWords > 0 ? completedWords / totalWords : 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          Text(
            '$completedWords / $totalWords words completed',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }
}