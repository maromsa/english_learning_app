# Achievement System Phase 2/3 — Plan

## Overview

Implement the Achievement System to reward the child's progress: extend the achievement model with `requirementValue` and `title`, refactor the achievement service to track and persist the four required achievements (First Word Learned, Quiz Streak, Coin Collector, Map Builder), add a Trophy Room screen with a scrollable grid of GlassCards, and integrate unlock flow with Spark celebration and a glassmorphism toast.

## Design decisions

- **Model**: Add `title` (display name; keep `name` as deprecated alias for backward compatibility during migration, then use `title` everywhere) and `requirementValue` (int, optional) to `Achievement`. Existing code uses `name` → we will add `title` and migrate usages to `title`; tests and notification will use `title`.
- **Achievement IDs**: Use `first_word_learned`, `quiz_streak_5`, `coin_collector`, `map_builder`. Replace/align existing `first_correct` → `first_word_learned`, `streak_5` → `quiz_streak_5`; add `coin_collector` (500 coins), `map_builder` (10 owned map items). Keep `add_word` and `level_1_complete` for future use.
- **Persistence**: Continue using SharedPreferences under keys `achievement_<id>`; service already persists; ensure `loadAchievements()` runs at startup and after user switch.
- **Event sources**:
  - **First Word Learned**: Unlock when `checkForAchievements` is called with “first correct” semantics. Keep current behavior: call from Home (on correct) and from Image Quiz (on correct); first time we call and achievement is locked we unlock it.
  - **Quiz Streak (5 in a row)**: Call `checkForAchievements(streak: currentStreak)` from Image Quiz after each correct answer (already done on Home; add to Image Quiz).
  - **Coin Collector (500)**: AchievementService listens to CoinProvider. Inject CoinProvider into AchievementService; on notify, if `coins >= 500` unlock `coin_collector`.
  - **Map Builder (10 items)**: Same listener; if `ownedShopItemsCount >= 10` unlock `map_builder`. Expose `ownedShopItemsCount` on CoinProvider.
- **Spark + toast on unlock**: Inject `SparkOverlayController` into AchievementService. When unlocking, call `markCelebrating()` then invoke the existing unlocked callback (so UI can show toast). Achievement notification widget: restyle with GlassCard (glassmorphism), keep 3s auto-dismiss. Callback is today set only from MyHomePage; we will also set it from a place that has overlay context (e.g. AuthGate or a root overlay wrapper) so the toast shows when unlock happens from Image Quiz or after coins/owned change. Alternatively, set callback once from AuthGate when building the main child, so any screen can show the overlay.
- **Trophy Room**: New screen `AchievementsScreen` (The Trophy Room): scrollable grid of GlassCards; each card shows icon, title, description, progress if applicable; unlocked = full color, locked = grayscale + lock icon. Navigation: add to Map bottom nav as 5th item (תגיות/הישגים) opening `AchievementsScreen`.

## Files to create

| File | Description |
|------|-------------|
| `lib/screens/achievements_screen.dart` | Trophy Room: AppBar, scrollable grid of GlassCards; each card uses Achievement (title, description, icon, isUnlocked, requirementValue); locked cards grayscale + lock icon; unlocked colorful. Consumes AchievementService via Provider. |

## Files to modify

