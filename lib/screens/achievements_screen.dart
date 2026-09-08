// lib/screens/achievements_screen.dart
//
// Achievements Showcase — the "Trophy Room".
//
// Audience: children aged 4–8, most of whom cannot read yet (Hebrew or English).
// The screen therefore leans on ICONS, COLOUR and SIZE rather than text:
//
//   * Unlocked -> big, vibrant, category-coloured medal + gold ring + check badge
//   * Locked   -> flat grey disc with a faded padlock; nothing to read
//
// Digits ("7 / 28") are kept — numbers are understood far earlier than words.
// All prose (titles, descriptions) lives in the tap-to-open detail sheet, where
// a grown-up can read it aloud; it never clutters the grid.

import 'package:english_learning_app/models/achievement.dart';
import 'package:english_learning_app/screens/collection_screen.dart';
import 'package:english_learning_app/services/achievement_service.dart';
import 'package:english_learning_app/utils/page_transitions.dart';
import 'package:english_learning_app/widgets/ui/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('🏆', style: TextStyle(fontSize: 30)),
        actions: [
          IconButton(
            tooltip: 'ספר האוסף',
            icon: const Icon(Icons.collections_bookmark_rounded),
            onPressed: () {
              Navigator.push(
                context,
                PageTransitions.slideFromRight(const CollectionScreen()),
              );
            },
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF6E5), Color(0xFFFDE9F3), Color(0xFFE8F1FF)],
          ),
        ),
        child: SafeArea(
          child: Consumer<AchievementService>(
            builder: (context, service, _) {
              final byCategory = service.byCategory;
              final unlocked = service.unlockedCount;
              final total = service.totalCount;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _TrophyHero(unlocked: unlocked, total: total),
                  ),
                  for (final category in AchievementCategory.values)
                    if (byCategory[category]?.isNotEmpty == true) ...[
                      SliverToBoxAdapter(
                        child: _CategoryBanner(
                          category: category,
                          items: byCategory[category]!,
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.78,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = byCategory[category]![index];
                              return _MedalTile(
                                achievement: item,
                                progress: service.progressToward(item.id) ?? 0,
                              );
                            },
                            childCount: byCategory[category]!.length,
                          ),
                        ),
                      ),
                    ],
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category theming
// ---------------------------------------------------------------------------

class _CatTheme {
  const _CatTheme(this.emoji, this.color);
  final String emoji;
  final Color color;
}

_CatTheme _categoryTheme(AchievementCategory cat) {
  switch (cat) {
    case AchievementCategory.firstSteps:
      return const _CatTheme('🌱', Color(0xFF43A047));
    case AchievementCategory.learning:
      return const _CatTheme('📚', Color(0xFF1E88E5));
    case AchievementCategory.streak:
      return const _CatTheme('🔥', Color(0xFFF4511E));
    case AchievementCategory.pronunciation:
      return const _CatTheme('🎤', Color(0xFF8E24AA));
    case AchievementCategory.explorer:
      return const _CatTheme('🔭', Color(0xFF00897B));
    case AchievementCategory.collector:
      return const _CatTheme('💰', Color(0xFFF9A825));
    case AchievementCategory.dedication:
      return const _CatTheme('⭐', Color(0xFFE53935));
  }
}

// ---------------------------------------------------------------------------
// Hero — giant medal counter
// ---------------------------------------------------------------------------

/// Static progress ring — no animation controller, so `pumpAndSettle` in
/// widget tests always terminates (unlike [CircularProgressIndicator]).
class _RingPainter extends CustomPainter {
  const _RingPainter(
    this.ratio, {
    this.trackColor = const Color(0x99FFFFFF), // white @ 60%
    this.progressColor = const Color(0xFFFFB300), // reward gold
    this.stroke = 12.0,
  });

