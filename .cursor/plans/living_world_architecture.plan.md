---
name: Living World Architecture Refactor
overview: >
  Refactor the English Learning App toward a "Living World" architecture:
  global AI companion overlay, mastery-based word progression, a richer 3D map
  bridge, glassmorphism UI, and enhanced multimodal Gemini flows.
todos: []
isProject: false
---

## Overview

This plan evolves the existing architecture into a "Living World" where Spark and the 3D map respond dynamically to the learner's journey. The refactor is staged: first models and services (safe, backward-compatible changes), then UI and interaction layers.

## Design Decisions

- **Global AI Companion (LivingSpark overlay)**
  - Keep `ConversationCoachService` as the single source of truth for conversational context and Spark "mood".
  - Introduce a lightweight provider/controller (e.g. `SparkOverlayController`) that:
    - Listens to navigation and progress events (via existing `RouteObserverService`, `LevelProgressService`, `DailyMissionProvider`).
    - Exposes a reactive state (`SparkEmotion`, visibility, contextual hints) for a global `LivingSpark` overlay.
  - Mount the overlay near the app root (e.g. in `main.dart` or a shell widget around `MaterialApp`) so it persists across screens and can react to Provider updates.

- **Mastery-Based Progress (WordData + WordRepository)**
  - Extend `WordData` with:
    - `double masteryLevel` in \[0.0, 1.0] (default `0.0`).
    - `DateTime? lastReviewed` (nullable, default `null`).
  - Keep JSON format backward-compatible by:
    - Defaulting missing fields from existing caches/remote responses.
    - Serializing `lastReviewed` as an ISO-8601 string.
  - Introduce a user-aware mastery layer:
    - New `WordMasteryService` (backed by `SharedPreferences`) keyed by `{userId}:{word}` that stores mastery and last-reviewed in small JSON blobs.
    - `WordRepository` stays responsible for loading the base word list but adds helper methods to:
      - Merge mastery data from `WordMasteryService` into `WordData` instances.
      - Provide prioritized word selections for:
        - **Daily Missions**: words with lowest mastery and/or longest time since review.
        - **Lightning Rounds**: biased to low-mastery words but with some randomness for variety.
  - Ensure existing SharedPreferences keys for word caches and level progress remain untouched; mastery uses new, versioned keys.

- **Dynamic 3D Map Bridge (MapChannel enhancements)**
  - Keep `MapScreen` as the single place that owns the `WebViewController` and the JS bridge.
  - Introduce a simple event channel from the learning flow into the map:
    - New `MapBridgeService` (or similar) as a singleton / Provider that:
      - Exposes `notifyWordCompleted({ levelId, word, masteryLevel })`.
      - Internally forwards events to the active `MapScreen`'s WebView via a registered callback.
    - `_MapScreenState` registers a bridge callback in `initState` and deregisters in `dispose`.
  - Flutter → JS contract:
    - Call `window.spawnWordAsset({...})` from Flutter when a word is marked `isCompleted`:
      - Payload fields: `levelId`, `word`, `masteryLevel`, optionally `imageUrl` or a simple `category`.
  - Update the word-completion execution path (likely in `MyHomePage` / `LevelProgressService`) to:
    - Mark the word as completed.
    - Update mastery.
    - Emit a map bridge event.

- **Enhanced UI Theme (Glassmorphism + BouncyButton)**
  - Introduce reusable UI primitives:
    - `GlassCard` / `GlassOverlay` widget that:
      - Wraps children with `BackdropFilter` (Gaussian blur), semi-transparent gradients, and soft borders.
      - Is used for overlays, banners, stat pills, and modal cards instead of ad-hoc `Container` styling.
    - `SparkButton` (or similar) as the primary button abstraction that:
      - Internally wraps its content in `BouncyButton`.
      - Centralizes color, shape, and typography consistent with the app theme.
  - Incrementally migrate:
    - Overlays and cards on `MapScreen` (stats pill, info banner, AI tools menu) to `GlassCard`.
    - Primary action buttons in key flows (levels, missions, AI screens) to `SparkButton` to guarantee haptics and consistent motion.
  - Keep raw `BouncyButton` available for niche/tiny cases but prefer `SparkButton` for most CTAs.

