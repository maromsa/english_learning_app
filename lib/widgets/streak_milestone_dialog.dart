import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:english_learning_app/utils/aurora_tokens.dart';
import 'package:english_learning_app/widgets/reward_animation_overlay.dart';
import 'package:english_learning_app/widgets/streak_badge.dart';
import 'package:english_learning_app/widgets/ui/kid_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Celebratory popup when a practice-streak milestone (day 3 / 7 / 14)
/// unlocks bonus coins.
class StreakMilestoneDialog extends StatelessWidget {
  const StreakMilestoneDialog({
    super.key,
    required this.day,
    required this.coins,
  });

  /// Consecutive practice days that unlocked this reward.
  final int day;

  /// Bonus coins granted for this milestone.
  final int coins;

  static const Key dialogKey = Key('streak-milestone-dialog');
  static const Key fireIconKey = Key('streak-milestone-fire');
  static const Key rewardAnimationKey =
      Key('streak-milestone-reward-animation');

  /// Placeholder Lottie asset. [RewardAnimationOverlay] fails closed if the
  /// JSON is not on disk yet.
  static const String rewardAnimationAsset = 'assets/animations/confetti.json';

  static Future<void> show(
    BuildContext context, {
    required int day,
    required int coins,
  }) {
    SoundService().playSuccessSound();
    SoundService().playCoinSound();
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => StreakMilestoneDialog(day: day, coins: coins),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: dialogKey,
      backgroundColor: AuroraTokens.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuroraTokens.rXl),
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AuroraTokens.s12,
              AuroraTokens.s16,
              AuroraTokens.s12,
              AuroraTokens.s12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  key: fireIconKey,
                  color: StreakBadge.activeColor,
                  size: 64,
                ),
                const SizedBox(height: AuroraTokens.s8),
                Text(
                  SparkStrings.streakMilestoneTitle(day),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AuroraTokens.ink,
                  ),
                ),
                const SizedBox(height: AuroraTokens.s4),
                Text(
                  SparkStrings.streakMilestoneCoins(coins),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AuroraTokens.coral,
                  ),
                ),
                const SizedBox(height: AuroraTokens.s12),
                KidButton.success(
                  label: SparkStrings.streakMilestoneCta,
                  onPressed: () => Navigator.of(context).pop(),
                  fullWidth: true,
                ),
              ],
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: RewardAnimationOverlay(
                key: rewardAnimationKey,
                animationPath: rewardAnimationAsset,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
