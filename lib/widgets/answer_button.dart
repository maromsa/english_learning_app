import 'package:flutter/material.dart';

class AnswerButton extends StatefulWidget {
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
  State<AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<AnswerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = Colors.blue.shade600;
    if (widget.answered) {
      if (widget.isCorrect) {
        backgroundColor = Colors.green.shade600;
      } else if (widget.isSelected && !widget.isCorrect) {
        backgroundColor = Colors.red.shade600;
      } else {
        backgroundColor = Colors.grey.shade400;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            onPressed: widget.answered
                ? null
                : () {
                    _controller.forward().then((_) {
                      _controller.reverse();
                    });
                    widget.onTap();
                  },
            child: Text(
              widget.answer,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
