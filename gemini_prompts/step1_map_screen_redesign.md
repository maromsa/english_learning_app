# Gemini 3 Pro Prompt - Step 1: Map Screen Redesign

## Context
You are redesigning a Flutter educational app for children learning English. The app is in Hebrew (RTL) and uses Material 3 design. The main navigation screen is the Map Screen where children see game levels as nodes on a map.

## Current App Theme
The app uses a custom theme (`AppTheme`) with:
- Primary colors: Blue (#4A90E2), Purple (#7B68EE), Green (#50C878), Orange (#FF6B6B), Yellow (#FFD93D)
- Font: Google Fonts Nunito (child-friendly)
- Material 3 design system
- RTL support for Hebrew

## Current Map Screen Code

The complete MapScreen implementation is in `lib/screens/map_screen.dart`. Key parts:

### Main Build Method
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      leading: Consumer<CharacterProvider>(
        builder: (context, characterProvider, _) {
          if (characterProvider.hasCharacter) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: CharacterAvatar(
                character: characterProvider.character!,
                size: 40,
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      title: Consumer<CharacterProvider>(
        builder: (context, characterProvider, _) {
          String title = "מסע המילים";
          if (characterProvider.hasCharacter) {
            title = "${characterProvider.character!.characterName} - $title";
          }
          return Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
            ),
          );
        },
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        PopupMenuButton<_QuickAiAction>(
          icon: const Icon(Icons.psychology_alt),
          tooltip: 'כלי AI חדשים',
          onSelected: _handleAiShortcut,
          itemBuilder: (context) => const [
            PopupMenuItem<_QuickAiAction>(
              value: _QuickAiAction.chatBuddy,
              child: Text('חבר שיחה של ספרק'),
            ),
            PopupMenuItem<_QuickAiAction>(
              value: _QuickAiAction.practicePack,
              child: Text('חבילת אימון AI'),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.auto_awesome),
          tooltip: 'מסע קסם עם Spark',
          onPressed: () { /* Navigate to adventure */ },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Row(
            children: [
              Icon(Icons.monetization_on, color: Colors.yellow.shade700),
              const SizedBox(width: 4),
              Text('${coinProvider.coins}'),
              const SizedBox(width: 12),
              const Icon(Icons.star, color: Colors.amber),
              const SizedBox(width: 4),
              Text('$_totalStars'),
            ],
          ),
        ),
        IconButton(icon: const Icon(Icons.flag), onPressed: _openDailyMissions),
        IconButton(icon: const Icon(Icons.card_giftcard), onPressed: _claimDailyReward),
        IconButton(icon: const Icon(Icons.store), onPressed: () { /* Navigate to shop */ }),
        IconButton(icon: const Icon(Icons.settings), onPressed: _openSettings),
        IconButton(icon: const Icon(Icons.people), onPressed: () { /* Navigate to users */ }),
      ],
    ),
    body: RepaintBoundary(
      child: Stack(
        children: [
          Image.asset(
            'assets/images/map/map_background.jpg',
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (levels.isEmpty)
            const Center(child: Text('אין שלבים זמינים כרגע...'))
          else
            ..._buildLevelNodes(context),
        ],
      ),
    ),
  );
}
```

### Level Node Widget
```dart
class _LevelNode extends StatelessWidget {
  final LevelData level;
  final int levelNumber;
  final VoidCallback? onTap;
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    final int cappedStars = level.stars.clamp(0, 3).toInt();
    return Tooltip(
      message: level.description ?? '${level.words.length} מילים בשלב',
      child: InkWell(
        onTap: () {
          if (level.isUnlocked) {
            onTap?.call();
          } else {
            onLockedTap?.call();
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: level.isUnlocked
                    ? Colors.amber.shade600
                    : Colors.grey.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: level.isUnlocked
                  ? Text(
                      levelNumber.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Icon(Icons.lock, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return Icon(
                  index < cappedStars ? Icons.star : Icons.star_border,
                  color: index < cappedStars ? Colors.amber : Colors.white,
                  size: 18,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Level Data Model
```dart
class LevelData {
  final String id;
  final String name;
  final String? description;
  final int reward;
  final int unlockStars;
  final double positionX;  // 0.0 to 1.0
  final double positionY;  // 0.0 to 1.0
  final List<WordData> words;
  bool isUnlocked;
  int stars;  // 0 to 3
}
```

## Current Issues
1. **AppBar is cluttered** - Too many icon buttons (AI tools, coins/stars, missions, rewards, shop, settings, users)
2. **Level nodes are basic** - Simple icons with text, not visually engaging
3. **No visual hierarchy** - Everything has equal visual weight
4. **Background is static** - Just an image, no interactivity
5. **Coins/stars display is cramped** - Small text in AppBar

## Redesign Goals
1. **Cleaner AppBar** - Move secondary actions to a bottom navigation or drawer
2. **Enhanced Level Nodes** - Make them more game-like with:
   - Animated glow effects for unlocked levels
   - Progress indicators showing completion
   - Visual distinction between locked/unlocked/completed
   - Smooth animations on interaction
3. **Better Information Display** - Create a dedicated stats card for coins/stars
4. **Improved Visual Hierarchy** - Use size, color, and animation to guide attention
5. **Modern UI Patterns** - Floating action buttons, bottom sheets, smooth transitions

## Design Requirements
- **Child-friendly**: Bright, colorful, playful
- **Accessible**: Large touch targets (min 48x48dp), clear contrast
- **RTL Support**: All layouts must work correctly in Hebrew
- **Performance**: Smooth 60fps animations, optimized rendering
- **Responsive**: Works on different screen sizes

## Your Task
Redesign the Map Screen with:
1. A cleaner AppBar with only essential actions
2. A floating stats card showing coins and stars prominently
3. Enhanced level nodes with:
   - Animated pulsing glow for unlocked levels
   - Progress rings showing completion percentage
   - Different visual styles for locked/unlocked/completed
   - Smooth scale animations on tap
4. A bottom navigation bar or floating action menu for secondary actions
5. Smooth page transitions and micro-interactions

## Output Format
Provide:
1. Complete refactored `MapScreen` widget code
2. Any new helper widgets/components needed
3. Brief explanation of design decisions
4. List of any new dependencies needed (if any)

## Code Style
- Use Material 3 components
- Follow Flutter best practices
- Use const constructors where possible
- Add meaningful comments
- Keep code readable and maintainable

Please provide the complete redesigned MapScreen code.

