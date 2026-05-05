# English Learning App — Project Specification

**Document Type:** Technical Product Spec  
**Author:** Senior Software Architect / Technical Product Manager  
**Date:** 2026-05-05  
**Status:** Living document — reflects current codebase state

---

## 1. Project Overview & Core Functionality

### Purpose

"מסע המילים באנגלית" (English Word Journey) is a gamified English vocabulary learning app targeting **Hebrew-speaking children aged 5–10**. The app blends structured word practice with AI-powered conversational features, a reward economy, and a 3D adventure map — all delivered as a cross-platform Flutter application (iOS, Android, Web).

### Core Features

**Vocabulary Learning Loop**  
Children progress through themed word levels (fruits, animals, magic items, vehicles, space, etc.). Each word is presented with an image and spoken pronunciation. The child must answer multiple-choice questions correctly to "master" the word and earn coins.

**AI Buddy — "Spark"**  
An AI companion (powered by Google Gemini via a Firebase Cloud Function proxy) offers three AI-driven activities:
- **AI Conversation** — Free-form voice conversation with Spark, guided by topic, skill level, and energy mode.
- **AI Adventure Story** — Spark generates a short interactive story using the child's learned vocabulary and chosen character mood.
- **AI Practice Pack** — Spark generates a custom structured activity pack (listening, speaking, writing mini-tasks) tailored to the child's words, age, and skill level.

**Camera Word Discovery**  
Children can photograph real-world objects; the app uses Gemini image recognition to validate whether the photo matches the current vocabulary word.

**Gamification & Economy**  
A coin economy rewards correct answers, level completion, and daily streaks. Coins are spent in a virtual shop on stickers and upgrades. An achievement system unlocks trophies for milestones.

**3D Adventure Map**  
An interactive Three.js WebView map visualises level progression as islands/nodes. The Flutter app communicates with the map via a JavaScript bridge (`MapChannel`) to update state in real time.

**Multi-User & Authentication**  
The app supports multiple local profiles per device (stored in SharedPreferences) and optional Google Sign-In that links a profile to Firebase Auth and syncs game data to Firestore. Multiple child profiles can coexist on a single device.

**Daily Missions & Streaks**  
Three randomised daily missions (speak practice, lightning quiz, image quiz) reset every 24 hours. Completing missions rewards coins and triggers Spark celebrations.

---

## 2. Current State — What Has Been Implemented

### 2.1 Authentication & User Management

- `AuthGate` — entry point; routes to onboarding, user selection, or map based on app state.
- `OnboardingScreen` — 3-page introduction (shown once, persisted via `SharedPreferences`).
- `UserSelectionScreen` — lists all local profiles; allows creating a new user or signing in with Google.
- `CreateUserScreen` — creates a local user (name, age, optional Google linking).
- `SignInScreen` — Google Sign-In via `firebase_auth` + `google_sign_in`.
- `LocalUserService` — full CRUD for local user profiles persisted in `SharedPreferences`.
- `LocalUserDataService` — per-user coin balance and purchased items for local (non-Firebase) users.
- `UserDataService` — Firestore sync for Firebase users (`users/{uid}/gameData/player`).
- `UserSessionProvider` — active session state (current user, Firebase vs. local mode).
- `AuthProvider` — wraps Firebase Auth stream.
- `PlayerDataSyncService` — syncs `PlayerData` between local state and Firestore.

**User model dual-mode:**  
Local users: `LocalUser` stored in `SharedPreferences`.  
Firebase users: `AppUser` and `PlayerData` stored in Firestore.

### 2.2 Main Map & Navigation

- `MapScreen` — hub screen with a bottom navigation bar (Map, Shop, Daily Missions, Settings).
- **3D WebView Map** — renders `assets/map_3d/index.html` (Three.js) inside a `WebViewController`; receives bridge commands from Flutter via `MapChannel`.
- **MapBridgeService** — Flutter↔JS message channel; sends word-mastered events to the 3D map to spawn visual assets (`.glb` model).
- **Snake layout** — level nodes are positioned in a snake path using `levels.json`; locked levels shown with star requirements.
- **Level data** — 6 themed levels fully defined in `assets/data/levels.json` (Fruits, Animals, Magic Items, Vehicles, Space, plus fantasy items).
- `LevelRepository` — loads and caches `levels.json`.
- `CharacterProvider` + `CharacterSelectionScreen` — player character selection.
- `CurrentUserAvatar` + `UserSwitchSheet` — top-right avatar with a bottom sheet for switching between user profiles.

