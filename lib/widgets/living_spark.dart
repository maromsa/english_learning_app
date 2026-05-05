import 'package:english_learning_app/providers/spark_overlay_controller.dart';
import 'package:english_learning_app/services/spark_voice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

/// Global, persistent Spark companion widget that listens to
/// [SparkOverlayController] for emotion, visibility and basic animation state.
class LivingSparkOverlay extends StatelessWidget {
  const LivingSparkOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SparkOverlayController>(
      builder: (context, controller, _) {
        if (!controller.isVisible) {
          return const SizedBox.shrink();
        }

        final alignment = _alignmentForPosition(controller.position);
        final emotion = controller.emotion;

        return IgnorePointer(
          ignoring: true,
          child: Align(
            alignment: alignment,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _SparkBubble(
                emotion: emotion,
                animationState: controller.animationState,
              ),
            ),
          ),
        );
      },
    );
  }

  Alignment _alignmentForPosition(SparkOverlayPosition position) {
    switch (position) {
      case SparkOverlayPosition.bottomRight:
        return Alignment.bottomRight;
      case SparkOverlayPosition.bottomLeft:
        return Alignment.bottomLeft;
      case SparkOverlayPosition.topRight:
        return Alignment.topRight;
      case SparkOverlayPosition.topLeft:
        return Alignment.topLeft;
    }
  }
}

class _SparkBubble extends StatelessWidget {
  const _SparkBubble({
    required this.emotion,
    required this.animationState,
  });

  final SparkEmotion emotion;
  final SparkOverlayAnimationState animationState;

  @override
  Widget build(BuildContext context) {
    IconData sparkIcon;
    Color sparkColor;

    switch (emotion) {
      case SparkEmotion.happy:
        sparkIcon = Icons.sentiment_very_satisfied;
        sparkColor = const Color(0xFFFFD93D);
        break;
      case SparkEmotion.excited:
        sparkIcon = Icons.celebration;
        sparkColor = const Color(0xFFFF6B6B);
        break;
      case SparkEmotion.empathetic:
        sparkIcon = Icons.psychology;
        sparkColor = const Color(0xFF7B68EE);
        break;
      case SparkEmotion.teaching:
        sparkIcon = Icons.school;
        sparkColor = const Color(0xFF50C878);
        break;
      case SparkEmotion.neutral:
        sparkIcon = Icons.auto_awesome;
        sparkColor = const Color(0xFF4A90E2);
        break;
    }

    const double bubbleSize = 120;

    Widget sparkWidget = Container(
      width: bubbleSize,
      height: bubbleSize,
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
        size: bubbleSize * 0.6,
        color: Colors.white,
      ),
    );

    // Idle / breathing
    if (animationState == SparkOverlayAnimationState.idle &&
        emotion == SparkEmotion.neutral) {
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

    // Thinking pulse
    if (animationState == SparkOverlayAnimationState.thinking) {
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

    // Celebration pop
    if (animationState == SparkOverlayAnimationState.celebrating) {
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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: sparkWidget,
    );
  }
}

