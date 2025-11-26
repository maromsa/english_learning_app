# Gemini 3 Pro Prompt - Step 3: AI Conversation Screen Redesign

## Context
You are redesigning a Flutter educational app for children learning English. The app is in Hebrew (RTL) and uses Material 3 design. The AI Conversation Screen is where children have interactive conversations with "Spark", an AI conversation coach that helps them practice English in a fun, engaging way.

## Current App Theme
The app uses a custom theme (`AppTheme`) with:
- Primary colors: Blue (#4A90E2), Purple (#7B68EE), Green (#50C878), Orange (#FF6B6B), Yellow (#FFD93D)
- Font: Google Fonts Nunito (child-friendly)
- Material 3 design system
- RTL support for Hebrew

## Current AI Conversation Screen Code

The complete AiConversationScreen implementation is in `lib/screens/ai_conversation_screen.dart`. Key parts:

### Main Build Method
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('חבר השיחה של ספרק'),
      backgroundColor: Colors.deepPurple.shade400,
    ),
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5E4AE3), Color(0xFF8E8DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Configurator (collapsible when session started)
            AnimatedSize(
              child: _sessionStarted
                  ? _buildCollapsedConfigurator()
                  : _buildConfiguratorCard(),
            ),
            // Error banner
            if (_errorMessage != null) _ErrorBanner(...),
            // Conversation area
            Expanded(
              child: _buildConversationArea(),
            ),
            // Input bar
            _buildInputBar(),
          ],
        ),
      ),
    ),
  );
}
```

### Message Bubbles

#### Spark Bubble (_SparkBubble)
```dart
class _SparkBubble extends StatelessWidget {
  final String message;
  final SparkCoachResponse? response;
  
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [...],
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text(message), // Main message
              if (response?.sparkTip != null) _InfoChip(...), // Tip
              if (response?.vocabularyHighlights.isNotEmpty) Wrap(...), // Vocabulary chips
              if (response?.miniChallenge != null) _InfoChip(...), // Challenge
              if (response?.followUp != null) _InfoChip(...), // Follow-up question
              if (response?.celebration != null) Text(...), // Celebration emoji
              if (response?.suggestedLearnerReplies.isNotEmpty) Wrap(...), // Suggested replies
            ],
          ),
        ),
      ),
    );
  }
}
```

#### Learner Bubble (_LearnerBubble)
```dart
class _LearnerBubble extends StatelessWidget {
  final String message;
  
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.lightBlue.shade100,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(message),
        ),
      ),
    );
  }
}
```

### Input Bar
```dart
Widget _buildInputBar() {
  return Card(
    margin: EdgeInsets.all(16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              hintText: 'מה תרצו להגיד לספרק?',
              onSubmitted: (_) => _sendLearnerMessage(),
            ),
          ),
          IconButton(
            icon: Icon(_isListening ? Icons.hearing_disabled : Icons.hearing),
            onPressed: _toggleListening,
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: _sendLearnerMessage,
          ),
        ],
      ),
    ),
  );
}
```

### Configurator Card
The configurator allows users to set:
- Topic (נושא)
- Skill Focus (מיקוד מיומנות)
- Energy Level (רמת אנרגיה)
- Learner Name (optional)
- Focus Words (מילות מיקוד)

### Current Issues
1. **Basic Message Bubbles** - Simple white/light blue bubbles, not very engaging
2. **Spark Has No Avatar** - No visual representation of Spark character
3. **Cluttered Spark Responses** - Tips, vocabulary, challenges all in one bubble, hard to scan
4. **Input Bar is Basic** - Simple text field with icons, not very prominent
5. **No Visual Feedback** - No typing indicators, no loading states for Spark
6. **Configurator Takes Space** - Even when collapsed, it still takes screen space
7. **No Message Timestamps** - Can't tell when messages were sent
8. **Suggestions are Small** - Suggested replies are small chips, could be more prominent

## Redesign Goals
1. **Modern Chat UI** - Make it feel like a real messaging app
   - Better message bubble design with avatars
   - Clear visual distinction between Spark and Learner messages
   - Smooth animations for new messages
   - Typing indicators when Spark is "thinking"

2. **Spark Character Representation** - Make Spark feel like a real friend
   - Avatar/icon for Spark (could be emoji or custom icon)
   - Personality in the design (friendly, encouraging colors)
   - Visual feedback when Spark is speaking (TTS indicator)

3. **Better Message Organization** - Make Spark's responses easier to read
   - Separate cards/sections for tips, vocabulary, challenges
   - Better visual hierarchy
   - Collapsible sections for long responses
   - More prominent suggested replies

4. **Enhanced Input Area** - Make input more intuitive and engaging
   - Larger, more prominent input field
   - Better microphone button with visual feedback
   - Clear send button
   - Show when listening (animated microphone)

5. **Improved Configurator** - Make setup more streamlined
   - Better organization of options
   - More visual, less text-heavy
   - Quick presets for common scenarios
   - Better focus words display

6. **Visual Polish** - Add delightful details
   - Smooth message animations (slide in, fade)
   - Loading states (Spark typing indicator)
   - Celebration animations for achievements
   - Better empty state (when no messages)

## Design Requirements
- **Child-friendly**: Bright, colorful, playful, encouraging
- **Accessible**: Large touch targets (min 48x48dp), clear contrast, readable text
- **RTL Support**: All layouts must work correctly in Hebrew
- **Performance**: Smooth 60fps animations, optimized scrolling
- **Responsive**: Works on different screen sizes (phones, tablets)
- **Engaging**: Use animations, colors, and visual feedback to keep children motivated

## Your Task
Redesign the AI Conversation Screen with:

1. **Modern Message Bubbles**
   - Spark messages: Left-aligned with Spark avatar/icon
     - Use purple/indigo color scheme for Spark
     - Rounded corners with tail (chat bubble style)
     - Avatar showing Spark's character (emoji or icon)
   - Learner messages: Right-aligned with user avatar
     - Use blue color scheme for learner
     - Rounded corners with tail
     - Simple user icon/avatar
   - Smooth slide-in animations for new messages
   - Optional: Message timestamps (can be subtle)

2. **Spark Response Organization**
   - Main message in primary bubble
   - Additional content (tips, vocabulary, challenges) in separate, visually distinct cards below
   - Use icons and colors to differentiate:
     - 💡 Tips: Yellow/amber card
     - 📚 Vocabulary: Blue card with word chips
     - 🎯 Challenges: Green card
     - ❓ Follow-up: Purple card
   - Suggested replies as prominent buttons (not small chips)
   - Celebration messages with larger, animated text

3. **Enhanced Input Bar**
   - Floating input bar (similar to modern chat apps)
   - Larger text field with better padding
   - Prominent microphone button with animation when listening
   - Clear send button
   - Visual feedback for all states (idle, listening, sending)

4. **Spark Character Avatar**
   - Consistent Spark avatar/icon throughout
   - Could be: 🎯 (target), ⚡ (spark), or custom icon
   - Show in AppBar, message bubbles, and loading states
   - Optional: Animated when Spark is "typing"

5. **Typing Indicator**
   - Show animated typing indicator when Spark is generating response
   - Use three dots animation or similar
   - Place where Spark's next message will appear

6. **Improved Configurator**
   - More compact design
   - Visual presets (e.g., "Quick Chat", "Practice Words", "Fun Story")
   - Better organization with icons
   - Focus words as visual chips/tags

7. **Empty State**
   - Engaging empty state when no conversation started
   - Show Spark character prominently
   - Clear call-to-action to start conversation
   - Friendly, encouraging message

8. **Loading States**
   - Show loading indicator when starting conversation
   - Typing indicator when Spark is responding
   - Disable input when busy

## Output Format
Provide:
1. Complete refactored `AiConversationScreen` widget code
2. Any new helper widgets/components needed (e.g., `_SparkAvatar`, `_TypingIndicator`, `_MessageBubble`, `_ResponseCard`)
3. Updated message bubble widgets
4. Brief explanation of design decisions
5. List of any new dependencies needed (if any)

## Code Style
- Use Material 3 components
- Follow Flutter best practices
- Use const constructors where possible
- Add meaningful comments
- Keep code readable and maintainable
- Preserve all existing functionality (TTS, speech recognition, conversation logic, etc.)

## Important Notes
- **Preserve all functionality**: Conversation generation, TTS, speech recognition, coin rewards, focus words, all settings - must work exactly as before
- **Keep existing services**: Don't change how ConversationCoachService, TTS, or speech recognition are used
- **Maintain state management**: Keep all existing state variables and their logic
- **RTL Support**: Ensure all layouts work correctly in Hebrew (RTL)
- **Animations**: Use smooth, child-friendly animations (not too fast, not jarring)
- **Spark's Personality**: Make Spark feel friendly, encouraging, and fun through design choices

## Current Data Structures
```dart
class _ChatEntry {
  final ConversationSpeaker speaker; // spark or learner
  final String message;
  final SparkCoachResponse? responseMeta; // Contains tips, vocabulary, challenges, etc.
}

class SparkCoachResponse {
  final String message;
  final String? sparkTip;
  final List<String> vocabularyHighlights;
  final String? miniChallenge;
  final String? followUp;
  final String? celebration;
  final List<String> suggestedLearnerReplies;
}
```

Please provide the complete redesigned AiConversationScreen code.