### 2.3 Word Learning (Home Page)

- `MyHomePage` — core learning screen; receives a level's `WordData` list.
- Word presentation with image (local asset or Cloudinary URL), English word display, and TTS pronunciation.
- Multiple-choice answering with `AnswerButton` widgets and visual feedback.
- Correct-answer flow: coin award, confetti animation, streak tracking.
- `WordRepository` — fetches word images from Cloudinary with local `SharedPreferences` caching as fallback.
- `LevelProgressService` — persists completed words per level per user (SharedPreferences); integrates with `WordMasteryService` and `MapBridgeService`.
- `WordMasteryService` — mastery score (`0.0–1.0`) per word with spaced-repetition-style review signals.
- `LevelCompletionScreen` — shown at level end with stars earned and coins collected.

**TTS dual-mode:**  
`FlutterTts` (device) with optional `GoogleTtsService` (Google Cloud TTS HTTP API) for higher-quality voice.

### 2.4 AI Features (Spark)

All AI features route through `GeminiProxyService` → Firebase Cloud Function (`geminiProxy`) → Google Gemini API. The proxy keeps the Gemini API key server-side.

- **`AiConversationScreen`** — voice/text chat with Spark; configurable topic, skill level, and energy. Uses `ConversationCoachService` for prompt building + response parsing, `SpeechToText` for voice input, and TTS for voice output. Maintains conversation history for multi-turn context.
- **`AiAdventureScreen`** — generates a personalized adventure story using `AdventureStoryService`. Child selects a mood and a level; Spark creates a story embedding that level's vocabulary words. Child-safety guardrails are built into the system instruction.
- **`AiPracticePackScreen`** — generates a structured mini activity pack via `PracticePackService`. Configurable skill, time, energy, and mode. Activities are displayed as a checklist the child completes.
- **`CameraScreen`** — live camera feed; child photographs a real object; `AiImageValidator` (via HTTP proxy) checks if the photo matches the target word.
- **`KidSpeechService`** — wraps `speech_to_text` with kid-friendly tolerance logic for pronunciation checking.
- **`SparkVoiceService`** — provides Spark's animated voice responses.
- **`OnboardingPersonalizer`** — AI-driven personalization logic for the onboarding flow.

### 2.5 Gamification & Economy

- **`CoinProvider`** — global coin state; persists per-user with `SharedPreferences` (local users) or Firestore sync (Firebase users). Handles per-level coin tracking (`levelCoins`).
- **`ShopScreen`** + **`ShopProvider`** — virtual shop with 12 items (stickers and upgrades at varying coin costs); purchase flow with confetti + sound on success.
- **`ShopItem` model** — catalog of 12 items (magic hat, wand, spell book, swords, armor, etc.) defined statically.
- **`AchievementService`** — manages 6 achievements: First Word Learned, Quiz Streak (5), Coin Collector (500 coins), Map Builder (10 items), Level 1 Complete, and Add Word. Unlocks are persisted in SharedPreferences; synced to Firestore for Firebase users. Listens to `CoinProvider` for automatic unlocks.
- **`AchievementsScreen`** — Trophy Room with a scrollable grid of `GlassCard` achievement cards (locked = grayscale, unlocked = full color).
- **`AchievementNotification` widget** — animated glassmorphism toast that slides in on achievement unlock (3-second auto-dismiss).
- **`DailyMissionProvider`** — manages 3 randomly-selected daily missions; 24-hour reset via date key in SharedPreferences; triggers Spark celebration on first completion.
- **`DailyMissionsScreen`** — displays missions with progress bars, `SparkButton` claim flow, and confetti reward animation.
- **`DailyRewardService`** — daily login reward with streak multiplier (base 10–20 coins + up to ×5 streak bonus).
- **`SparkOverlayController`** — controls the global Spark celebration animation overlay (`LivingSparkOverlay`).

### 2.6 Practice Modes

- **`LightningPracticeScreen`** — 60-second timed quiz; shuffled word pool with smart anti-repeat queue; displays score, streak, and performance stats at end. Awards coins and updates daily missions.
- **`ImageQuizGame`** + **`ImageQuizScreen`** — static image quiz with a predefined question bank covering all learned vocabulary themes.

### 2.7 Audio & UX

