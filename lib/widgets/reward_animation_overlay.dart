import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Plays a one-shot Lottie reward animation (confetti, coins, etc.).
///
/// Missing or unreadable assets fail closed: [errorBuilder] returns an empty
/// box so tests and early development can run before the JSON files land.
class RewardAnimationOverlay extends StatefulWidget {
  const RewardAnimationOverlay({
    super.key,
    required this.animationPath,
    this.onComplete,
  });

  /// Asset key, e.g. `assets/animations/confetti.json`.
  final String animationPath;

  /// Fired once the controller reaches [AnimationStatus.completed].
  final VoidCallback? onComplete;

  /// Marker on the [SizedBox.shrink] fallback when the asset cannot load.
  static const Key fallbackKey = Key('reward-animation-fallback');

  @override
  State<RewardAnimationOverlay> createState() => _RewardAnimationOverlayState();
}

class _RewardAnimationOverlayState extends State<RewardAnimationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      widget.onComplete?.call();
    }
  }

  void _onLoaded(LottieComposition composition) {
    if (!mounted) return;
    _controller.duration = composition.duration;
    unawaited(_controller.forward());
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      widget.animationPath,
      controller: _controller,
      repeat: false,
      fit: BoxFit.contain,
      onLoaded: _onLoaded,
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
          'RewardAnimationOverlay: failed to load ${widget.animationPath}: $error',
        );
        return const SizedBox.shrink(key: RewardAnimationOverlay.fallbackKey);
      },
    );
  }
}
