import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_mission.dart';
import '../providers/coin_provider.dart';
import '../providers/daily_mission_provider.dart';

class DailyMissionsScreen extends StatelessWidget {
  const DailyMissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('משימות הבזק היומיות'),
        backgroundColor: Colors.indigo.shade400,
      ),
      body: Consumer<DailyMissionProvider>(
        builder: (context, missionsProvider, _) {
          if (!missionsProvider.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          final missions = missionsProvider.missions;
          if (missions.isEmpty) {
            return _EmptyState(onRefresh: missionsProvider.refreshMissions);
          }

          final completedCount = missions
              .where((mission) => mission.isCompleted)
              .length;
          final claimableRewards = missions
              .where((mission) => mission.isClaimable)
              .fold<int>(0, (sum, mission) => sum + mission.reward);

          return RefreshIndicator(
            onRefresh: missionsProvider.refreshMissions,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SummaryHeader(
                  completedCount: completedCount,
                  totalCount: missions.length,
                  claimableRewards: claimableRewards,
                ),
                const SizedBox(height: 16),
                ...missions
                    .map((mission) => _MissionCard(mission: mission))
                    .toList(growable: false),
                const SizedBox(height: 24),
                _TipsSection(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.completedCount,
    required this.totalCount,
    required this.claimableRewards,
  });

  final int completedCount;
  final int totalCount;
  final int claimableRewards;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: const Color(0xFFEEF1FF),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade500,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'המסע של היום',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SummaryChip(
                  icon: Icons.check_circle_outline,
                  label: 'הושלמו',
                  value: '$completedCount/$totalCount',
                  color: Colors.green,
                ),
                _SummaryChip(
                  icon: Icons.card_giftcard,
                  label: 'פרסים זמינים',
                  value: claimableRewards > 0 ? '+$claimableRewards' : '0',
                  color: claimableRewards > 0 ? Colors.orange : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'שחקו, דברו והקשיבו כדי לפתוח את כל הבונוסים של היום!',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission});

  final DailyMission mission;

  Color _badgeColor() {
    if (mission.isClaimable) {
      return Colors.amber.shade600;
    }
    if (mission.isCompleted) {
      return Colors.green.shade600;
    }
    return Colors.blue.shade400;
  }

  IconData _badgeIcon() {
    if (mission.isClaimable) {
      return Icons.redeem;
    }
    if (mission.isCompleted) {
      return Icons.check_circle_rounded;
    }
    return Icons.bolt_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final progressPercent = mission.completionRatio;
    final coins = mission.reward;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _badgeColor().withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_badgeIcon(), color: _badgeColor()),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mission.description,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                minHeight: 12,
                value: progressPercent,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(_badgeColor()),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${mission.progress}/${mission.target}',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.monetization_on, color: Colors.amber.shade600),
                    const SizedBox(width: 4),
                    Text('+$coins'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: mission.isClaimable
                    ? FilledButton.icon(
                        key: const ValueKey('claimable'),
                        onPressed: () async {
                          final missionsProvider = context
                              .read<DailyMissionProvider>();
                          final coinProvider = context.read<CoinProvider>();
                          final success = await missionsProvider.claimReward(
                            mission.id,
                            (reward) => coinProvider.addCoins(reward),
                          );
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '🎉 משימה הושלמה! קיבלתם $coins מטבעות.',
                                ),
                                backgroundColor: Colors.green.shade600,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.card_giftcard),
                        label: const Text('אספו פרס'),
                      )
                    : OutlinedButton.icon(
                        key: const ValueKey('keep-going'),
                        icon: const Icon(Icons.play_arrow_rounded),
                        onPressed: () =>
                            _navigateToMission(context, mission.type),
                        label: const Text('קדימה לתרגול'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToMission(BuildContext context, DailyMissionType type) {
    switch (type) {
      case DailyMissionType.speakPractice:
        Navigator.pop(context);
        break;
      case DailyMissionType.lightningRound:
        Navigator.pop(context, 'lightning');
        break;
      case DailyMissionType.quizPlay:
        Navigator.pop(context, 'quiz');
        break;
    }
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TipsSection extends StatelessWidget {
  final List<String> tips = const [
    'שלבו האזנה, דיבור וקריאה כדי לזכור מילים במהירות.',
    'התנסו בשיחת Lightning לאחר כל שלב במפה.',
    'חזרו על מילים שקשות לכם והוסיפו אותן לרשימת המילים האישית.',
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.blueGrey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.lightbulb_outline, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'טיפים למסע מהיר יותר',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Text(tip, style: const TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
        children: [
          Icon(Icons.emoji_objects, size: 72, color: Colors.indigo.shade300),
          const SizedBox(height: 16),
          const Text(
            'המשימות של היום בדרך!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'משכו כלפי מטה כדי לרענן או התחילו מסע חדש מהמפה.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
