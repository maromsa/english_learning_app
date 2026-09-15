import 'package:english_learning_app/utils/aurora_tokens.dart';
import 'package:flutter/material.dart';

/// Compact 🔥 streak pill for the map HUD and practice screen.
///
/// Lights up with a warm background when [streakCount] is positive, and
/// plays a short bounce when the count updates (unless animations are
/// disabled).
class StreakBadge extends StatefulWidget {
  const StreakBadge({super.key, required this.streakCount});

  /// Consecutive practice days in the current streak.
  final int streakCount;

  /// Lit-flame colour for an active streak.
  static const Color activeColor = Color(0xFFFF5722);

  /// Warm fill behind an active flame.
  static const Color warmBackground = Color(0xFFFFF3E0);

  /// Muted fill when there is no active streak.
  static const Color inactiveBackground = Color(0xFFF5F5F5);

  /// Length of the bounce played when [streakCount] changes.
  static const Duration bounceDuration = Duration(milliseconds: 320);

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: StreakBadge.bounceDuration,
    );
    _bounce = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.16)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.16, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(_bounceController);
  }

  @override
  void didUpdateWidget(covariant StreakBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streakCount != widget.streakCount) {
      _playBounce();
    }
  }

  void _playBounce() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _bounceController.forward(from: 0);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool active = widget.streakCount > 0;
    final Color accent =
        active ? StreakBadge.activeColor : Colors.grey.shade500;
    final Color background =
        active ? StreakBadge.warmBackground : StreakBadge.inactiveBackground;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'רצף יומי: ${widget.streakCount}',
      child: ScaleTransition(
        key: const ValueKey<String>('streak-badge-scale'),
        scale: _bounce,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AuroraTokens.rPill),
              border: Border.all(
                color: active
                    ? StreakBadge.activeColor.withValues(alpha: 0.28)
                    : Colors.grey.shade400.withValues(alpha: 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: (active ? StreakBadge.activeColor : Colors.black)
                      .withValues(alpha: active ? 0.22 : 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department, color: accent, size: 20),
                const SizedBox(width: 6),
                Text(
                  '${widget.streakCount}',
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: active ? accent : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
