// lib/screens/achievements_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:english_learning_app/models/achievement.dart';
import 'package:english_learning_app/services/achievement_service.dart';
import 'package:english_learning_app/widgets/ui/glass_card.dart';

/// The Trophy Room: scrollable grid of achievements.
/// Unlocked = colorful; locked = grayscale with lock icon.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('הישגים'),
      ),
      body: Consumer<AchievementService>(
        builder: (context, achievementService, _) {
          final achievements = achievementService.achievements;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final achievement = achievements[index];
                      return _AchievementCard(achievement: achievement);
                    },
                    childCount: achievements.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnlocked = achievement.isUnlocked;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon: full color when unlocked, grayscale when locked
          Icon(
            achievement.icon,
            size: 48,
            color: isUnlocked
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          if (!isUnlocked) ...[
            const SizedBox(height: 4),
            Icon(
              Icons.lock,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isUnlocked
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            achievement.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isUnlocked
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (achievement.requirementValue != null && !isUnlocked) ...[
            const SizedBox(height: 4),
            Text(
              '${achievement.requirementValue}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