| File | Description |
|------|-------------|
| `lib/models/achievement.dart` | Add `title` (String), `requirementValue` (int, optional). Keep `name` as getter forwarding to `title` for backward compatibility. |
| `lib/services/achievement_service.dart` | Accept optional `CoinProvider` and `SparkOverlayController` in constructor. Define achievements list with ids: first_word_learned, quiz_streak_5, coin_collector, map_builder (and optionally add_word, level_1_complete). Add listener to CoinProvider: on notify check coins >= 500 and ownedShopItemsCount >= 10; call unlockAchievement for coin_collector / map_builder. On unlock call `sparkOverlayController?.markCelebrating()` then callback. Update `checkForAchievements` to use new ids and first-word semantics. Ensure `loadAchievements()` runs in ctor and when user changes. |
| `lib/providers/coin_provider.dart` | Add getter `int get ownedShopItemsCount => _ownedShopItemIds.length;` (or expose length of owned list). |
| `lib/widgets/achievement_notification.dart` | Use GlassCard for container; keep 3s auto-dismiss; use `achievement.title` and existing icon/description. |
| `lib/screens/home_page.dart` | Use `achievement.title` if present else `achievement.name`. Call `SparkOverlayController.markCelebrating()` in achievement callback (if we don’t do it in service). Ensure callback is set so overlay shows from any screen (callback runs in service now; overlay is inserted by whoever sets the callback – we’ll set it from a widget that has overlay context; see integration below). |
| `lib/main.dart` | Create `SparkOverlayController` and pass it plus `CoinProvider` into `AchievementService` constructor. Provide both via `ChangeNotifierProvider.value`. |
| `lib/screens/map_screen.dart` | Add 5th bottom nav destination: Trophy Room (icon: Icons.emoji_events), label 'הישגים'. On tap push `AchievementsScreen`. Adjust `_handleBottomNav` for new index mapping (Shop=1, Trophy=2, AI=3, Missions=4 or keep order: Map, Shop, AI, Missions, Trophy). |
| `lib/screens/image_quiz_screen.dart` | After correct answer and updating `_streak`, call `context.read<AchievementService>().checkForAchievements(streak: _streak)` (and firstWordLearned if needed). Inject AchievementService. |
| `lib/screens/auth_gate.dart` | When building the main app content (MapScreen/Home flow), set achievement callback once so the overlay is inserted at root: get Overlay.of(context) from the navigator context and show AchievementNotification in overlay; call SparkOverlayController.markCelebrating in callback. So when achievement unlocks from Image Quiz or from service (coins/map), callback runs and overlay shows. Alternatively set callback in a widget that is always mounted above the stack (e.g. MaterialApp.builder). Set in AuthGate after we have a context that has overlay (e.g. in build of the child that contains Navigator). |

## Database/schema changes

None (SharedPreferences only).

## Testing strategy

- **Unit tests**
  - `lib/models/achievement.dart`: test that `title` and `requirementValue` are stored and that `name` getter returns `title`.
  - `lib/services/achievement_service_test.dart`: update tests to use new achievement ids (`first_word_learned`, `quiz_streak_5`); add tests for coin_collector (when coins >= 500), map_builder (when ownedShopItemsCount >= 10); test that listener is called when coins/owned change (mock CoinProvider). Test that unlockAchievement calls SparkOverlayController.markCelebrating when provided.
- **Widget test** (optional): AchievementsScreen shows grid and locked/unlocked state from AchievementService.
- **Manual**: Unlock each achievement from the app and verify toast + Spark celebration; open Trophy Room and verify list and navigation.

## Risks / open questions

- **Callback context**: Achievement callback is currently set in MyHomePage; when user unlocks from Image Quiz, MyHomePage may still be in the tree (we pushed Image Quiz from Home or from Map). So overlay.insert might still work if we use the root overlay. To be safe, set the achievement callback from a place that is always mounted when the user is in the app (e.g. AuthGate’s child builder, or MaterialApp.builder). We’ll set it in AuthGate when building the post-login child so the overlay context is the same for the whole session.
- **Backward compatibility**: Existing prefs keys `achievement_first_correct`, `achievement_streak_5` etc. If we rename to first_word_learned and quiz_streak_5, we lose existing unlocks. Option: keep old ids first_correct and streak_5 in the list and only add new ones; or migrate on load (if achievement_first_correct true, set achievement_first_word_learned true). We’ll keep old ids in the definition (first_correct, streak_5) and use display title "First Word Learned" / "Quiz Streak" so we don’t break persistence. So: id stays first_correct, title "First Word Learned"; id stays streak_5, title "Quiz Streak". Same for add_word. Add coin_collector and map_builder with requirementValue.
- **LevelProgressService**: No change needed for “first word learned”; we only need to call checkForAchievements from Home and Image Quiz. LevelProgressService is already used to mark words completed; we don’t need to listen to it for achievements in this phase.

## Summary

- Model: add `title`, `requirementValue`; keep `name` as alias.
- Service: inject CoinProvider + SparkOverlayController; listen to CoinProvider; add coin_collector and map_builder; on unlock call markCelebrating and callback.
- CoinProvider: add `ownedShopItemsCount`.
- Main: create Spark + AchievementService with deps, provide both.
- AchievementsScreen: new Trophy Room with grid of GlassCards.
- AchievementNotification: glassmorphism (GlassCard), 3s.
- Map: add Trophy nav item; Image Quiz: call checkForAchievements on correct.
- AuthGate (or root): set achievement callback so overlay shows from any screen.
