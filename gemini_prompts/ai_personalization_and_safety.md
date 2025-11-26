# AI Personalization and Child Safety in All AI Features

## Overview

This document describes the requirements for personalizing all AI interactions in the app and ensuring child-safe content. The AI should recognize users, remember their names, recall information about them, and strictly prevent inappropriate content for children.

## Current AI Features

The app has three main AI-powered features:

1. **AI Conversation Screen** (`lib/screens/ai_conversation_screen.dart`)
   - Service: `ConversationCoachService` (`lib/services/conversation_coach_service.dart`)
   - System instruction: `_sparkSystemInstruction` (line ~90-94)

2. **AI Adventure Screen** (`lib/screens/ai_adventure_screen.dart`)
   - Service: `AdventureStoryService` (`lib/services/adventure_story_service.dart`)
   - System instruction: `_sparkSystemInstruction` (line ~46-50)

3. **AI Practice Pack Screen** (`lib/screens/ai_practice_pack_screen.dart`)
   - Service: `PracticePackService` (`lib/services/practice_pack_service.dart`)
   - System instruction: `_sparkSystemInstruction` (line ~48-51)

All services use `GeminiProxyService` to communicate with Gemini API through a proxy endpoint.

## Requirements

### 1. User Recognition and Personalization

#### 1.1 Get User Information
- Use `UserSessionProvider` (`lib/providers/user_session_provider.dart`) to get current user
- Access `AppSessionUser` which contains:
  - `id`: User ID
  - `name`: User's name
  - `photoUrl`: User's photo (optional)
  - `isGoogle`: Whether user is Google account or local

- For local users, also access `LocalUser` model (`lib/models/local_user.dart`) which contains:
  - `age`: User's age (important for age-appropriate content)
  - `name`: User's name
  - Additional metadata

#### 1.2 Pass User Context to AI
- Modify all three services to accept user information
- Include user context in every prompt sent to Gemini
- Store user preferences and progress for future sessions

#### 1.3 System Instructions Enhancement
Update all `_sparkSystemInstruction` constants to include:

```
You are Spark, [existing description]...

IMPORTANT USER CONTEXT:
- The learner's name is: [USER_NAME]
- The learner's age is: [USER_AGE] years old
- Always address the learner by their name when appropriate
- Remember previous conversations and reference them naturally
- Personalize your responses based on the learner's interests and progress
- Use the learner's name in greetings and encouragements

CHILD SAFETY REQUIREMENTS:
- NEVER discuss, mention, or allow topics related to: violence, weapons, drugs, alcohol, adult content, inappropriate relationships, or any content not suitable for children
- If the user attempts to discuss inappropriate topics, gently redirect to educational English learning topics
- Keep all content age-appropriate for children aged 5-10
- Focus exclusively on English learning, vocabulary, conversation practice, and educational adventures
- If asked about inappropriate topics, respond: "Let's focus on learning English! What's your favorite English word?"
```

### 2. Implementation Details

#### 2.1 Modify Service Constructors

**ConversationCoachService** (`lib/services/conversation_coach_service.dart`):
- Add optional `AppSessionUser?` parameter to constructor
- Add optional `LocalUser?` parameter for additional user data
- Pass user info to `_buildOpeningPrompt` and `_buildFollowUpPrompt`

**AdventureStoryService** (`lib/services/adventure_story_service.dart`):
- Add optional `AppSessionUser?` parameter to constructor
- Add optional `LocalUser?` parameter for additional user data
- Pass user info to `_buildPrompt`

**PracticePackService** (`lib/services/practice_pack_service.dart`):
- Add optional `AppSessionUser?` parameter to constructor
- Add optional `LocalUser?` parameter for additional user data
- Pass user info to `_buildPrompt`

#### 2.2 Update Prompt Building Methods

For each service, modify the prompt building methods to include user context:

**Example for ConversationCoachService:**
```dart
String _buildOpeningPrompt(ConversationSetup setup, {AppSessionUser? user, LocalUser? localUser}) {
  final userContext = <String, dynamic>{
    'learnerName': user?.name ?? localUser?.name ?? 'friend',
    'learnerAge': localUser?.age ?? 7, // Default age if not available
  };
  
  final contextJson = jsonEncode({
    ...setup.toMap(),
    'user': userContext,
  });
  
  // Rest of prompt...
}
```

**Example for AdventureStoryService:**
```dart
String _buildPrompt(AdventureStoryContext context, {AppSessionUser? user, LocalUser? localUser}) {
  final userContext = <String, dynamic>{
    'learnerName': user?.name ?? localUser?.name ?? 'explorer',
    'learnerAge': localUser?.age ?? 7,
  };
  
  final contextJson = jsonEncode({
    ...context.toMap(),
    'user': userContext,
  });
  
  // Rest of prompt...
}
```

#### 2.3 Update System Instructions

Enhance all `_sparkSystemInstruction` constants with user personalization and safety:

