// lib/screens/achievements_screen.dart
//
// Trophy Room — shows all 28 achievements grouped by category.
// Unlocked = colorful card; Locked = grayscale + lock icon.

import 'package:english_learning_app/models/achievement.dart';
import 'package:english_learning_app/services/achievement_service.dart';
import 'package:english_learning_app/screens/collection_screen.dart';
import 'package:english_learning_app/utils/page_transitions.dart';
import 'package:english_learning_app/widgets/ui/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('הישגים'),
        actions: [
          IconButton(
            tooltip: 'ספר האוסף',
            icon: const Icon(Icons.collections_bookmark_outlined),
            onPressed: () {
              Navigator.push(
                context,
                PageTransitions.slideFromRight(const CollectionScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<AchievementService>(
        builder: (context, service, _) {
          final byCategory = service.byCategory;
          final unlocked = service.unlockedCount;
          final total = service.totalCount;

          return CustomScrollView(
            slivers: [
              // Progress header
              SliverToBoxAdapter(
                child: _ProgressHeader(unlocked: unlocked, total: total),
              ),

              // Categories
              for (final category in AchievementCategory.values) ...[
                if (byCategory[category]?.isNotEmpty == true) ...[
                  SliverToBoxAdapter(
                    child: _CategoryHeader(category: category),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final achievement =
                              byCategory[category]![index];
                          return _AchievementCard(
                              achievement: achievement);
                        },
                        childCount: byCategory[category]!.length,
                      ),
                    ),
                  ),
                ],
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.unlocked, required this.total});
  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : unlocked / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
              const SizedBox(width: 10),
              Text(
                '$unlocked / $total הישגים',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              color: Colors.amber.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});
  final AchievementCategory category;

  static const _labels = {
    AchievementCategory.firstSteps: ('🌱', 'צעדים ראשונים'),
    AchievementCategory.learning: ('📚', 'למידה'),
    AchievementCategory.streak: ('🔥', 'רצפים'),
    AchievementCategory.pronunciation: ('🎤', 'הגייה'),
    AchievementCategory.explorer: ('🔭', 'חקירה'),
    AchievementCategory.collector: ('💰', 'אוסף'),
    AchievementCategory.dedication: ('🏆', 'מסירות'),
  };

  @override
  Widget build(BuildContext context) {
    final (emoji, label) = _labels[category] ?? ('⭐', category.name);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        '$emoji  $label',
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
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

    final iconColor = isUnlocked
        ? _categoryColor(achievement.category)
        : theme.colorScheme.onSurface.withValues(alpha: 0.3);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? _categoryColor(achievement.category).withValues(alpha: 0.12)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(achievement.icon, size: 36, color: iconColor),
              ),
              if (!isUnlocked)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock, size: 12, color: Colors.white),
                ),
              if (isUnlocked && achievement.coinReward > 0)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star, size: 12, color: Colors.white),
                ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            achievement.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: isUnlocked
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            achievement.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: isUnlocked
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.75)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),

          if (achievement.coinReward > 0 && isUnlocked) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on,
                    size: 12, color: Colors.amber),
                const SizedBox(width: 3),
                Text(
                  '+${achievement.coinReward}',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _categoryColor(AchievementCategory cat) {
    switch (cat) {
      case AchievementCategory.firstSteps:
        return Colors.green;
      case AchievementCategory.learning:
        return Colors.blue;
      case AchievementCategory.streak:
        return Colors.orange;
      case AchievementCategory.pronunciation:
        return Colors.purple;
      case AchievementCategory.explorer:
        return Colors.teal;
      case AchievementCategory.collector:
        return Colors.amber.shade700;
      case AchievementCategory.dedication:
        return Colors.red;
    }
  }
}