- **`BackgroundMusicService`** — `just_audio`-based; plays looping map music (`the_twinkling_map.mp3`); fades in/out on screen transitions; pauses during AI screens.
- **`SoundService`** — short UI feedback sounds (`startup_chime.wav`, `background_loop.wav`).
- **`ThemeProvider`** + `AppTheme` — light and dark mode with persisted preference; uses Google Fonts.
- **`PageTransitions`** — custom slide/fade transitions between screens.
- **`LivingSpark` widget** + `LivingSparkOverlay` — animated 3D Spark character (`.glb` model via `model_viewer_plus`) as a persistent overlay.
- **`BouncyButton`**, **`GlassCard`**, **`SparkButton`**, **`ProcessingIndicator`** — reusable UI components.

### 2.8 Settings & Telemetry

- **`SettingsScreen`** — dark/light mode toggle, progress reset, word cache clear.
- **`TelemetryService`** — screen session tracking (start/end events) for usage analytics via Firebase Analytics.
- **`AppConfig`** — reads all secrets from `--dart-define` compile-time variables (Gemini endpoint, Cloudinary keys, Google TTS key); no secrets in source.

### 2.9 Infrastructure & CI/CD

- Firebase project configured for Android, iOS, and Web (`firebase_options.dart`, `google-services.json`).
- `.env` + `flutter_dotenv` for native builds; `--dart-define` for web builds.
- **GitHub Actions workflows:**
  - `deploy-web-pages.yml` — builds and deploys Flutter Web to GitHub Pages.
  - `appetize-upload.yml` — uploads APK to Appetize.io for online emulator testing.
  - `test.yml` — runs Flutter unit tests on push.
- Cloudinary integration for remote word images with CDN delivery.
- `dio` + `DioSmartRetry` for HTTP with retry logic; `AppHttpClient` wrapper.

### 2.10 Data Models (Summary)

| Model | Storage | Key Fields |
|---|---|---|
| `LocalUser` | SharedPreferences | id, name, age, photoUrl, googleUid |
| `AppUser` | Firestore `users/{uid}` | uid, email, role, displayName |
| `PlayerData` | Firestore `users/{uid}/gameData/player` | coins, purchasedItems, achievements, levelProgress, dailyStreak |
| `LevelProgress` | SharedPreferences + Firestore | stars, isUnlocked, wordsCompleted |
| `WordData` | `levels.json` + Cloudinary | word, imageUrl, searchHint |
| `Achievement` | SharedPreferences + Firestore | id, title, icon, isUnlocked, requirementValue |
| `DailyMission` | SharedPreferences | id, type, target, progress, reward, rewardClaimed |
| `ShopItem` | Static catalog | id, name, imageUrl, cost, type |
| `WordMasteryEntry` | SharedPreferences | masteryLevel (0.0–1.0), lastReviewed |
| `PlayerCharacter` | SharedPreferences + Firestore | character selection |

---

## 3. Pending Tasks & Roadmap

### Priority 1 — Bug Fixes & Code Health

These are existing issues that should be resolved before new features are added.

**Deprecated API Usage (20+ instances)**  
`withOpacity` → `.withValues()` and `TextEditingController(value:)` → `initialValue` across `ai_conversation_screen.dart`, `ai_practice_pack_screen.dart`, `camera_screen.dart`, `daily_missions_screen.dart`, `home_page.dart`. These will become errors in future Flutter/Dart versions.

**BuildContext Across Async Gaps (5 instances)**  
Missing `if (!mounted) return;` guards in `ai_conversation_screen.dart` (lines 392, 473), `home_page.dart` (444), `image_quiz_game.dart` (140). Risk of crashes when widgets are disposed before async callbacks complete.

**Unnecessary Imports**  
`package:flutter/foundation.dart` unused in `ai_conversation_screen.dart` and `ai_practice_pack_screen.dart`.

**iOS Entitlements File Missing**  
`ios/Runner/Runner.entitlements` does not exist. Required for push notifications, background modes, and keychain capabilities.

**Outdated Dependencies**  
70 packages have newer versions available, including major-version bumps for `firebase_core`, `firebase_auth`, and `firebase_storage`. Needs a coordinated upgrade with regression testing.

### Priority 2 — Feature Gaps

**Camera Mission Daily Type**  
`DailyMissionType.camera` is planned in the enum but no camera-based daily mission is wired into the mission catalog or UI. The camera screen exists; the daily mission integration does not.

