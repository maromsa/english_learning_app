import 'package:flutter/material.dart';

import '../l10n/spark_strings.dart';
import '../models/parent_dashboard_stats.dart';
import '../models/weekly_recap.dart';

/// Parent Dashboard summary of the child's last 7 days — active practice days,
/// words practised, practice minutes, coins earned, best day, and words taken
/// to mastery this week. Pure presentation: [recap] is computed by
/// `WeeklyRecapService`.
class WeeklyRecapCard extends StatelessWidget {
  const WeeklyRecapCard({super.key, required this.recap});

  final WeeklyRecap recap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6A5AE0), Color(0xFF8B7BF0)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A5AE0).withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Text(
                SparkStrings.weeklyRecapTitle,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              Text(
                SparkStrings.weeklyRecapSubtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (recap.isEmpty)
            const _EmptyState()
          else ...[
            Row(
              children: [
                Expanded(
                  child: _RecapTile(
                    icon: Icons.event_available_rounded,
                    value: '${recap.activeDays}/7',
                    label: SparkStrings.weeklyRecapActiveDays(recap.activeDays),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RecapTile(
                    icon: Icons.menu_book_rounded,
                    value: '${recap.wordsPracticed}',
                    label: SparkStrings.weeklyRecapWords,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _RecapTile(
                    icon: Icons.timer_rounded,
                    value: '${recap.minutesPracticed}',
                    label: SparkStrings.weeklyRecapMinutes,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RecapTile(
                    icon: Icons.monetization_on_rounded,
                    value: '${recap.coinsEarned}',
                    label: SparkStrings.weeklyRecapCoins,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Sparkline(days: recap.days),
            if (recap.bestDay != null) ...[
              const SizedBox(height: 12),
              _RecapNote(
                SparkStrings.weeklyRecapBestDay(
                  recap.bestDay!.shortDayLabel,
                  recap.bestDay!.words,
                ),
              ),
            ],
            if (recap.wordsMasteredThisWeek > 0) ...[
              const SizedBox(height: 8),
              _RecapNote(
                SparkStrings.weeklyRecapMastered(recap.wordsMasteredThisWeek),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RecapTile extends StatelessWidget {
  const _RecapTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapNote extends StatelessWidget {
  const _RecapNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.95),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.days});
  final List<DailyActivity> days;

  @override
  Widget build(BuildContext context) {
    final maxWords = days.fold<int>(1, (m, d) => d.words > m ? d.words : m);
    return SizedBox(
      height: 58,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final day in days)
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 20,
                  height: (day.words / maxWords * 36).clamp(3, 36).toDouble(),
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withValues(alpha: day.words > 0 ? 0.9 : 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  day.shortDayLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text(
        SparkStrings.weeklyRecapEmpty,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
