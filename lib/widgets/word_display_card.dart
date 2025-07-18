// lib/widgets/word_display_card.dart
import 'package:flutter/material.dart';
import '../models/word_data.dart';

class WordDisplayCard extends StatelessWidget {
  final WordData wordData;
  const WordDisplayCard({super.key, required this.wordData});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 2, blurRadius: 8, offset: const Offset(0, 4),) ],
            border: wordData.isCompleted ? Border.all(color: Colors.green.shade400, width: 4) : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.network(
                  wordData.imageUrl,
                  key: ValueKey(wordData.imageUrl),
                  width: 250,
                  height: 250,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.error_outline, size: 150, color: Colors.grey);
                  },
                ),
                if (wordData.isCompleted)
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
                    child: Icon(Icons.check_circle, color: Colors.green.shade400, size: 120),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        Text(wordData.word, style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
      ],
    );
  }
}