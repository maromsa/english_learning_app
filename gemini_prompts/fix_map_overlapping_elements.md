# Fix Overlapping Elements on Map Screen

## Problem Description

The map screen (`lib/screens/map_screen.dart`) has overlapping UI elements that interfere with each other. Elements are positioned on top of each other, making the interface cluttered and potentially blocking user interactions.

**CRITICAL ISSUE**: The Settings button (in AppBar `actions`) overlaps with:
1. The Stats Pill (coins and stars display) positioned at top-left
2. The Map Title Card ("המסע של..." / "מסע המילים") in the centered AppBar title

## Current Structure

The map screen uses a `Stack` widget with the following elements:

1. **AppBar** with:
   - `leading`: `CurrentUserAvatar` widget (width: 180)
   - `title`: `_MapTitleCard` (centered)
   - `actions`: Settings button

2. **Stack children** (in order):
   - Background image (`Positioned.fill`)
   - Scrollable map content (`SingleChildScrollView` with level nodes)
   - Floating Stats Pill (`Positioned` at top-left, below AppBar)
   - Error banner (`Positioned` at bottom, above bottom nav)

3. **Bottom Navigation Bar** (fixed at bottom)

## Issues to Fix

### 1. Settings Button Overlaps with Stats Pill and Title (CRITICAL)
- **Problem**: The Settings button in AppBar `actions` overlaps with:
  - The Stats Pill (`_StatsPill`) positioned at `top: kToolbarHeight + 20, left: 20`
  - The Map Title Card (`_MapTitleCard`) in the centered AppBar title
- **Current Code**: Settings button is at line ~939-959, Stats Pill at line ~1084, Title at line ~937
- **Solution**: 
  - **Option A**: Move Stats Pill to a different position (e.g., below AppBar on the right side, or integrate into AppBar)
  - **Option B**: Reposition Settings button (e.g., move to leading area, or use a different layout)
  - **Option C**: Adjust AppBar layout - reduce title width, move Settings to a different location
  - **Option D**: Make Stats Pill part of AppBar (e.g., in `actions` before Settings, or in `title` area)
  - Ensure proper spacing between all AppBar elements and Stats Pill
  - Use `MediaQuery` to calculate available space and adjust positions dynamically
  - Consider using `Flexible` or `Expanded` widgets to manage space better

### 2. AppBar Elements Overlap
- **Problem**: `CurrentUserAvatar` has `leadingWidth: 180`, which may overlap with the centered `_MapTitleCard` title, especially on smaller screens.
- **Solution**: 
  - Adjust `leadingWidth` to be responsive based on screen size
  - Ensure title has proper padding/margin to avoid overlap
  - Consider hiding title text on very small screens or making it smaller
  - Calculate available space: `screenWidth - leadingWidth - actionsWidth` and ensure title fits

### 3. Stats Pill Overlaps with Level Nodes
- **Problem**: The `_StatsPill` is positioned at `top: kToolbarHeight + 20, left: 20`, which is a fixed position. When scrolling, level nodes may appear behind or overlap with the stats pill.
- **Solution**:
  - Ensure Stats Pill has proper z-index (appears above scrollable content)
  - Add padding to the scrollable content to prevent level nodes from appearing under the stats pill
  - Consider making stats pill scroll-aware or repositioning it

### 4. Level Nodes May Overlap Each Other
- **Problem**: Level nodes are positioned using `_calculateLevelPosition()` which uses a sine wave algorithm. On certain screen sizes or with many levels, nodes might overlap.
- **Solution**:
  - Add collision detection to prevent overlapping
  - Increase `_levelHeightSpacing` if needed
  - Adjust `_pathAmplitude` to ensure nodes don't get too close horizontally
  - Add minimum distance checks between nodes

### 5. Error Banner Overlaps with Level Nodes
- **Problem**: Error banner is positioned at `bottom: 100` which may overlap with level nodes when scrolling to the bottom.
- **Solution**:
  - Ensure error banner appears above scrollable content (proper z-index)
  - Add padding to bottom of scrollable content to prevent overlap
  - Consider repositioning or making it dismissible

### 6. Bottom Navigation Overlaps Content
- **Problem**: With `extendBody: true`, the bottom navigation may overlap with level nodes at the bottom of the map.
- **Solution**:
  - Ensure `_bottomPadding` (currently 120.0) is sufficient
  - Verify that the last level node is positioned above the bottom nav area
  - Add safe area insets if needed

## Technical Requirements

### Z-Index Order (Bottom to Top)
1. Background image
2. Scrollable content (path lines and level nodes)
3. Stats Pill (should be above scrollable content)
4. Error banner (should be above scrollable content)
5. AppBar (always on top)
6. Bottom Navigation (always on top)

### Responsive Design
- Test on different screen sizes (small phones, tablets)
- Ensure elements don't overlap on any screen size
- Use `MediaQuery` to adjust spacing/padding based on screen dimensions

