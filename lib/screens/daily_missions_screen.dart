import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'dart:math' as math;

import '../models/daily_mission.dart';
import '../providers/coin_provider.dart';
import '../providers/daily_mission_provider.dart';

class DailyMissionsScreen extends StatefulWidget {
  const DailyMissionsScreen({super.key});

  @override
  State<DailyMissionsScreen> createState() => _DailyMissionsScreenState();
}

class _DailyMissionsScreenState extends State<DailyMissionsScreen> {
  late ConfettiController _confettiController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    try {
      _confettiController = ConfettiController(duration: const Duration(seconds: 2));
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing confetti: $e');
      _isInitialized = false;
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _confettiController.dispose();
    }
    super.dispose();
  }

  Future<void> _handleClaim(
      BuildContext context, DailyMission mission, DailyMissionProvider provider) async {
    final coinProvider = context.read<CoinProvider>();

    final success = await provider.claimReward(
      mission.id,
      (reward) => coinProvider.addCoins(reward),
    );

    if (!mounted) return;

    if (success) {
      if (_isInitialized) {
        try {
          _confettiController.play();
        } catch (e) {
          debugPrint('Error playing confetti: $e');
        }
      }
      // Show snackbar or custom toast
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.celebration, color: Colors.white),
                const SizedBox(width: 12),
                Text('כל הכבוד! הרווחת ${mission.reward} מטבעות!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _handleNavigation(BuildContext context, DailyMissionType type) {
    switch (type) {
      case DailyMissionType.speakPractice:
        Navigator.pop(context); // Go back to map/home usually
        break;
      case DailyMissionType.lightningRound:
        Navigator.pop(context, 'lightning');
        break;
      case DailyMissionType.quizPlay:
        Navigator.pop(context, 'quiz');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('משימות יומיות',
            style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        foregroundColor: Colors.indigo.shade800,
      ),
      body: Stack(
        children: [
          // Confetti Overlay (Top z-index logic handled by Stack order)
          if (_isInitialized)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: math.pi / 2,
                maxBlastForce: 5,
                minBlastForce: 2,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.1,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange
                ],
              ),
            ),

          Consumer<DailyMissionProvider>(
            builder: (context, missionsProvider, _) {
              if (!missionsProvider.isInitialized) {
                return const Center(child: CircularProgressIndicator());
              }

              final missions = missionsProvider.missions;

              if (missions.isEmpty) {
                return _EmptyMissionsState(
                    onRefresh: missionsProvider.refreshMissions);
              }

              final completedCount =
                  missions.where((m) => m.isCompleted).length;
              final totalRewards =
                  missions.fold<int>(0, (sum, m) => sum + m.reward);
              final earnedRewards = missions
                  .where((m) => m.rewardClaimed)
                  .fold<int>(0, (sum, m) => sum + m.reward);

              return RefreshIndicator(
                onRefresh: missionsProvider.refreshMissions,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    // 1. Hero Header
                    _MissionBoardHeader(
                      completedCount: completedCount,
                      totalCount: missions.length,
                      earnedRewards: earnedRewards,
                      totalPossibleRewards: totalRewards,
                    ),

                    const SizedBox(height: 24),

                    // 2. Section Label
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0, bottom: 12.0),
                      child: Text(
                        "רשימת המשימות",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),

                    // 3. Mission List
                    ...missions.map((mission) => Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _QuestCard(
                            mission: mission,
                            onClaim: () => _handleClaim(
                                context, mission, missionsProvider),
                            onNavigate: () =>
                                _handleNavigation(context, mission.type),
                          ),
                        )),

                    const SizedBox(height: 20),

                    // 4. Tips
                    const _DailyTipCard(),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// COMPONENT WIDGETS
// ----------------------------------------------------------------

class _MissionBoardHeader extends StatelessWidget {
  final int completedCount;
  final int totalCount;
  final int earnedRewards;
  final int totalPossibleRewards;

  const _MissionBoardHeader({
    required this.completedCount,
    required this.totalCount,
    required this.earnedRewards,
    required this.totalPossibleRewards,
  });

  @override
  Widget build(BuildContext context) {
    double progress = totalCount == 0 ? 0 : completedCount / totalCount;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.indigo.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade200,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Progress
          SizedBox(
            height: 80,
            width: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                Center(
                  child: Text(
                    "${(progress * 100).toInt()}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Text Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "ההתקדמות היומית",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.lightGreenAccent, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            "$completedCount/$totalCount",
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on,
                              color: Colors.amberAccent, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            "$earnedRewards",
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  final DailyMission mission;
  final VoidCallback onClaim;
  final VoidCallback onNavigate;

  const _QuestCard({
    required this.mission,
    required this.onClaim,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final config = _MissionTypeConfig.fromType(mission.type);
    final bool isCompleted = mission.isCompleted;
    final bool isClaimable = mission.isClaimable;
    final bool isClaimed = mission.rewardClaimed;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: isClaimable
            ? Border.all(color: Colors.amber, width: 2)
            : Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Column(
        children: [
          // Top Section: Icon + Text
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: config.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(config.icon, color: config.color, size: 28),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mission.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Reward Badge
                if (!isClaimed)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.monetization_on,
                            color: Colors.amber.shade700, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          "+${mission.reward}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Middle Section: Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: mission.completionRatio,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? Colors.green : config.color,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${mission.progress} / ${mission.target}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      isCompleted
                          ? "הושלם!"
                          : "${((mission.completionRatio) * 100).toInt()}%",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? Colors.green : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Bottom Section: Action Button
          _QuestActionButton(
            isClaimable: isClaimable,
            isClaimed: isClaimed,
            isCompleted: isCompleted,
            config: config,
            onClaim: onClaim,
            onNavigate: onNavigate,
          ),
        ],
      ),
    );
  }
}

class _QuestActionButton extends StatelessWidget {
  final bool isClaimable;
  final bool isClaimed;
  final bool isCompleted;
  final _MissionTypeConfig config;
  final VoidCallback onClaim;
  final VoidCallback onNavigate;

  const _QuestActionButton({
    required this.isClaimable,
    required this.isClaimed,
    required this.isCompleted,
    required this.config,
    required this.onClaim,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Already Claimed
    if (isClaimed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 18, color: Colors.green),
              SizedBox(width: 8),
              Text("הפרס נאסף",
                  style:
                      TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    // 2. Ready to Claim (Celebratory Button)
    if (isClaimable) {
      return SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: FilledButton.icon(
            onPressed: onClaim,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 4,
            ),
            icon: const Icon(Icons.card_giftcard),
            label: const Text("אסוף פרס!",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    // 3. In Progress (Navigation Button)
    return InkWell(
      onTap: onNavigate,
      borderRadius:
          const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: config.color.withValues(alpha: 0.1),
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        child: Center(
          child: Text(
            "המשך במשימה",
            style: TextStyle(
              color: config.color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyTipCard extends StatelessWidget {
  const _DailyTipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, color: Colors.purple, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "טיפ יומי",
                  style: TextStyle(
                    color: Colors.purple.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "תרגול של 5 דקות ביום משפר את הביטחון העצמי בדיבור פלאים!",
                  style: TextStyle(color: Colors.purple.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMissionsState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyMissionsState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
        children: [
          Icon(Icons.task_alt, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "אין משימות כרגע",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => onRefresh(),
            icon: const Icon(Icons.refresh),
            label: const Text("רענן רשימה"),
          )
        ],
      ),
    );
  }
}

// --- Helper Class for Styling based on MissionType ---

class _MissionTypeConfig {
  final Color color;
  final IconData icon;

  _MissionTypeConfig(this.color, this.icon);

  static _MissionTypeConfig fromType(DailyMissionType type) {
    switch (type) {
      case DailyMissionType.speakPractice:
        return _MissionTypeConfig(Colors.blue, Icons.mic_rounded);
      case DailyMissionType.lightningRound:
        return _MissionTypeConfig(Colors.orange, Icons.bolt_rounded);
      case DailyMissionType.quizPlay:
        return _MissionTypeConfig(Colors.green, Icons.quiz_rounded);
    }
  }
}
