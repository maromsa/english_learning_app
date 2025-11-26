import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:english_learning_app/services/spark_voice_service.dart';

// Re-export SparkEmotion from spark_voice_service for convenience
// The enum is defined in spark_voice_service.dart to avoid duplication

/// A living, breathing Spark character widget that reacts to emotions
/// Makes Spark feel like a real friend, not just a static avatar
class LivingSpark extends StatelessWidget {
  final SparkEmotion emotion;
  final double size;

  const LivingSpark({
    super.key,
    this.emotion = SparkEmotion.neutral,
    this.size = 150.0,
  });

  @override
  Widget build(BuildContext context) {
    // For now, use icon-based representation
    // In production, replace with actual Spark character images
    IconData sparkIcon;
    Color sparkColor;

    // Map SparkEmotion from spark_voice_service to visual representation
    switch (emotion) {
      case SparkEmotion.happy:
        sparkIcon = Icons.sentiment_very_satisfied;
        sparkColor = const Color(0xFFFFD93D); // Yellow
        break;
      case SparkEmotion.excited:
        sparkIcon = Icons.celebration;
        sparkColor = const Color(0xFFFF6B6B); // Orange
        break;
      case SparkEmotion.empathetic:
        sparkIcon = Icons.psychology;
        sparkColor = const Color(0xFF7B68EE); // Purple
        break;
      case SparkEmotion.teaching:
        sparkIcon = Icons.school;
        sparkColor = const Color(0xFF50C878); // Green
        break;
      case SparkEmotion.neutral:
      default:
        sparkIcon = Icons.auto_awesome;
        sparkColor = const Color(0xFF4A90E2); // Blue
        break;
    }

    Widget sparkWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            sparkColor,
            sparkColor.withValues(alpha: 0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: sparkColor.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(
        sparkIcon,
        size: size * 0.6,
        color: Colors.white,
      ),
    );

    // Add breathing animation when neutral/idle
    if (emotion == SparkEmotion.neutral) {
      sparkWidget = sparkWidget
          .animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          )
          .scaleXY(
            begin: 1.0,
            end: 1.05,
            duration: 2000.ms,
            curve: Curves.easeInOut,
          );
    }

    // Add celebration animation
    if (emotion == SparkEmotion.excited) {
      sparkWidget = sparkWidget
          .animate()
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.2, 1.2),
            duration: 300.ms,
            curve: Curves.elasticOut,
          )
          .then()
          .scale(
            begin: const Offset(1.2, 1.2),
            end: const Offset(1.0, 1.0),
            duration: 300.ms,
          );
    }

    // Add thinking animation (gentle pulse)
    if (emotion == SparkEmotion.empathetic) {
      sparkWidget = sparkWidget
          .animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          )
          .scaleXY(
            begin: 1.0,
            end: 1.08,
            duration: 1500.ms,
            curve: Curves.easeInOut,
          );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: sparkWidget,
    );
  }
}

