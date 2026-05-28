import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/parent_dashboard_stats.dart';
import 'package:english_learning_app/providers/child_profile_provider.dart';
import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/screens/child_profile_selection_screen.dart';
import 'package:english_learning_app/services/parent_progress_service.dart';
import 'package:english_learning_app/widgets/offline_downloads_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({
    super.key,
    this.progressService,
  });

  final ParentProgressService? progressService;

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  late final ParentProgressService _progressService;
  Future<ParentDashboardStats>? _statsFuture;
  bool _startedLoad = false;

  @override
  void initState() {
    super.initState();
    _progressService = widget.progressService ?? ParentProgressService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_startedLoad) {
      _startedLoad = true;
      _statsFuture = _loadStats();
    }
  }

  Future<ParentDashboardStats> _loadStats() async {
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

    return _progressService.loadStats(
      userId: userId,
      childName: childName,
      isLocalUser: true,
      lastPlayedAt: lastPlayedAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          SparkStrings.parentDashboardTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'החלפת פרופיל',
            icon: const Icon(Icons.switch_account),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChildProfileSelectionScreen(),
                ),
              ).then((_) {
                setState(() {
                  _statsFuture = _loadStats();
                });
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<ParentDashboardStats>(
        future: _statsFuture ??= _loadStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onRetry: () {
                setState(() {
                  _statsFuture = _loadStats();
                });
              },
            );
          }
          final stats = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _statsFuture = _loadStats();
              });
              await _statsFuture;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeaderCard(stats: stats),
                const SizedBox(height: 20),
                Text(
                  SparkStrings.parentDashboardOverview,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                _StatGrid(stats: stats),
                const SizedBox(height: 20),
                Text(
                  SparkStrings.parentDashboardProgress,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                      ? SparkStrings.parentDashboardMastered(stats.wordsMastered)
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
                const SizedBox(height: 24),
                Text(
                  SparkStrings.offlineDownloadsTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
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
      ),
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
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
          ],
        ),
      ),
    );
  }
}

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
            value: '${stats.dailyStreak}',
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
            value:
                '${stats.achievementsUnlocked}/${stats.achievementsTotal}',
          ),
          _StatTileData(
            icon: Icons.check_circle,
            color: Colors.blue,
            label: SparkStrings.parentDashboardLevelsDone,
            value: '${stats.levelsCompleted}',
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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

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
              child: Text(SparkStrings.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
