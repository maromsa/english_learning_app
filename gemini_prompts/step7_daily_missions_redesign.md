# Gemini 3 Pro Prompt - Step 7: Daily Missions Screen Redesign

## Context
You are redesigning a Flutter educational app for children learning English. The app is in Hebrew (RTL) and uses Material 3 design. This step focuses on the **Daily Missions Screen** - a gamification feature that encourages daily engagement through quest-like missions with rewards.

## Current App Theme
The app uses a custom theme (`AppTheme`) with:
- Primary colors: Blue (#4A90E2), Purple (#7B68EE), Green (#50C878), Orange (#FF6B6B), Yellow (#FFD93D)
- Font: Google Fonts Nunito (child-friendly)
- Material 3 design system
- RTL support for Hebrew

## Current Daily Missions Screen Code

The complete DailyMissionsScreen implementation is in `lib/screens/daily_missions_screen.dart`. Key parts:

### Main Build Method
```dart
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

        final completedCount = missions.where((mission) => mission.isCompleted).length;
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
              ...missions.map((mission) => _MissionCard(mission: mission)),
              const SizedBox(height: 24),
              _TipsSection(),
            ],
          ),
        );
      },
    ),
  );
}
```

### Summary Header
```dart
class _SummaryHeader extends StatelessWidget {
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
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade500,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.flag_rounded, color: Colors.white, size: 28),
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
```

### Mission Card
```dart
class _MissionCard extends StatelessWidget {
  final DailyMission mission;

  Color _badgeColor() {
    if (mission.isClaimable) return Colors.amber.shade600;
    if (mission.isCompleted) return Colors.green.shade600;
    return Colors.blue.shade400;
  }

  IconData _badgeIcon() {
    if (mission.isClaimable) return Icons.redeem;
    if (mission.isCompleted) return Icons.check_circle_rounded;
    return Icons.bolt_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent = mission.completionRatio;
    final coins = mission.reward;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _badgeColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_badgeIcon(), color: _badgeColor()),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mission.title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(mission.description, style: textTheme.bodyMedium),
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
                Text('${mission.progress}/${mission.target}', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                          final missionsProvider = context.read<DailyMissionProvider>();
                          final coinProvider = context.read<CoinProvider>();
                          final success = await missionsProvider.claimReward(
                            mission.id,
                            (reward) => coinProvider.addCoins(reward),
                          );
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🎉 משימה הושלמה! קיבלתם $coins מטבעות.'),
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
                        onPressed: () => _navigateToMission(context, mission.type),
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
```

### DailyMission Model
```dart
enum DailyMissionType { speakPractice, lightningRound, quizPlay }

class DailyMission {
  final String id;
  final String title;
  final String description;
  final int target;
  final int reward;
  final DailyMissionType type;
  int progress;
  bool rewardClaimed;

  bool get isCompleted => progress >= target;
  double get completionRatio => target == 0 ? 1 : (progress / target).clamp(0, 1);
  bool get isClaimable => isCompleted && !rewardClaimed;
}
```

## Current Issues
1. **Basic Header** - Simple card with summary, could be more engaging
2. **Mission Cards** - Standard cards, not very game-like
3. **Progress Display** - Basic linear progress bar, could be more visual
4. **Claim Button** - Standard button, not very celebratory
5. **No Visual Hierarchy** - All missions look similar
6. **Tips Section** - Basic card, could be more integrated
7. **Empty State** - Simple icon and text, could be more inviting
8. **No Mission Types Distinction** - All missions look the same regardless of type

## Redesign Goals

### 1. Epic Mission Board
- Large, prominent header with daily mission theme
- Visual progress indicator (circular or segmented)
- Claimable rewards prominently displayed
- Daily reset timer (optional but nice)

### 2. Gamified Mission Cards
- Quest-like appearance with borders/glows
- Mission type icons (speech, lightning, quiz)
- Better progress visualization (circular progress, segmented bar, or visual steps)
- Clear state indicators (locked, in-progress, completed, claimable)
- Animated claim button

### 3. Enhanced Progress Display
- More visual progress indicators
- Percentage or visual steps
- Animated progress updates
- Clear remaining steps display

### 4. Celebratory Claim Flow
- Animated claim button
- Success animation when claiming
- Coin counter animation
- Confetti or particle effects

### 5. Mission Type Distinction
- Different visual styles for different mission types
- Type-specific icons and colors
- Clear visual hierarchy

### 6. Better Empty State
- Friendly illustration or icon
- Encouraging message
- Clear call-to-action

### 7. Visual Polish
- Better spacing and layout
- Smooth animations
- Loading states
- Error handling

## Design Requirements
- **Child-friendly**: Bright, colorful, playful, engaging
- **Accessible**: Large touch targets (min 48x48dp), clear contrast, readable text
- **RTL Support**: All layouts must work correctly in Hebrew
- **Performance**: Smooth 60fps animations, optimized rendering
- **Responsive**: Works on different screen sizes (phones, tablets)
- **Material 3**: Follow Material 3 design guidelines
- **Consistent**: Match the design language of other redesigned screens

## Your Task
Redesign the Daily Missions Screen with:

### 1. Hero Mission Board Header
- Large, engaging header section
- Visual progress indicator showing completion (e.g., circular progress or segmented bar)
- Prominent claimable rewards display with animation
- Daily mission theme with emoji/icon
- Optional: Daily reset countdown timer

### 2. Gamified Mission Cards
- Quest-like card design with:
  - Mission type icon (speech, lightning bolt, quiz)
  - Clear title and description
  - Visual progress indicator (circular, segmented, or step-based)
  - Reward badge prominently displayed
  - State-based styling (in-progress, completed, claimable)
- Different visual styles for different mission types
- Smooth animations on state changes

### 3. Enhanced Progress Visualization
- Circular progress indicator (optional)
- Segmented progress bar with steps
- Visual "steps remaining" indicator
- Animated progress updates
- Percentage display (optional)

### 4. Celebratory Claim Flow
- Animated claim button (pulsing or glowing when claimable)
- Success animation when claiming
- Coin counter animation
- Confetti or particle effects
- Success message with reward preview

### 5. Mission Type Visual Distinction
- **Speak Practice**: Microphone icon, blue/purple theme
- **Lightning Round**: Lightning bolt icon, yellow/orange theme
- **Quiz Play**: Quiz icon, green/teal theme
- Each type has distinct visual styling

### 6. Enhanced Empty State
- Friendly illustration or large icon
- Encouraging message
- Clear call-to-action
- Pull-to-refresh indicator

### 7. Tips Section
- Better integration with the design
- More visual appeal
- Optional: Collapsible or integrated into cards

### 8. Visual Enhancements
- Better background (gradient or pattern)
- Smooth transitions
- Loading indicators
- Error handling with friendly messages

## Output Format
Provide:
1. Complete refactored `DailyMissionsScreen` widget code
2. Any new helper widgets/components needed (e.g., `_MissionBoardHeader`, `_QuestCard`, `_ProgressIndicator`, `_ClaimButton`)
3. Brief explanation of design decisions
4. List of any new dependencies needed (if any)

## Code Style
- Use Material 3 components
- Follow Flutter best practices
- Use const constructors where possible
- Add meaningful comments
- Keep code readable and maintainable
- Preserve all existing functionality

## Important Notes
- **Preserve all functionality**: Mission loading, progress tracking, reward claiming, navigation - all must work exactly as before
- **Keep widget properties**: Don't change the constructor parameters
- **Maintain state management**: Keep all existing state variables and providers
- **RTL Support**: Ensure all layouts work correctly in Hebrew (RTL)
- **Animations**: Use smooth, child-friendly animations
- **Error Handling**: Preserve all error handling and validation
- **Mission Model**: The `DailyMission` model has: `id`, `title`, `description`, `target`, `reward`, `type`, `progress`, `rewardClaimed`, `isCompleted`, `completionRatio`, `isClaimable`

## Current Data Available
- `missionsProvider.missions` - List of DailyMission objects
- `missionsProvider.isInitialized` - Loading state
- `missionsProvider.refreshMissions()` - Refresh function
- `missionsProvider.claimReward(missionId, rewardCallback)` - Claim reward function
- `coinProvider.addCoins(amount)` - Add coins function
- Mission states: In-progress, Completed, Claimable
- Mission types: `speakPractice`, `lightningRound`, `quizPlay`

## Design Inspiration
Think of:
- Quest boards in RPG games
- Daily challenge screens in mobile games
- Achievement systems
- Progress trackers with visual steps
- Reward claiming animations
- Mission/quest UI patterns

Please provide the complete redesigned DailyMissionsScreen code.


