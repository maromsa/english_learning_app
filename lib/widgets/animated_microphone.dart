import 'package:flutter/material.dart';

/// Animated microphone widget that pulses when listening
class AnimatedMicrophone extends StatefulWidget {
  const AnimatedMicrophone({
    super.key,
    required this.isListening,
    this.size = 80,
    this.color = Colors.redAccent,
  });

  final bool isListening;
  final double size;
  final Color color;

  @override
  State<AnimatedMicrophone> createState() => _AnimatedMicrophoneState();
}

class _AnimatedMicrophoneState extends State<AnimatedMicrophone>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isListening) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedMicrophone oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !oldWidget.isListening) {
      _controller.repeat(reverse: true);
    } else if (!widget.isListening && oldWidget.isListening) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing circle background
            if (widget.isListening)
              Opacity(
                opacity: 1.0 - _pulseAnimation.value,
                child: Container(
                  width: widget.size * 1.5 * _pulseAnimation.value,
                  height: widget.size * 1.5 * _pulseAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.3),
                  ),
                ),
              ),
            // Microphone icon
            Transform.scale(
              scale: widget.isListening ? _scaleAnimation.value : 1.0,
              child: Icon(
                Icons.mic,
                size: widget.size,
                color: widget.color,
              ),
            ),
          ],
        );
      },
    );
  }
}