  final double ratio;
  final Color trackColor;
  final Color progressColor;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (ratio > 0) {
      final progress = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = progressColor;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.5707963267948966, // -pi/2, start at 12 o'clock
        6.283185307179586 * ratio.clamp(0.0, 1.0),
        false,
        progress,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.ratio != ratio ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.stroke != stroke;
}

class _TrophyHero extends StatelessWidget {
  const _TrophyHero({required this.unlocked, required this.total});

  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : unlocked / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: GlassCard(
        borderRadius: 28,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(132, 132),
                    painter: _RingPainter(ratio),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 34)),
                      Text(
                        '$unlocked / $total',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF5D4037),
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // One dot per medal — filled = earned. Pure visual progress bar.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < total; i++)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < unlocked
                          ? const Color(0xFFFFB300)
                          : Colors.white.withValues(alpha: 0.7),
                      border: Border.all(
                        color: const Color(0xFFFFB300),
                        width: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category banner — big emoji + numeric progress, no prose needed
// ---------------------------------------------------------------------------

class _CategoryBanner extends StatelessWidget {
  const _CategoryBanner({required this.category, required this.items});

  final AchievementCategory category;
  final List<Achievement> items;

  @override
  Widget build(BuildContext context) {
    final t = _categoryTheme(category);
    final earned = items.where((a) => a.isUnlocked).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: t.color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Text(t.emoji, style: const TextStyle(fontSize: 24)),
            const Spacer(),
            Text(
              '$earned / ${items.length}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: t.color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Medal tile
// ---------------------------------------------------------------------------

class _MedalTile extends StatelessWidget {
  const _MedalTile({required this.achievement, this.progress = 0});

  final Achievement achievement;

  /// Fraction (0.0–1.0) toward unlocking — only meaningful while locked.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.isUnlocked;
    final t = _categoryTheme(achievement.category);

    return Semantics(
      label: unlocked
          ? 'הישג פתוח: ${achievement.title}'
          : progress > 0
              ? 'הישג נעול, ${(progress * 100).round()} אחוז'
              : 'הישג נעול',
      button: true,
      child: GestureDetector(
        key: Key('achievement_${achievement.id}'),
        onTap: () => _showDetail(context, achievement, t.color),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: unlocked
                    ? _UnlockedMedal(icon: achievement.icon, color: t.color)
                    : _LockedMedal(progress: progress),
              ),
            ),
            const SizedBox(height: 6),
            if (unlocked)
              Text(
                achievement.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4E342E),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnlockedMedal extends StatelessWidget {
  const _UnlockedMedal({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Gold ring
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Color(0xFFFFE082),
                Color(0xFFFFB300),
                Color(0xFFFFE082),
                Color(0xFFFFB300),
                Color(0xFFFFE082),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        // Coloured medal face
        Padding(
          padding: const EdgeInsets.all(6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(color, Colors.white, 0.35)!, color],
              ),
            ),
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 0.5,
                child: FittedBox(
                  child: Icon(icon, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        // Shine highlight
        Align(
          alignment: const Alignment(-0.35, -0.45),
          child: FractionallySizedBox(
            widthFactor: 0.16,
            heightFactor: 0.16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
        // Check badge
        Align(
          alignment: Alignment.bottomRight,
          child: FractionallySizedBox(
            widthFactor: 0.34,
            heightFactor: 0.34,
            child: FittedBox(
              child: Icon(Icons.verified_rounded, color: Colors.green.shade600),
            ),
          ),
        ),
      ],
    );
  }
}

class _LockedMedal extends StatelessWidget {
  const _LockedMedal({this.progress = 0});

  /// Fraction (0.0–1.0) toward unlocking. `0` renders a plain grey disc (no
  /// "you haven't started" nag); any positive value draws an encouraging ring
  /// around the padlock so kids can see how close they are.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final hasProgress = progress > 0;

    final disc = Stack(
      alignment: Alignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.06),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.12),
              width: 3,
            ),
          ),
          child: const SizedBox.expand(),
        ),
        FractionallySizedBox(
          widthFactor: 0.4,
          heightFactor: 0.4,
          child: FittedBox(
            child: Icon(
              Icons.lock_rounded,
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
        ),
      ],
    );

    if (!hasProgress) return disc;

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _RingPainter(
              progress,
              // Very light grey track, soft gold fill — same "reward" hue as
              // the hero ring and medal faces, just gentler for a not-yet prize.
              trackColor: const Color(0x11000000),
              progressColor: const Color(0xFFFFCA28),
              stroke: 6,
            ),
          ),
        ),
        // Inset the disc so the ring reads as a frame around it.
        FractionallySizedBox(
          widthFactor: 0.78,
          heightFactor: 0.78,
          child: disc,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Detail sheet — where the words are allowed to live
// ---------------------------------------------------------------------------

void _showDetail(BuildContext context, Achievement a, Color color) {
  final unlocked = a.isUnlocked;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: unlocked
                ? _UnlockedMedal(icon: a.icon, color: color)
                : const _LockedMedal(),
          ),
          const SizedBox(height: 20),
          Text(
            unlocked ? a.title : 'עדיין נעול 🔒',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            a.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: unlocked ? 0.8 : 0.5),
                ),
          ),
          if (a.coinReward > 0) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.monetization_on_rounded,
                  color: unlocked ? Colors.amber : Colors.grey,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text(
                  '+${a.coinReward}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: unlocked ? Colors.amber.shade800 : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
