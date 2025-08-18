import 'package:flutter/material.dart';

class AnswerButton extends StatelessWidget {
  final String answer;
  final bool isSelected;
  final bool isCorrect;
  final bool answered;
  final VoidCallback onTap;

  const AnswerButton({
    super.key,
    required this.answer,
    required this.isSelected,
    required this.isCorrect,
    required this.answered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = Colors.blue.shade600;
    if (answered) {
      if (isCorrect) {
        backgroundColor = Colors.green.shade600;
      } else if (isSelected && !isCorrect) {
        backgroundColor = Colors.red.shade600;
      } else {
        backgroundColor = Colors.grey.shade400;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        onPressed: answered ? null : onTap,
        child: Text(
          answer,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }
}