**Achievement Callback Context**  
The achievement unlock toast (`AchievementNotification`) is currently only set up from `MyHomePage`. Unlocks triggered from `ImageQuizGame` or from the coin/shop listener (inside `AchievementService`) may not show the overlay if the user is not on the home page. The callback should be registered at a root-level widget (e.g., `AuthGate` or `MaterialApp.builder`) so it fires from any screen.

**Firestore Achievement Sync for Local Users**  
Local (non-Firebase) users have their achievements saved only in SharedPreferences. There is no cloud backup or cross-device restore for local users.

**Character Customization Flow**  
`CharacterProvider` and `CharacterSelectionScreen` exist but character selection is not prominently surfaced in the UX (no clear entry point from the map or settings) and character data persistence to Firestore for Firebase users needs verification.

**Onboarding Personalization**  
`OnboardingPersonalizer` service exists but is not yet integrated into the actual onboarding flow. The current onboarding is a static 3-page introduction.

**Word Mastery & Spaced Repetition**  
`WordMasteryService` records mastery scores but the scores are not yet used to intelligently surface review words or adjust difficulty in the Lightning Practice or Home Page word order.

**Parent / Teacher Dashboard**  
No read-only view of a child's progress exists for parents or teachers. This is listed as a high-priority future feature.

**Offline Support**  
The word image cache (Cloudinary via `WordRepository`) provides basic offline fallback, but AI features, coin sync, and Firestore-backed features fail without a connection. A full offline-first strategy is not implemented.

**Progress Analytics**  
Firebase Analytics is integrated (`TelemetryService`) but no custom events for learning outcomes (e.g., words mastered per session, quiz accuracy trend) are tracked or visualized.

### Priority 3 — Content & UX Improvements

**More Levels & Words**  
Only 6 levels are defined in `levels.json`. Expanding content (more themes, more words per level, higher difficulty tiers) is the primary ongoing content task.

**Social & Sharing Features**  
No ability to share achievements or invite friends. Planned for a later phase.

**Adaptive Difficulty**  
The app currently uses fixed difficulty per level. Adapting word presentation order and quiz option difficulty based on `WordMasteryEntry` data would improve learning outcomes.

**Sound Effects Polish**  
Only two audio files are in use for UI feedback. More contextual sounds (per-answer feedback, level-up fanfare, shop purchase) would improve engagement.

**More Achievement Types**  
The current 6 achievements cover basic milestones. A richer achievement tree (streaks, vocabulary themes, AI conversation milestones) is planned.

**Image Quiz Expansion**  
`ImageQuizGame` uses a hardcoded question list (~15 items). It should pull dynamically from the `levels.json` word catalog.

---

## 4. Technical Architecture & Stack

### 4.1 Technology Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter (Dart ≥3.2.4), targets iOS, Android, Web |
| **State Management** | Provider (`provider ^6.1.2`) — `ChangeNotifier`-based providers |
| **Backend / Auth** | Firebase Auth, Cloud Firestore, Firebase Storage, Firebase Analytics |
| **AI / LLM** | Google Gemini API (via Firebase Cloud Function proxy) |
| **Image CDN** | Cloudinary (via `cloudinary_flutter` + `cloudinary_url_gen`) |
| **TTS** | `flutter_tts` (device) + Google Cloud TTS HTTP API (high quality) |
| **STT** | `speech_to_text ^7.1.0` |
| **Audio Playback** | `just_audio ^0.10.5`, `flutter_sound ^9.2.13` |
| **3D / WebView** | Three.js in `webview_flutter`; `model_viewer_plus` for `.glb` overlay |
| **Networking** | `dio ^5.7.0` + `dio_smart_retry`; `http ^1.6.0` |
| **Local Storage** | `shared_preferences ^2.2.3` |
| **Animations** | `flutter_animate ^4.5.2`, `confetti ^0.8.0` |
| **Fonts** | Google Fonts (`google_fonts ^6.3.2`) |
| **Image Loading** | `cached_network_image ^3.4.1` |
| **CI/CD** | GitHub Actions (web deploy → GitHub Pages, APK → Appetize.io, tests) |
| **Config / Secrets** | `flutter_dotenv` (native), `--dart-define` (web), `AppConfig` helper |

### 4.2 Project Structure

