import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/leaderboard_entry.dart';
import 'package:english_learning_app/providers/child_profile_provider.dart';
import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/services/leaderboard_service.dart';
import 'package:english_learning_app/utils/list_performance.dart';
import 'package:english_learning_app/widgets/ui/_barrel.dart';
import 'package:english_learning_app/widgets/ui/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    LeaderboardService? leaderboardService,
  }) : _leaderboardService = leaderboardService;

  final LeaderboardService? _leaderboardService;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final LeaderboardService _service;
  bool _loading = true;
  String? _errorMessage;
  LeaderboardResult? _result;

  @override
  void initState() {
    super.initState();
    _service = widget._leaderboardService ?? LeaderboardService();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final profileProvider = context.read<ChildProfileProvider>();
    final session = context.read<UserSessionProvider>();
    final currentId = profileProvider.activeProfileId ?? session.currentUserId;

    try {
      final result = await _service.fetchLeaderboard(
        currentProfileId: currentId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = SparkStrings.leaderboardLoadFailed;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF8E1),
              Color(0xFFE8F5E9),
              Color(0xFFE3F2FD),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _LeaderboardHeader(onBack: () => Navigator.pop(context)),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFFFB300)),
            SizedBox(height: 16),
            Text(
              SparkStrings.leaderboardLoading,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5D4037),
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: Colors.orange),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              KidButton.warning(
                label: SparkStrings.tryAgain,
                onPressed: _loadLeaderboard,
              ),
            ],
          ),
        ),
      );
    }

    final entries = _result?.entries ?? [];
    if (entries.isEmpty) {
      return _LeaderboardEmptyState(onRefresh: _loadLeaderboard);
    }

    final currentOutsideList = _result?.currentUserEntry != null &&
        !entries.any((e) => e.isCurrentUser);

    final listEntries =
        entries.length >= 3 ? entries.skip(3).toList(growable: false) : entries;
    final headerCount = entries.length >= 3 ? 1 : 0;
    final footerCount =
        currentOutsideList && _result!.currentUserEntry != null ? 1 : 0;
    final itemCount = headerCount + listEntries.length + footerCount;

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      child: ListView.builder(
        cacheExtent: ListPerformance.defaultCacheExtent,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (entries.length >= 3 && index == 0) {
            return _PodiumRow(
                topThree: entries.take(3).toList(growable: false));
          }

          final listIndex = index - headerCount;
          if (listIndex >= 0 && listIndex < listEntries.length) {
            return _LeaderboardTile(entry: listEntries[listIndex]);
          }

          if (footerCount == 1 && index == itemCount - 1) {
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _YourRankBanner(entry: _result!.currentUserEntry!),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _LeaderboardHeader extends StatelessWidget {
  const _LeaderboardHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon:
                const Icon(Icons.arrow_back_rounded, color: Color(0xFF5D4037)),
            onPressed: onBack,
          ),
          const Icon(Icons.emoji_events, color: Color(0xFFFFB300), size: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SparkStrings.leaderboardTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF5D4037),
                      ),
                ),
                Text(
                  SparkStrings.leaderboardSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8D6E63),
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

class _PodiumRow extends StatelessWidget {
  const _PodiumRow({required this.topThree});

  final List<LeaderboardEntry> topThree;

  @override
  Widget build(BuildContext context) {
    final first = topThree[0];
    final second = topThree.length > 1 ? topThree[1] : null;
    final third = topThree.length > 2 ? topThree[2] : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: second != null
                ? _PodiumPlace(
                    entry: second, medal: LeaderboardMedal.silver, height: 88)
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: _PodiumPlace(
                entry: first, medal: LeaderboardMedal.gold, height: 110),
          ),
          Expanded(
            child: third != null
                ? _PodiumPlace(
                    entry: third, medal: LeaderboardMedal.bronze, height: 72)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

enum LeaderboardMedal { gold, silver, bronze }

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({
    required this.entry,
    required this.medal,
    required this.height,
  });

  final LeaderboardEntry entry;
  final LeaderboardMedal medal;
  final double height;

  @override
  Widget build(BuildContext context) {
    final medalData = _medalStyle(medal);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(medalData.emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        _AvatarBubble(entry: entry, radius: 26, highlight: entry.isCurrentUser),
        const SizedBox(height: 4),
        Text(
          entry.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: entry.isCurrentUser
                ? const Color(0xFF6A1B9A)
                : const Color(0xFF5D4037),
          ),
        ),
        Text(
          '🪙 ${entry.totalCoins}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: medalData.color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            boxShadow: [
              BoxShadow(
                color: medalData.color.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '${entry.rank}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  ({String emoji, Color color}) _medalStyle(LeaderboardMedal medal) {
    switch (medal) {
      case LeaderboardMedal.gold:
        return (emoji: '🥇', color: const Color(0xFFFFC107));
      case LeaderboardMedal.silver:
        return (emoji: '🥈', color: const Color(0xFFB0BEC5));
      case LeaderboardMedal.bronze:
        return (emoji: '🥉', color: const Color(0xFFCD7F32));
    }
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final medal = _rankMedal(entry.rank);
    final isYou = entry.isCurrentUser;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isYou ? const Color(0xFFFFF9C4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isYou ? const Color(0xFFFFB300) : Colors.grey.shade200,
          width: isYou ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              child: Text(
                medal ?? '#${entry.rank}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: medal != null ? 22 : 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF5D4037),
                ),
              ),
            ),
            _AvatarBubble(entry: entry, radius: 22, highlight: isYou),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color:
                      isYou ? const Color(0xFF6A1B9A) : const Color(0xFF37474F),
                ),
              ),
            ),
            if (isYou)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  SparkStrings.leaderboardYouBadge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${SparkStrings.leaderboardStreakLabel} ${entry.currentStreak} 🔥',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🪙', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 4),
            Text(
              '${entry.totalCoins}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFF8F00),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _rankMedal(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return null;
    }
  }
}

class _YourRankBanner extends StatelessWidget {
  const _YourRankBanner({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _AvatarBubble(entry: entry, radius: 24, highlight: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  SparkStrings.leaderboardYourRank,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                Text(
                  SparkStrings.leaderboardYourRankDetail(
                    entry.rank,
                    entry.totalCoins,
                    entry.currentStreak,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardEmptyState extends StatelessWidget {
  const _LeaderboardEmptyState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              SparkStrings.leaderboardEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5D4037),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              SparkStrings.leaderboardEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8D6E63)),
            ),
            const SizedBox(height: 24),
            KidButton.primary(
              label: SparkStrings.tryAgain,
              onPressed: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({
    required this.entry,
    required this.radius,
    this.highlight = false,
  });

  final LeaderboardEntry entry;
  final double radius;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Color(entry.avatarColor),
      backgroundImage:
          entry.avatarUrl != null ? NetworkImage(entry.avatarUrl!) : null,
      child: entry.avatarUrl == null
          ? Text(
              entry.displayName.isNotEmpty
                  ? entry.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: radius * 0.9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}
