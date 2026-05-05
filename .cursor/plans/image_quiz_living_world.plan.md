# Image Quiz Mini-game (Living World) — Plan

## Overview

Implement the Image Quiz screen at `lib/screens/image_quiz_screen.dart` that uses the Living World architecture: WordRepository + WordMasteryService for spaced repetition, LevelProgressService.markWordCompleted() to drive mastery and MapBridgeService, CoinProvider for rewards, and SparkOverlayController + GlassCard/SparkButton for UI.

## Design decisions

- **New file**: `lib/screens/image_quiz_screen.dart` (per user request). Existing `image_quiz_game.dart` remains for now; navigation from HomePage will switch to the new screen when opened from a level (levelId + wordsForLevel available).
- **Word selection**: Screen receives `levelId` and `wordsForLevel`. On load, call WordRepository.loadWords(..., fallbackWords: wordsForLevel, cacheNamespace: levelId). Then use WordMasteryService (with userId from UserSessionProvider) to merge mastery into each WordData, sort by masteryLevel ascending (prioritize &lt; 0.5), and use that ordered list for quiz questions.
- **Quiz mechanics**: One target word (show text + play audio via SparkVoiceService/FlutterTts). Four image options: one correct (target’s image), three wrong (random other words from the same level list). Build image URL from WordData: prefer existing imageUrl; else if publicId present use Cloudinary URL `https://res.cloudinary.com/{cloudName}/image/upload/{publicId}`. Use CachedNetworkImage for network URLs; for asset/local paths use Image.asset or Image.file as appropriate.
- **On correct answer**: Call LevelProgressService.markWordCompleted(userId, levelId, word, isLocalUser) [which triggers WordMasteryService + MapBridgeService.emitWordMastered], CoinProvider.addCoins(reward), SparkOverlayController.markCelebrating(). After a short delay (e.g. 2s), call markIdle() (or let map_screen listener already do that).
- **UI**: GlassCard wrapping the question (target word + speaker); four options as SparkButton or tappable cards with CachedNetworkImage. Spark: setEmotion(SparkEmotion.happy) when screen is shown (or on init); markCelebrating() on correct.
- **UserId**: Read from Provider of UserSessionProvider; currentUser.id and currentUser.isGoogle → isLocalUser. If no current user, use a fallback id (e.g. 'local_guest') and isLocalUser: true so progress is still stored.

## Files to create

| File | Description |
|------|-------------|
| `lib/screens/image_quiz_screen.dart` | New Image Quiz screen: word selection via repo+mastery, 1 word + 4 images, integration with LevelProgressService/CoinProvider/SparkOverlayController, GlassCard + SparkButton, CachedNetworkImage for Cloudinary. |
| `test/screens/image_quiz_screen_test.dart` | Unit/widget tests: loads with mock providers, correct answer triggers markWordCompleted and addCoins, Spark controller receives celebrating. |

## Files to modify

| File | Description |
|------|-------------|
| `lib/screens/home_page.dart` | Import ImageQuizScreen; in game menu, navigate to ImageQuizScreen(levelId: widget.levelId, wordsForLevel: widget.wordsForLevel) instead of ImageQuizGame() when opening Image Quiz. |

## Database/schema changes

None (uses existing SharedPreferences via LevelProgressService, WordMasteryService, WordRepository).

## Testing strategy

- **image_quiz_screen_test.dart**: Pump ImageQuizScreen with mock WordRepository (return fixed list), mock LevelProgressService (verify markWordCompleted called with correct params on correct tap), mock CoinProvider (verify addCoins), mock SparkOverlayController (verify markCelebrating), mock UserSessionProvider (currentUser). Test: correct answer flow; optional: wrong answer does not call markWordCompleted.
- **Existing**: Keep image_quiz_game_test.dart unchanged (still tests legacy ImageQuizGame).

## Risks / open questions

- If a level has fewer than 4 words, we need at least 4 options: either allow repeating options or show fewer choices (e.g. 2–3). Plan: require at least 4 words in the level for the quiz to be playable; otherwise show an empty state or “Need more words” message.
- Cloudinary publicId format: assume publicId is the full resource path (e.g. `folder/name`); URL is `https://res.cloudinary.com/{cloudName}/image/upload/{publicId}`. No format extension needed for Cloudinary to serve.
