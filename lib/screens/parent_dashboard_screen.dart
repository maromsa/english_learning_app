// lib/screens/parent_dashboard_screen.dart
//
// Parent Dashboard — rich view of child's learning progress.
//
// New in this version:
//   • Weekly activity bar chart (words practiced per day, 7 days).
//   • Weak words list (lowest mastery — needs more practice).
//   • Total session time estimate.
//   • Weekly new words count.

import 'dart:async';

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/parent_dashboard_stats.dart';
import 'package:english_learning_app/models/weekly_recap.dart';
import 'package:english_learning_app/providers/child_profile_provider.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/daily_streak_provider.dart';
import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/providers/word_bank_provider.dart';
import 'package:english_learning_app/screens/child_profile_selection_screen.dart';
import 'package:english_learning_app/services/parent_progress_service.dart';
import 'package:english_learning_app/services/weekly_recap_service.dart';
import 'package:english_learning_app/widgets/offline_downloads_card.dart';
import 'package:english_learning_app/widgets/weekly_recap_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({
    super.key,
    this.progressService,
    this.recapService,
  });

  final ParentProgressService? progressService;

  /// Overridable for tests.
  final WeeklyRecapService? recapService;

  static const Key vocabularyValueKey =
      ValueKey<String>('parent_dashboard_vocabulary');
  static const Key streakValueKey = ValueKey<String>('parent_dashboard_streak');
  static const Key coinsValueKey = ValueKey<String>('parent_dashboard_coins');

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