- **Multimodal Gemini Integration ("Scene Description" mode)**
  - Extend `GeminiProxyService` with a new high-level method, e.g. `describeSceneAndQuizChild(...)`:
    - Sends `mode: 'identify'` or a new `mode: 'scene_description'` payload (configurable, but defaulting to a new mode string for future-proofing).
    - Includes a strongly-typed prompt and system instruction tailored for:
      - Describing the whole scene in simple Hebrew with key English nouns.
      - Asking the child to point out or name objects in English.
    - Parses back structured JSON (e.g. `description`, `targetObjects`, `quizQuestions`) if available; otherwise, falls back to plain text.
  - Update `AiImageValidator` (or the camera flow using `GeminiProxyService`) to:
    - Prefer the new scene description method over simple single-word validation when in "explore" / discovery mode.
    - Preserve existing word-validation behavior where strictly required (e.g. tests, current missions) to stay backward compatible.

- **Backward Compatibility and Safety**
  - No breaking changes to existing SharedPreferences keys for:
    - Coins, stars, character, daily streak, or level progress.
  - New mastery and Living World keys are additive and namespaced.
  - Existing test suites for `WordData`, `WordRepository`, `conversation_coach_service`, and map behavior are updated rather than removed.

## Files to Create / Modify

### Models
- **Modify** `lib/models/word_data.dart`
  - Add `masteryLevel` and `lastReviewed` fields.
  - Update `fromJson` / `toJson` with safe defaults and ISO-8601 timestamp handling.
  - Update unit tests in `test/models/word_data_test.dart`.

### Services / Providers
- **Create** `lib/services/word_mastery_service.dart`
  - `getMasteryForWord(userId, levelId, word) → (masteryLevel, lastReviewed)`
  - `updateMasteryForWord(...)` with simple capped update rules.
  - Backed by `SharedPreferences` with versioned, namespaced keys.
- **Modify** `lib/services/word_repository.dart`
  - Add optional dependency on `WordMasteryService`.
  - Add helpers:
    - `Future<List<WordData>> loadWordsWithMastery(...)`
    - `List<WordData> prioritizeForDailyMissions(List<WordData> words, {int limit})`
    - `List<WordData> prioritizeForLightningRound(List<WordData> words, {int limit})`
  - Ensure existing behavior (without mastery) still works as before.
- **Modify** `lib/services/level_progress_service.dart`
  - Hook into word-completion logic to:
    - Update word mastery via `WordMasteryService`.
    - Emit completion events for map and Spark overlay.
- **Create** `lib/services/map_bridge_service.dart`
  - Singleton / Provider exposing:
    - `registerMapCallbacks({required void Function(Map<String, dynamic>) onWordCompleted})`
    - `notifyWordCompleted({required String levelId, required String word, double masteryLevel})`.
  - Internally implemented via a simple `ChangeNotifier` or callback registry.
- **Modify** `lib/screens/map_screen.dart`
  - Register bridge callbacks in `_initWebView` / `initState`.
  - Implement `spawnWordAsset` JS call via `_webViewController.runJavaScript`.
  - Ensure it is safe when WebView is not yet ready.
- **Modify** camera / image validation service(s), likely:
  - `lib/services/ai_image_validator.dart`
  - Any camera-related screens invoking Gemini:
    - Wire them to the new `describeSceneAndQuizChild` method where appropriate.
- **Modify** `lib/services/gemini_proxy_service.dart`
  - Add `describeSceneAndQuizChild(...)` with:
    - `mode: 'scene_description'` (or configurable).
    - Rich but safe system instructions for scene description + object-quiz behavior.
    - Parsing/validation logic; reuse `_postJson`.

- **Global AI Companion**
  - **Create** `lib/providers/spark_overlay_controller.dart`
    - Holds current `SparkEmotion`, visibility flag, and optional context text.
    - Listens to:
      - Navigation changes (via a callback from `RouteObserverService` or a thin integration in `main.dart`).
      - Level completion events (via `LevelProgressService` / `MapBridgeService`).
  - **Modify** `lib/services/conversation_coach_service.dart`
    - Optionally expose hooks to inform the overlay about conversation state (e.g. thinking, celebrating, idle).

### UI / Widgets
- **Modify** `lib/widgets/living_spark.dart`
  - Make it stateless but drive its state from `SparkOverlayController` via `Consumer`.
  - Ensure it is visually ready for glassmorphism overlays (transparent background, fits nicely in corners).
- **Create** `lib/widgets/glass_card.dart`
  - A reusable glassmorphism container using `BackdropFilter` + blur + gradient.
- **Create** `lib/widgets/spark_button.dart`
  - Wraps `BouncyButton`, applies app-wide button styling and ensures haptics on by default.
