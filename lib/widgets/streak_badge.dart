import 'package:flutter/material.dart';

/// A small pill badge showing the child's current daily streak (🔥), styled
/// to sit next to the coin counter on the practice screen.
///
/// The streak value comes from `DailyRewardService.getCurrentStreak()` — the
/// same source the parent dashboard reads.
///
/// When [streak] is 0 the badge renders grey (no active streak); any positive
/// streak lights the flame up in vibrant orange-red.
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.streak});

  /// Number of consecutive days the child has kept the streak going.
  final int streak;

  /// Lit-flame colour for an active streak.
  static const Color activeColor = Color(0xFFFF5722);

  @override
  Widget build(BuildContext context) {
    final bool active = streak > 0;
    final Color accent = active ? activeColor : Colors.grey.shade500;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'רצף יומי: $streak',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
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
              '$streak',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: active ? accent : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