```dart
static const String _sparkSystemInstruction = '''
You are Spark, an energetic AI mentor helping Hebrew-speaking kids aged 6-10 practise English conversation. 
You reply in warm, supportive Hebrew sentences sprinkled with short English phrases that match the lesson focus. 
Keep answers concise (max 70 Hebrew words) and highlight no more than three English words per turn. 
Always output minified JSON following the caller instructions. Never mention JSON, prompts, or Gemini.

PERSONALIZATION:
- Address the learner by their name when provided in the context
- Remember and reference previous conversations naturally
- Personalize examples and vocabulary based on the learner's age and interests
- Use the learner's name in greetings: "שלום [NAME]!" or "היי [NAME]!"

CHILD SAFETY - STRICT REQUIREMENTS:
- NEVER discuss, mention, or allow topics related to: violence, weapons, drugs, alcohol, adult content, inappropriate relationships, horror, scary content, or any content not suitable for children aged 5-10
- If the user attempts to discuss inappropriate topics, immediately and gently redirect: "בואו נמשיך ללמוד אנגלית! מה המילה האהובה עליך באנגלית?" (Let's continue learning English! What's your favorite English word?)
- Keep all content educational, positive, and age-appropriate
- Focus exclusively on: English learning, vocabulary, conversation practice, educational adventures, fun activities, and positive encouragement
- If asked about inappropriate topics, respond with: "בואו נמשיך ללמוד אנגלית יחד! מה תרצו ללמוד היום?" (Let's continue learning English together! What would you like to learn today?)
- Never generate content that could be scary, violent, or inappropriate for young children
''';
```

#### 2.4 Update Screen Components

**AiConversationScreen** (`lib/screens/ai_conversation_screen.dart`):
- Get user from `UserSessionProvider` in `initState` or `build`
- Get `LocalUser` if available using `LocalUserService`
- Pass user info to `ConversationCoachService` methods

**AiAdventureScreen** (`lib/screens/ai_adventure_screen.dart`):
- Get user from `UserSessionProvider`
- Get `LocalUser` if available
- Pass user info to `AdventureStoryService.generateAdventure()`

**AiPracticePackScreen** (`lib/screens/ai_practice_pack_screen.dart`):
- Get user from `UserSessionProvider`
- Get `LocalUser` if available
- Pass user info to `PracticePackService.generatePack()`

### 3. User Memory and Persistence

#### 3.1 Store User Preferences
- Create a service to store user preferences and conversation history
- Use `SharedPreferences` or local database to persist:
  - User's favorite topics
  - Previous conversation themes
  - Vocabulary progress
  - Preferred learning style

#### 3.2 Include History in Prompts
- For conversation service, include previous session summaries
- Reference past achievements and progress
- Build on previous learning experiences

### 4. Safety Filtering

#### 4.1 Content Filtering
- Add explicit safety instructions in every system prompt
- Use Gemini's safety settings (if available through proxy)
- Implement client-side filtering for responses (check for inappropriate keywords)

#### 4.2 Response Validation
- After receiving AI response, validate it doesn't contain inappropriate content
- If inappropriate content detected, show fallback message and log incident
- Never display inappropriate content to the user

### 5. Code Changes Summary

#### Files to Modify:

1. **lib/services/conversation_coach_service.dart**
   - Update constructor to accept user parameters
   - Modify `_buildOpeningPrompt` and `_buildFollowUpPrompt`
   - Update `_sparkSystemInstruction`

2. **lib/services/adventure_story_service.dart**
   - Update constructor to accept user parameters
   - Modify `_buildPrompt`
   - Update `_sparkSystemInstruction`

3. **lib/services/practice_pack_service.dart**
   - Update constructor to accept user parameters
   - Modify `_buildPrompt`
   - Update `_sparkSystemInstruction`

4. **lib/screens/ai_conversation_screen.dart**
   - Get user from `UserSessionProvider`
   - Pass user to service methods

5. **lib/screens/ai_adventure_screen.dart**
   - Get user from `UserSessionProvider`
   - Pass user to service methods

6. **lib/screens/ai_practice_pack_screen.dart**
   - Get user from `UserSessionProvider`
   - Pass user to service methods

#### New Files (Optional):

1. **lib/services/user_preferences_service.dart**
   - Service to store and retrieve user preferences
   - Conversation history management
   - Progress tracking

### 6. Testing Requirements

- [ ] Test with user name - verify AI uses name in responses
- [ ] Test with different ages - verify age-appropriate content
- [ ] Test inappropriate topic attempts - verify redirection
- [ ] Test conversation continuity - verify references to previous sessions
- [ ] Test all three AI features with user personalization
- [ ] Test with no user (guest mode) - verify graceful fallback
- [ ] Test with Google user vs local user - verify both work

### 7. Example Implementation

**Example: Updated ConversationCoachService.startConversation**

```dart
Future<SparkCoachResponse> startConversation(
  ConversationSetup setup, {
  AppSessionUser? user,
  LocalUser? localUser,
}) async {
  final userName = user?.name ?? localUser?.name ?? 'friend';
  final userAge = localUser?.age ?? 7;
  
  final prompt = _buildOpeningPrompt(
    setup,
    userName: userName,
    userAge: userAge,
  );

  // Rest of implementation...
}
```

**Example: Enhanced System Instruction**

```dart
static String _buildSystemInstruction({String? userName, int? userAge}) {
  final base = 'You are Spark, an energetic AI mentor...';
  final personalization = userName != null 
    ? '\n\nPERSONALIZATION:\n- The learner\'s name is $userName. Always address them by name in greetings and encouragements.\n- The learner is ${userAge ?? 7} years old. Keep content age-appropriate.'
    : '';
  final safety = '\n\nCHILD SAFETY:\n- NEVER discuss inappropriate topics...';
  
  return base + personalization + safety;
}
```

### 8. Expected Behavior

After implementation:

✅ AI greets user by name: "שלום [NAME]!" or "היי [NAME]!"
✅ AI remembers user preferences and references them
✅ AI personalizes content based on user's age
✅ AI redirects inappropriate topics immediately
✅ AI never generates inappropriate content
✅ All three AI features (conversation, adventure, practice pack) are personalized
✅ Works with both local users and Google users
✅ Gracefully handles missing user information

---

**Priority**: HIGH - This affects user experience and child safety
**Files to modify**: 6 files (3 services + 3 screens)
**Estimated complexity**: Medium - Requires updating prompts and system instructions across all AI features











