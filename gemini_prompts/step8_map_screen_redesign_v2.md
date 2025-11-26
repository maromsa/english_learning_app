# Gemini 3 Pro Prompt - Step 8: Map Screen Redesign V2 (Better Organization)

## Context
You are redesigning a Flutter educational app for children learning English. The app is in Hebrew (RTL) and uses Material 3 design. This is a **second redesign** of the Map Screen to fix organization issues - objects overlapping and stages scattered unpleasantly.

## Current Issues
The user reported:
- **"מסך המפה לא מסודר טוב"** (Map screen is not well organized)
- **"יש אובייקטים על אובייקטים"** (Objects on objects - overlapping elements)
- **"השלבים מפוזרים על המפה בצורה לא יפה"** (Stages are scattered on the map in an unpleasant way)

## Current App Theme
The app uses a custom theme (`AppTheme`) with:
- Primary colors: Blue (#4A90E2), Purple (#7B68EE), Green (#50C878), Orange (#FF6B6B), Yellow (#FFD93D)
- Font: Google Fonts Nunito (child-friendly)
- Material 3 design system
- RTL support for Hebrew

## Current Map Screen Structure

The MapScreen displays a game map with level nodes positioned on a background image. The current implementation has:

### Layout Structure
```dart
Scaffold(
  extendBodyBehindAppBar: true,
  extendBody: true,
  appBar: AppBar(...),
  bottomNavigationBar: NavigationBar(...),
  body: Stack(
    children: [
      // Background image
      Positioned.fill(
        child: RepaintBoundary(
          child: Image.asset('assets/images/map/map_background.jpg'),
        ),
      ),
      // Level nodes positioned absolutely
      LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: levels.map((level) {
              return Positioned(
                left: level.positionX * constraints.maxWidth - 40,
                top: level.positionY * constraints.maxHeight - 40,
                child: _LevelNode(...),
              );
            }).toList(),
          );
        },
      ),
      // Floating stats pill
      Positioned(
        top: kToolbarHeight + 40,
        left: 20,
        child: _StatsPill(...),
      ),
    ],
  ),
)
```

### Level Data Structure
Levels are loaded from `assets/data/levels.json` with the following structure:
```json
{
  "levels": [
    {
      "id": "level_fruits",
      "name": "שלב 1: פירות",
      "description": "למדו מילים של פירות טעימים",
      "unlockStars": 0,
      "reward": 30,
      "position": {
        "x": 0.1,
        "y": 0.85
      },
      "words": [...]
    },
    ...
  ]
}
```

### Current Level Positions (from levels.json)
The levels are positioned using relative coordinates (0.0-1.0):
- Level 1: x: 0.1, y: 0.85 (bottom-left)
- Level 2: x: 0.3, y: 0.7
- Level 3: x: 0.7, y: 0.5
- Level 4: x: 0.5, y: 0.3
- Level 5: x: 0.15, y: 0.18
- Level 6: x: 0.85, y: 0.18
- ... (more levels)

### Current Problems

1. **Overlapping Elements**: 
   - Stats pill might overlap with level nodes
   - Level nodes might overlap with each other
   - AppBar elements might overlap with nodes

2. **Scattered Layout**:
   - Levels are positioned randomly without clear visual flow
   - No clear path or progression visible
   - Levels don't follow a logical visual journey

3. **Poor Organization**:
   - No clear grouping of levels
   - No visual hierarchy
   - No clear "start" and "end" points

## Redesign Goals

### 1. Clear Visual Path
- Create a clear progression path from start to finish
- Levels should be arranged in a logical flow (left-to-right or top-to-bottom for RTL)
- Visual path should guide the child's eye naturally

### 2. Better Spacing
- Ensure no overlapping elements
- Adequate spacing between level nodes
- Clear safe zones for UI elements (AppBar, bottom nav, stats)

### 3. Organized Layout
- Group levels by difficulty or theme
- Create visual regions/zones on the map
- Clear visual hierarchy (completed, current, locked)

### 4. Child-Friendly Organization
- Easy to see which level comes next
- Clear visual feedback for progress
- Intuitive navigation

## Design Requirements

### Layout Options

**Option A: Linear Path (Recommended)**
- Arrange levels in a clear path (zigzag, spiral, or straight line)
- Start at top-left, end at bottom-right (or vice versa for RTL)
- Connect levels with visual path lines (optional)
- Clear progression flow

**Option B: Grid Layout**
- Organize levels in a grid pattern
- Clear rows and columns
- Easy to scan and navigate

**Option C: Zone-Based**
- Divide map into themed zones
- Each zone contains related levels
- Visual separation between zones

### Spacing Requirements
- Minimum 100px between level nodes (center to center)
- Safe zones:
  - Top: 120px (for AppBar and stats)
  - Bottom: 100px (for bottom navigation)
  - Left/Right: 60px (for edge spacing)
- No overlapping allowed

### Visual Hierarchy
- **Completed levels**: Green with checkmark, smaller size
- **Current level**: Large, pulsing, highlighted
- **Locked levels**: Gray, smaller, with lock icon
- **Upcoming levels**: Medium size, visible but not highlighted

## Your Task

Redesign the MapScreen with:

### 1. Better Level Positioning Algorithm
- Calculate optimal positions to avoid overlaps
- Create a clear visual path
- Ensure proper spacing
- Consider screen size variations

### 2. Visual Path (Optional but Recommended)
- Add connecting lines or path between levels
- Use subtle animations or visual cues
- Make progression clear

### 3. Improved Layout Structure
- Better organization of UI elements
- Clear separation between interactive and static elements
- Better use of screen space

### 4. Level Node Improvements
- Better visual distinction between states
- Clearer size hierarchy
- Better spacing and positioning

### 5. Safe Zones
- Ensure stats pill doesn't overlap with nodes
- Ensure AppBar doesn't interfere
- Ensure bottom nav doesn't block nodes

## Code Structure to Preserve

### Must Keep
- `MapScreen` widget structure
- Level loading from `levels.json`
- Level node widget (`_LevelNode`)
- Stats pill (`_StatsPill`)
- Navigation logic
- Music control (stops when leaving, resumes when returning)
- Progress tracking
- Unlock logic

### Can Modify
- Level positioning algorithm
- Layout structure
- Visual organization
- Spacing calculations

## Level Data

The app currently has multiple levels (check `assets/data/levels.json` for exact count). Each level has:
- `id`: Unique identifier
- `name`: Display name (Hebrew)
- `description`: Level description
- `unlockStars`: Stars needed to unlock
- `reward`: Coins reward
- `position`: `{x: 0.0-1.0, y: 0.0-1.0}` relative coordinates
- `words`: Array of word objects

## Output Format

Provide:
1. **Complete refactored `MapScreen` widget code** with:
   - Better level positioning algorithm
   - Improved layout structure
   - Better spacing and organization
   - Visual path (optional)

2. **Helper methods** for:
   - Calculating optimal positions
   - Detecting overlaps
   - Creating visual path

3. **Updated level positioning logic** that:
   - Avoids overlaps
   - Creates clear progression
   - Works on different screen sizes

4. **Brief explanation** of:
   - Positioning algorithm chosen
   - Layout improvements
   - How it solves the organization issues

## Design Inspiration

Think of:
- Game maps with clear paths (like Super Mario, Candy Crush)
- Educational apps with progression paths
- Adventure maps with waypoints
- Flow charts with clear connections

## Important Notes

- **Preserve all functionality**: Level loading, navigation, progress tracking, unlock logic - all must work
- **RTL Support**: Ensure layout works correctly in Hebrew (RTL)
- **Responsive**: Must work on different screen sizes
- **Performance**: Keep RepaintBoundary for background, optimize rendering
- **Child-friendly**: Clear, intuitive, easy to understand

## Current Code Location

The MapScreen is in `lib/screens/map_screen.dart`. The current implementation includes:
- Background image with RepaintBoundary
- Level nodes positioned absolutely
- Stats pill floating at top
- Bottom navigation bar
- AppBar with character avatar

Please provide a complete redesigned MapScreen that solves the organization and overlapping issues while maintaining all existing functionality.