```
lib/
├── main.dart                    # App bootstrap, provider wiring
├── app_config.dart              # Reads all secrets from dart-define/dotenv
├── firebase_options.dart        # Auto-generated Firebase config
├── models/                      # Pure data classes (no UI)
│   ├── app_user.dart            # Firebase user
│   ├── local_user.dart          # Local profile user
│   ├── player_data.dart         # Firestore game state
│   ├── achievement.dart
│   ├── daily_mission.dart
│   ├── level_data.dart
│   ├── word_data.dart
│   ├── shop_item.dart
│   ├── quiz_item.dart
│   └── player_character.dart
├── providers/                   # ChangeNotifier state
│   ├── auth_provider.dart
│   ├── coin_provider.dart
│   ├── theme_provider.dart
│   ├── shop_provider.dart
│   ├── character_provider.dart
│   ├── daily_mission_provider.dart
│   ├── user_session_provider.dart
│   └── spark_overlay_controller.dart
├── services/                    # Business logic, no UI
│   ├── auth_service.dart
│   ├── user_data_service.dart   # Firestore CRUD
│   ├── local_user_service.dart  # SharedPrefs CRUD
│   ├── local_user_data_service.dart
│   ├── player_data_sync_service.dart
│   ├── level_repository.dart    # Loads levels.json
│   ├── word_repository.dart     # Cloudinary + cache
│   ├── level_progress_service.dart
│   ├── word_mastery_service.dart
│   ├── achievement_service.dart
│   ├── daily_reward_service.dart
│   ├── gemini_proxy_service.dart # Gemini HTTP proxy
│   ├── conversation_coach_service.dart
│   ├── adventure_story_service.dart
│   ├── practice_pack_service.dart
│   ├── ai_image_validator.dart
│   ├── kid_speech_service.dart
│   ├── spark_voice_service.dart
│   ├── google_tts_service.dart
│   ├── background_music_service.dart
│   ├── sound_service.dart
│   ├── map_bridge_service.dart  # Flutter↔JS WebView bridge
│   ├── cloudinary_service.dart
│   ├── telemetry_service.dart
│   └── onboarding_personalizer.dart
├── screens/                     # Full-page route widgets
│   ├── auth_gate.dart
│   ├── onboarding_screen.dart
│   ├── user_selection_screen.dart
│   ├── create_user_screen.dart
│   ├── sign_in_screen.dart
│   ├── character_selection_screen.dart
│   ├── map_screen.dart          # Main hub
│   ├── home_page.dart           # Word learning loop
│   ├── level_completion_screen.dart
│   ├── lightning_practice_screen.dart
│   ├── image_quiz_game.dart
│   ├── image_quiz_screen.dart
│   ├── ai_conversation_screen.dart
│   ├── ai_adventure_screen.dart
│   ├── ai_practice_pack_screen.dart
│   ├── camera_screen.dart
│   ├── shop_screen.dart
│   ├── achievements_screen.dart
│   ├── daily_missions_screen.dart
│   └── settings_screen.dart
├── widgets/                     # Reusable UI components
│   ├── living_spark.dart        # 3D Spark overlay
│   ├── achievement_notification.dart
│   ├── bouncy_button.dart
│   ├── ui/glass_card.dart
│   ├── ui/spark_button.dart
│   └── ...
└── utils/
    ├── app_theme.dart
    ├── page_transitions.dart
    └── route_observer.dart

assets/
├── data/levels.json             # Level + word definitions
├── images/words/                # 40+ local word images
├── images/map/                  # Map background + player avatar
├── audio/                       # Music + sound effects
├── map_3d/                      # Three.js WebView map
└── models/spark.glb             # 3D Spark model
```

### 4.3 Data Flow

```
User Tap → Screen → Provider.read<>() 
         → Service (business logic)
         → SharedPreferences (local) OR Firestore (cloud)
         → Provider.notifyListeners()
         → Widget rebuilds

AI Request → Screen → Service (builds prompt)
           → GeminiProxyService
           → Firebase Cloud Function (geminiProxy)
           → Google Gemini API
           → Parsed response → Screen updates UI

Word Image → WordRepository
           → SharedPreferences cache (hit?) → return cached URL
           → Cloudinary API (miss) → cache result → return URL
```

### 4.4 Security Model

- Gemini API key is **never** in the Flutter client; all Gemini calls go through a Firebase Cloud Function.
- Cloudinary and Google TTS keys are injected at build time via `--dart-define` (web) or `.env` file (native), read through `AppConfig`.
- Firebase security rules govern Firestore access per `uid`.
- No secrets are committed to the repository (`.env` is gitignored; `.env.example` provides the template).