- **Modify** selected screens to adopt glassmorphism and `SparkButton`:
  - `lib/screens/map_screen.dart`:
    - `_StatsPill`, `_InfoBanner`, AI tools menu bottom sheet → `GlassCard`-based.
  - Key learning / AI screens (in later passes) to use `SparkButton` for primary actions.
- **Modify** `lib/main.dart` or the root app shell:
  - Add a top-level overlay layer (e.g. `Stack` or `Overlay` widget) hosting the `LivingSpark` companion.
  - Wire it to `SparkOverlayController`.

### Tests
- **Models**
  - Update `test/models/word_data_test.dart` for mastery fields.
- **Services**
  - New tests for `WordMasteryService` (persistence, default values).
  - Update `test/services/word_repository_test.dart` to cover:
    - Loading with mastery overlay.
    - Prioritization helpers.
  - Extend `test/services/gemini_proxy_service_test.dart` for scene description mode.
  - Add tests for `MapBridgeService` behavior (registration, forwarding).
- **UI**
  - Snapshot / golden or widget tests for:
    - `GlassCard` basic rendering.
    - `SparkButton` using `BouncyButton`.
    - `LivingSpark` overlay presence in root widget tree.

## Data / Persistence Changes

- **New SharedPreferences keys**
  - `word_mastery.v1.{userId}.{levelId}.{word}` → JSON object with:
    - `masteryLevel` (double)
    - `lastReviewed` (ISO-8601 string)
  - `map_bridge.recent_word_events` (if needed, debug-only or for lightweight caching).
- **Backward compatibility**
  - Do not alter existing keys:
    - Word cache keys in `WordRepository` (v2 cache keys remain as-is).
    - Level/star keys in `LevelProgressService` and `LocalUserDataService`.
  - All new keys are additive and graceful: if missing, the system assumes:
    - `masteryLevel = 0.0`
    - `lastReviewed = null`

## Testing Strategy

- **Phase 2 (per feature unit)**
  - After modifying each service/model file:
    - Run targeted tests:
      - `flutter test test/models/word_data_test.dart`
      - `flutter test test/services/word_repository_test.dart`
      - `flutter test test/services/gemini_proxy_service_test.dart`
      - `flutter test test/services/conversation_coach_service_test.dart`
      - `flutter test test/services/level_progress_service_test.dart`
    - Run static analysis for touched files using `flutter analyze` scoped to `lib/models` and `lib/services`.
- **Phase 3 (regression)**
  - Run the full test suite:
    - `flutter test`
  - Manually smoke-test:
    - Word learning flow (ensure words still load, complete, and coins/stars behave).
    - Map navigation + 3D map WebView (enter level, complete a word, verify 3D asset spawn JS call in logs).
    - Camera-based image tasks using the new scene description mode.
    - Global LivingSpark overlay across navigation.

## Risks / Open Questions

- **Backend support for `scene_description` mode**
  - Assumption: the Firebase Function can accept a new `mode` or can treat `scene_description` as a specialized `identify` case.
  - Mitigation: implement the client to be resilient; if backend does not recognize the mode, it should fail gracefully and fall back to legacy behavior.
- **Per-word mastery storage granularity**
  - Assumption: per `(userId, levelId, word)` is sufficient and performant in SharedPreferences for the expected word counts.
  - If performance suffers, consider migrating mastery to Firestore for Firebase users in a future iteration.
- **Scope of "all overlays and cards"**
  - This plan focuses on the most visible overlays first (map, missions, AI sheets). A follow-up pass may be needed for long-tail screens.

## Implementation Order (High-Level)

1. **Models & Persistence**
   - Extend `WordData` and its tests.
   - Implement `WordMasteryService` with tests.
2. **WordRepository Integration**
   - Add mastery-aware helpers and prioritization methods + tests.
3. **Map Bridge & Level Progress Hooks**
   - Add `MapBridgeService`, register in `MapScreen`, and wire into word completion and mastery updates.
4. **Gemini Scene Description Mode**
   - Extend `GeminiProxyService` and update camera/image validation services + tests.
5. **Global Spark Overlay**
   - Implement `SparkOverlayController`, global overlay wrapper, and hook it into navigation/progress + `ConversationCoachService`.
6. **Glassmorphism & Button Unification**
   - Introduce `GlassCard` and `SparkButton`, migrate key overlays and CTAs to use them.