### Safe Areas
- Respect safe area insets (notch, status bar, home indicator)
- Use `SafeArea` widget where appropriate
- Ensure content is accessible on all devices

## Code Structure to Review

Key areas in `lib/screens/map_screen.dart`:

1. **AppBar configuration** (lines ~928-962):
   - `leadingWidth: 180` - may need adjustment
   - Title positioning (`_MapTitleCard` at line ~937)
   - **Settings button** (lines ~939-959) - **CRITICAL**: overlaps with Stats Pill and Title
   - Need to calculate: `leadingWidth + titleWidth + actionsWidth` and ensure it fits screen

2. **Stack children** (lines ~981-1101):
   - Background: `Positioned.fill` (line ~984)
   - Scrollable content: `SingleChildScrollView` (line ~1011)
   - **Stats Pill: `Positioned` (line ~1084)** - **CRITICAL**: overlaps with Settings button
     - Current position: `top: kToolbarHeight + 20, left: 20`
     - This is in the same area as Settings button (top-right of AppBar)
   - Error banner: `Positioned` (line ~1095)

3. **Level positioning** (lines ~1042-1075):
   - `_calculateLevelPosition()` function
   - `_levelHeightSpacing` constant (140.0)
   - `_pathAmplitude` constant (80.0)

4. **Padding constants** (lines ~57-61):
   - `_topPadding: 160.0`
   - `_bottomPadding: 120.0`

## Expected Outcome

After fixes:
- ✅ **Settings button doesn't overlap with Stats Pill or Title** (CRITICAL)
- ✅ No overlapping elements visible
- ✅ All interactive elements (level nodes, buttons) are clickable
- ✅ Stats pill is always visible and doesn't block content or AppBar elements
- ✅ Error banner doesn't overlap with level nodes
- ✅ AppBar elements (leading, title, actions) don't overlap
- ✅ Works correctly on all screen sizes
- ✅ Proper spacing between all elements

## Testing Checklist

- [ ] Test on small screen (iPhone SE size)
- [ ] Test on medium screen (standard phone)
- [ ] Test on large screen (tablet)
- [ ] Scroll to top - verify stats pill doesn't overlap AppBar
- [ ] Scroll to bottom - verify last level node is above bottom nav
- [ ] Verify all level nodes are clickable
- [ ] Verify error banner (if shown) doesn't block level nodes
- [ ] **Verify Settings button doesn't overlap with Stats Pill** (CRITICAL)
- [ ] **Verify Settings button doesn't overlap with Map Title Card** (CRITICAL)
- [ ] Verify CurrentUserAvatar doesn't overlap with title
- [ ] Verify Stats Pill is visible and doesn't overlap with any AppBar elements
- [ ] Test on different screen sizes to ensure no overlaps
- [ ] Test with many levels (6+ levels)
- [ ] Test with few levels (1-2 levels)

## Implementation Notes

- Use `RepaintBoundary` for performance (already used for background)
- Consider using `IgnorePointer` for elements that shouldn't receive touch events
- Use `ClipRect` or `ClipRRect` if needed to prevent overflow
- Ensure all `Positioned` widgets have proper constraints
- Consider using `LayoutBuilder` for responsive calculations (already used in some places)

## Priority

**CRITICAL Priority**: 
- Fix Settings button overlapping with Stats Pill and Map Title Card
- This is a visible and functional issue that affects user experience

**High Priority**: Fix overlapping that blocks user interaction (level nodes, buttons)
**Medium Priority**: Fix visual overlaps (stats pill positioning, error banner)
**Low Priority**: Optimize spacing for better aesthetics

## Recommended Solution Approach

1. **Reposition Stats Pill**: Move it to avoid AppBar area
   - Option: Position it at `top: kToolbarHeight + 60, right: 20` (below AppBar, on right side)
   - Option: Integrate into AppBar as part of `actions` (before Settings button)
   - Option: Move to bottom of screen (above bottom nav)

2. **Adjust AppBar Layout**:
   - Reduce `leadingWidth` if needed
   - Make title more compact or responsive
   - Consider using `flexibleSpace` for custom AppBar layout

3. **Use LayoutBuilder** to calculate available space:
   ```dart
   LayoutBuilder(
     builder: (context, constraints) {
       final availableWidth = constraints.maxWidth;
       final leadingWidth = 180.0;
       final actionsWidth = 56.0; // Settings button width
       final titleMaxWidth = availableWidth - leadingWidth - actionsWidth - 32; // 32 for padding
       // Use titleMaxWidth to ensure title doesn't overlap
     }
   )
   ```

---

**File to modify**: `lib/screens/map_screen.dart`
**Related widgets**: `_StatsPill`, `_LevelNode`, `_MapTitleCard`, `CurrentUserAvatar`

