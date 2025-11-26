# Gemini 3 Pro Prompt - Step 2: Home Page (Game Screen) Redesign

## Context
You are redesigning a Flutter educational app for children learning English. The app is in Hebrew (RTL) and uses Material 3 design. The Home Page is the main game screen where children practice pronouncing English words using speech recognition.

## Current App Theme
The app uses a custom theme (`AppTheme`) with:
- Primary colors: Blue (#4A90E2), Purple (#7B68EE), Green (#50C878), Orange (#FF6B6B), Yellow (#FFD93D)
- Font: Google Fonts Nunito (child-friendly)
- Material 3 design system
- RTL support for Hebrew

## Current Home Page Code

The complete HomePage implementation is in `lib/screens/home_page.dart`. Key parts:

### Main Build Method
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.lightBlue.shade300,
      title: Text(widget.title),
      centerTitle: true,
      actions: [
        IconButton(icon: Icon(Icons.chat), ...), // AI Chat
        IconButton(icon: Icon(Icons.emoji_events), ...), // AI Practice
        IconButton(icon: Icon(Icons.image_search), ...), // Image Quiz
        IconButton(icon: Icon(Icons.camera_alt), ...), // Add Word
        IconButton(icon: Icon(Icons.store), ...), // Shop
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _takePictureAndIdentify,
      label: Text('הוסף מילה'),
      icon: Icon(Icons.camera_alt),
    ),
    body: Center(
      child: SingleChildScrollView(
        child: Column(
          children: [
            ScoreDisplay(coins: coinProvider.coins),
            WordsProgressBar(
              totalWords: _words.length,
              completedWords: _words.where((w) => w.isCompleted).length,
            ),
            // Mission nudge card
            WordDisplayCard(
              wordData: currentWordData,
              onPrevious: _previousWord,
              onNext: _nextWord,
            ),
            SizedBox(height: 40),
            Row(
              children: [
                ActionButton(
                  text: 'הקשב',
                  icon: Icons.volume_up,
                  onPressed: () => flutterTts.speak(currentWordData.word),
                ),
                SizedBox(width: 20),
                _isListening
                    ? AnimatedMicrophone(isListening: true, size: 50)
                    : _isEvaluating
                        ? ProcessingIndicator(size: 50)
                        : ActionButton(
                            text: 'דבר',
                            icon: Icons.mic,
                            onPressed: _handleSpeech,
                          ),
              ],
            ),
            // Feedback text
            Text(_feedbackText),
          ],
        ),
      ),
    ),
  );
}
```

### Word Display Card Widget
```dart
class WordDisplayCard extends StatelessWidget {
  final WordData wordData;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Image with navigation arrows
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image(...), // 250x250 image
                ),
                Positioned(left: 0, child: PreviousButton()),
                Positioned(right: 0, child: NextButton()),
              ],
            ),
            SizedBox(height: 24),
            // Word text
            Text(
              wordData.word,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w600,
                color: Colors.indigo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Progress Bar Widget
```dart
class WordsProgressBar extends StatelessWidget {
  final int totalWords;
  final int completedWords;

  @override
  Widget build(BuildContext context) {
    final progress = completedWords / totalWords;
    return Column(
      children: [
        Text('$completedWords מתוך $totalWords מילים'),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      ],
    );
  }
}
```

### Speech Recognition Flow
1. User taps "דבר" (Speak) button
2. `AnimatedMicrophone` appears with pulsing animation
3. Speech recognition starts listening
4. When user stops speaking, `ProcessingIndicator` appears
5. Speech is evaluated using Gemini AI
6. Feedback text shows result ("כל הכבוד! +10 מטבעות" or error message)
7. If correct: confetti animation, word marked as completed, coins added

### Current Issues
1. **Cluttered AppBar** - Too many icon buttons (5 buttons)
2. **Basic Word Display** - Simple card with image and text, not very engaging
3. **Progress Bar is Basic** - Simple linear progress, could be more visual
4. **Feedback is Text-Only** - Just text at bottom, not very prominent
5. **Action Buttons Layout** - Side-by-side buttons, could be more prominent
6. **No Visual Celebration** - Confetti exists but could be more integrated
7. **Score Display is Small** - Just shows coins, could be more prominent
8. **Background is Static** - Just an image, no interactivity

## Redesign Goals
1. **Immersive Word Display** - Make the word the hero of the screen
   - Larger, more prominent word display
   - Better image presentation
   - Visual feedback when word is completed
   - Smooth transitions between words

2. **Enhanced Progress Visualization** - Make progress more engaging
   - Circular progress indicator or more visual progress
   - Show word cards or icons for completed words
   - Celebration when reaching milestones

3. **Better Feedback System** - Make feedback more prominent and encouraging
   - Large, animated success/error messages
   - Visual indicators (checkmarks, X marks)
   - Sound effects (optional, via TTS)
   - Better color coding

4. **Improved Controls** - Make actions more intuitive
   - Larger, more prominent microphone button
   - Better visual states (idle, listening, processing, success)
   - Clearer action hierarchy

5. **Cleaner AppBar** - Reduce clutter
   - Move secondary actions to a menu or bottom sheet
   - Keep only essential actions visible

6. **Better Score Display** - Make achievements more visible
   - Prominent coin display
   - Show streak count
   - Animate when coins are earned

7. **Mission Integration** - Better mission nudge
   - More prominent but not intrusive
   - Clear call-to-action

## Design Requirements
- **Child-friendly**: Bright, colorful, playful, encouraging
- **Accessible**: Large touch targets (min 48x48dp), clear contrast, readable text
- **RTL Support**: All layouts must work correctly in Hebrew
- **Performance**: Smooth 60fps animations, optimized rendering
- **Responsive**: Works on different screen sizes (phones, tablets)
- **Engaging**: Use animations, colors, and visual feedback to keep children motivated

## Your Task
Redesign the Home Page (Game Screen) with:

1. **Hero Word Display**
   - Large, prominent word card (larger than current)
   - Beautiful image presentation with better aspect ratio handling
   - Smooth fade/slide animations when changing words
   - Visual indicator when word is completed (checkmark overlay, color change)
   - Better navigation arrows (maybe swipe gestures?)

2. **Enhanced Progress System**
   - Replace simple linear progress with a more engaging visual
   - Options: Circular progress, word cards grid, milestone indicators
   - Show completion percentage prominently
   - Animate progress updates

3. **Prominent Feedback Display**
   - Large feedback card/modal that appears on success/error
   - Use colors: Green for success, Orange/Red for errors
   - Include icons (checkmark, X, star)
   - Animate in/out smoothly
   - Show coin rewards prominently

4. **Improved Microphone Control**
   - Large, prominent microphone button (maybe floating action button style)
   - Clear visual states:
     - Idle: Normal button
     - Listening: Pulsing animation with "מקשיב..." text
     - Processing: Rotating indicator with "בודק..." text
     - Success: Green checkmark with "כל הכבוד!"
     - Error: Red X with "נסה שוב"
   - Make it the primary action on the screen

5. **Cleaner AppBar**
   - Keep only level title and maybe one menu button
   - Move other actions to a bottom sheet or menu

6. **Better Score Display**
   - Floating coin counter (similar to Map Screen stats pill)
   - Show current streak
   - Animate when values change

7. **Mission Nudge**
   - Make it more visually appealing
   - Use card design with clear CTA
   - Don't make it too prominent (shouldn't distract from main game)

## Output Format
Provide:
1. Complete refactored `MyHomePage` widget code
2. Any new helper widgets/components needed (e.g., `_FeedbackCard`, `_EnhancedProgressIndicator`)
3. Updated `WordDisplayCard` if needed
4. Brief explanation of design decisions
5. List of any new dependencies needed (if any)

## Code Style
- Use Material 3 components
- Follow Flutter best practices
- Use const constructors where possible
- Add meaningful comments
- Keep code readable and maintainable
- Preserve all existing functionality (speech recognition, TTS, progress tracking, etc.)

## Important Notes
- **Preserve all functionality**: Speech recognition, TTS, progress tracking, coin rewards, word completion, level completion checks - all must work exactly as before
- **Keep existing services**: Don't change how services are initialized or used
- **Maintain state management**: Keep all existing state variables and their logic
- **RTL Support**: Ensure all layouts work correctly in Hebrew (RTL)
- **Animations**: Use smooth, child-friendly animations (not too fast, not jarring)

Please provide the complete redesigned HomePage code.