typedef _DashboardData = ({ParentDashboardStats stats, WeeklyRecap recap});

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  ParentProgressService? _progressService;
  WeeklyRecapService? _recapService;
  Future<_DashboardData>? _statsFuture;
  bool _startedLoad = false;

  @override
  void initState() {
    super.initState();
    _progressService = widget.progressService;
    _recapService = widget.recapService;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedLoad) return;
    _startedLoad = true;
    if (_hasDetailedDeps()) {
      _statsFuture = _loadStats();
    }
  }

  bool _hasDetailedDeps() {
    try {
      context.read<UserSessionProvider>();
      context.read<ChildProfileProvider>();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<_DashboardData> _loadStats() async {
    final session = context.read<UserSessionProvider>();
    final profileProvider = context.read<ChildProfileProvider>();
    final userId = session.currentUserId ?? profileProvider.activeProfileId;
    if (userId == null) {
      throw StateError(SparkStrings.parentDashboardNoUser);
    }

    final childName = profileProvider.activeProfile?.displayName ??
        session.currentUser?.name ??
        SparkStrings.parentDashboardDefaultChild;
    final lastPlayedAt = profileProvider.activeProfile?.lastPlayedAt;

    final progress = _progressService ??= ParentProgressService();
    final recapService = _recapService ??= WeeklyRecapService();

    final statsFuture = progress.loadStats(
      userId: userId,
      childName: childName,
      isLocalUser: true,
      lastPlayedAt: lastPlayedAt,
    );
    final recapFuture = recapService.loadRecap(userId: userId);

    return (stats: await statsFuture, recap: await recapFuture);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          SparkStrings.parentDashboardTitle,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_statsFuture != null)
            IconButton(
              tooltip: 'החלפת פרופיל',
              icon: const Icon(Icons.switch_account),
              onPressed: () {
                unawaited(
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChildProfileSelectionScreen(),
                    ),
                  ).then((_) {
                    setState(() => _statsFuture = _loadStats());
                  }),
                );
              },
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _LiveProgressStrip(),
          Expanded(child: _buildDetailedBody()),
        ],
      ),
    );
  }

  Widget _buildDetailedBody() {
    if (_statsFuture == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<_DashboardData>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(
            message: snapshot.error.toString(),
            onRetry: () => setState(() => _statsFuture = _loadStats()),
          );
        }
        final stats = snapshot.data!.stats;
        final recap = snapshot.data!.recap;
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _statsFuture = _loadStats());
            await _statsFuture;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _HeaderCard(stats: stats),
              const SizedBox(height: 20),

              // ── Weekly Recap ───────────────────────────────────────────
              WeeklyRecapCard(recap: recap),
              const SizedBox(height: 20),

              // ── Weekly Activity Chart ──────────────────────────────────
              const _SectionTitle(title: 'פעילות שבועית'),
              const SizedBox(height: 12),
              _WeeklyActivityChart(activity: stats.weeklyActivity),
              const SizedBox(height: 20),

              // ── Quick Stats ────────────────────────────────────────────
              const _SectionTitle(
                title: SparkStrings.parentDashboardOverview,
              ),
              const SizedBox(height: 12),
              _StatGrid(stats: stats),
              const SizedBox(height: 20),

              // ── Progress bars ──────────────────────────────────────────
              const _SectionTitle(
                title: SparkStrings.parentDashboardProgress,
              ),
              const SizedBox(height: 12),
              _ProgressCard(
                title: SparkStrings.parentDashboardWordsLabel,
                subtitle: SparkStrings.parentDashboardWordsSubtitle(
                  stats.wordsPracticed,
                  stats.totalWordsInCatalog,
                ),
                value: stats.wordsProgressRatio,
                trailing: stats.wordsMastered > 0
                    ? SparkStrings.parentDashboardMastered(
                        stats.wordsMastered,
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              _ProgressCard(
                title: SparkStrings.parentDashboardLevelsLabel,
                subtitle: SparkStrings.parentDashboardLevelsSubtitle(
                  stats.levelsCompleted,
                  stats.totalLevels,
                ),
                value: stats.levelsProgressRatio,
              ),
              const SizedBox(height: 12),
              _ProgressCard(
                title: SparkStrings.parentDashboardMissionsLabel,
                subtitle: SparkStrings.parentDashboardMissionsSubtitle(
                  stats.dailyMissionsCompleted,
                  stats.dailyMissionsTotal,
                ),
                value: stats.dailyMissionsTotal == 0
                    ? 0
                    : stats.dailyMissionsCompleted / stats.dailyMissionsTotal,
              ),
              const SizedBox(height: 20),

              // ── Weak Words ─────────────────────────────────────────────
              if (stats.weakWords.isNotEmpty) ...[
                const _SectionTitle(title: 'מילים לחיזוק'),
                const SizedBox(height: 12),
                _WeakWordsList(words: stats.weakWords),
                const SizedBox(height: 20),
              ],

              // ── Offline Downloads ──────────────────────────────────────
              const _SectionTitle(title: SparkStrings.offlineDownloadsTitle),
              const SizedBox(height: 12),
              OfflineDownloadsCard(
                userId: context.read<ChildProfileProvider>().activeProfileId ??
                    context.read<UserSessionProvider>().currentUserId ??
                    '',
              ),
              const SizedBox(height: 24),
              Text(
                SparkStrings.parentDashboardNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// Private widgets
// =============================================================================

class _LiveProgressStrip extends StatelessWidget {
  const _LiveProgressStrip();

  @override
  Widget build(BuildContext context) {
    final wordCount = context.watch<WordBankProvider>().count;
    final streakDays = context.watch<DailyStreakProvider>().currentStreak;
    final coins = context.watch<CoinProvider>().coins;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _LiveStatCard(
              icon: Icons.menu_book_outlined,
              color: Colors.teal.shade700,
              label: SparkStrings.parentDashboardLiveVocabulary,
              value: '$wordCount',
              valueKey: ParentDashboardScreen.vocabularyValueKey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _LiveStatCard(
              icon: Icons.local_fire_department_outlined,
              color: Colors.orange.shade800,
              label: SparkStrings.parentDashboardLiveStreak,
              value: SparkStrings.parentDashboardStreakDays(streakDays),
              valueKey: ParentDashboardScreen.streakValueKey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _LiveStatCard(
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.green.shade700,
              label: SparkStrings.parentDashboardLiveCoins,
              value: '$coins',
              valueKey: ParentDashboardScreen.coinsValueKey,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveStatCard extends StatelessWidget {
  const _LiveStatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              key: valueKey,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  final day = dateTime.day;
  final month = dateTime.month;
  final year = dateTime.year;
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.stats});
  final ParentDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final lastPlayed = stats.lastPlayedAt;
    final lastPlayedText = lastPlayed == null
        ? SparkStrings.parentDashboardLastPlayedUnknown
        : SparkStrings.parentDashboardLastPlayed(_formatDateTime(lastPlayed));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.deepPurple.shade100,
                  child: Icon(
                    Icons.family_restroom,
                    color: Colors.deepPurple.shade700,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stats.childName,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastPlayedText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (stats.totalSessionMinutes > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'סה"כ זמן למידה: ${stats.totalSessionMinutes} דקות',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly activity chart — pure Flutter, no external chart library.
// ---------------------------------------------------------------------------

class _WeeklyActivityChart extends StatelessWidget {
  const _WeeklyActivityChart({required this.activity});
  final List<DailyActivity> activity;

  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('אין נתוני פעילות עדיין.')),
        ),
      );
    }

    final maxWords = activity.fold<int>(1, (m, d) => d.words > m ? d.words : m);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'מילים שתורגלו (7 ימים)',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: activity.map((day) {
                  final fraction = maxWords == 0 ? 0.0 : day.words / maxWords;
                  final isToday = _isToday(day.date);
                  return _DayBar(
                    fraction: fraction,
                    label: day.shortDayLabel,
                    value: day.words,
                    isToday: isToday,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            if (activity.any((d) => d.words > 0))
              Text(
                'ממוצע: ${activity.where((d) => d.words > 0).map((d) => d.words).fold(0, (s, v) => s + v) ~/ activity.where((d) => d.words > 0).length} מילים ביום פעיל',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.fraction,
    required this.label,
    required this.value,
    required this.isToday,
  });

  final double fraction;
  final String label;
  final int value;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final barColor =
        isToday ? Colors.deepPurple.shade500 : Colors.deepPurple.shade200;
    final minHeight = value > 0 ? 8.0 : 2.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (value > 0)
          Text(
            '$value',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color:
                  isToday ? Colors.deepPurple.shade700 : Colors.grey.shade600,
            ),
          ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          width: 28,
          height: (fraction * 90).clamp(minHeight, 90),
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            color: isToday ? Colors.deepPurple.shade700 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stat grid (unchanged layout, extended content)
// ---------------------------------------------------------------------------

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});
  final ParentDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;
        final items = <_StatTileData>[
          _StatTileData(
            icon: Icons.star_rate,
            color: Colors.amber,
            label: SparkStrings.parentDashboardTotalStars,
            value: '${stats.totalStars}',
          ),
          _StatTileData(
            icon: Icons.local_fire_department,
            color: Colors.orange,
            label: SparkStrings.parentDashboardDailyStreak,
            value: '${stats.dailyStreak} ימים',
          ),
          _StatTileData(
            icon: Icons.menu_book,
            color: Colors.teal,
            label: SparkStrings.parentDashboardWordsPracticed,
            value: '${stats.wordsPracticed}',
          ),
          _StatTileData(
            icon: Icons.monetization_on,
            color: Colors.green,
            label: SparkStrings.parentDashboardCoins,
            value: '${stats.coins}',
          ),
          _StatTileData(
            icon: Icons.emoji_events,
            color: Colors.deepPurple,
            label: SparkStrings.parentDashboardAchievements,
            value: '${stats.achievementsUnlocked}/${stats.achievementsTotal}',
          ),
          _StatTileData(
            icon: Icons.auto_stories,
            color: Colors.blue,
            label: 'מילים חדשות השבוע',
            value: '${stats.weeklyNewWords}',
          ),
          _StatTileData(
            icon: Icons.today_rounded,
            color: Colors.redAccent,
            label: SparkStrings.parentDashboardWordsDueToday,
            value: '${stats.wordsDueToday}',
          ),
          _StatTileData(
            icon: Icons.trending_up_rounded,
            color: Colors.indigo,
            label: SparkStrings.parentDashboardLongestStreak,
            value: '${stats.longestSrsStreak}',
          ),
        ];

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: items.map((item) => _StatTile(data: item)).toList(),
        );
      },
    );
  }
}

class _StatTileData {
  const _StatTileData({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.data});
  final _StatTileData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(data.icon, color: data.color, size: 28),
            const SizedBox(height: 8),
            Text(
              data.value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              data.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress card (unchanged)
// ---------------------------------------------------------------------------

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.title,
    required this.subtitle,
    required this.value,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final double value;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                color: Colors.deepPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weak words list
// ---------------------------------------------------------------------------

class _WeakWordsList extends StatelessWidget {
  const _WeakWordsList({required this.words});
  final List<WeakWord> words;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.shade100),
      ),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fitness_center,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'המילים האלה צריכות עוד תרגול:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...words.map((w) => _WeakWordRow(word: w)),
          ],
        ),
      ),
    );
  }
}

class _WeakWordRow extends StatelessWidget {
  const _WeakWordRow({required this.word});
  final WeakWord word;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.word,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  word.levelName,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${word.masteryPercent}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: word.masteryLevel.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.orange.shade100,
                    color: Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state (unchanged)
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text(SparkStrings.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
