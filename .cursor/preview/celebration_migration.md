# Celebration migration preview (P-06)

**Status:** Parts 1–4 shipped (screen migrations complete). Epic deferred until P-09 (see level_completion TODO).

---

## ConfettiController call sites

| File | Lines (approx) | Current trigger | Proposed replacement |
|------|----------------|-----------------|-------------------|
| `lib/screens/home_page.dart` | 61, 105–106, 132, 573, 1077–1088 | Plays explosive confetti on every correct word (~1s) | See [home_page routing](#home_page-routing) below |
| `lib/screens/level_completion_screen.dart` | 33, 46–47, 84, 104–105 | 3s confetti on screen enter | **Remove** inline confetti; `big` already fires from home on last word. Epic only if chapter end (see level_completion) |
| `lib/screens/shop_screen.dart` | 24–44, 85–89, 140–144 | Confetti on successful purchase | `Celebration.fire(context, tier: CelebrationTier.small)` |
| `lib/screens/daily_missions_screen.dart` | 20–38, 57–59, 121–122 | Confetti on mission claim | `Celebration.fire(context, tier: CelebrationTier.small)` |

No other `ConfettiController` usages under `lib/` (verified via ripgrep).

---

## `home_page.dart` routing (Part 4)

### New state

- `int _attemptsForCurrentWord = 0` — reset when advancing to next word (and on level load).
- Increment on each pronunciation evaluation attempt (before/after judge).

### On correct answer

| Condition | Tier | Notes |
|-----------|------|--------|
| `_attemptsForCurrentWord == 1` | `micro` | `word: currentWord` |
| `_attemptsForCurrentWord > 1` | `small` | `burstOrigin` from word chip `RenderBox` center (optional) |
| Last word in level (`_currentIndex == _words.length - 1` or all completed) | `big` | `word`, `compliment: SparkStrings.randomCompliment()`, `coinsEarned`, `starsEarned` from level logic |

### Remove

- `late final ConfettiController _confettiController`
- `import 'package:confetti/confetti.dart'`
- `ConfettiWidget` in build stack
- `_confettiController.play()` in correct-word branch
- Direct `_soundService.playSound('success')` for correct (Celebration owns SFX per tier)

### Import

```dart
import 'package:english_learning_app/widgets/ui/_barrel.dart';
// Celebration.fire(...)
```

---

## `level_completion_screen.dart` (Part 4)

### On `initState` / first frame

```dart
if (await LevelRepository().isLastOfChapter(levelId)) {
  await Celebration.fire(context, tier: CelebrationTier.epic);
}
```

- **Else:** no `Celebration.fire` — calm summary UI only; `big` already played on home.

### Remove

- `_confettiController` field, init, dispose, `ConfettiWidget`

### New API (Part 4)

Add to `lib/services/level_repository.dart`:

```dart
Future<bool> isLastOfChapter(String levelId, {int chapterSize = N});
```

Implement against `assets/data/levels.json` ordering + chapter grouping (define `N` from product spec).

---

## Achievement / other unlocks (Part 4)

| Location | Proposal |
|----------|----------|
| `AchievementService` / toast flows | If confetti added later → `Celebration.fire(tier: small)` |
| `achievement_notification.dart` | No confetti today — no change |

---

## Provider requirement

`SoundService` is now provided in `main.dart` (`Provider<SoundService>.value`). Screens/tests that call `Celebration.fire` must have:

- `Provider<SoundService>`
- `ChangeNotifierProvider<SparkOverlayController>`

---

## String rule (P-03)

- Compliments: `SparkStrings.randomCompliment()` only.
- Buttons: `SparkStrings.continueBtn`, etc.
- No new hard-coded Hebrew in `celebration.dart` or callers.

---

## Assets added (placeholders)

| Path | Purpose |
|------|---------|
| `assets/sfx/soft_chime.mp3` | micro chime |
| `assets/sfx/pop.mp3` | small puff |
| `assets/sfx/fanfare.mp3` | big dialog |
| `assets/sfx/epic.mp3` | chapter complete |
| `assets/rive/chapter_done.riv` | epic Rive (stub UI until designer ships) |

`SoundService` falls back to `assets/audio/*` if sfx files are empty/missing (logs warning).

---

## Part 4 complete

- `home_page.dart`: tiered `Celebration.fire`, shared compliment, `_attemptsForCurrentWord`
- `level_completion_screen.dart`: confetti removed; epic TODO(P-09)
- `shop_screen.dart` / `daily_missions_screen.dart`: `CelebrationTier.small`
- `LevelRepository.isLastOfChapter` → `false` placeholder
