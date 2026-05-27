# SparkOrb migration — preview (PART 3 steps 11–12 pending approval)

**Status:** PART 1–3 complete (screen migrations applied).

---

## Summary

| Item | Detail |
|------|--------|
| Widget | `lib/widgets/ui/spark_orb.dart` |
| Barrel | `lib/widgets/ui/_barrel.dart` → `export 'spark_orb.dart';` |
| Tests | `test/widgets/ui/spark_orb_test.dart` |
| Deprecated | `lib/widgets/animated_microphone.dart` (`@Deprecated`) |
| `AnimatedMicrophone` call sites in `lib/` | **0** (widget exists but unused in screens today) |
| Mic UI to replace | `home_page.dart` `_SmartMicButton`, `ai_conversation_screen.dart` inline mic |

---

## PART 1 + PART 2 + step 13 (shipped)

| Artifact | Path |
|----------|------|
| `SparkOrb` + `OrbState` | `lib/widgets/ui/spark_orb.dart` |
| Semantics strings | `lib/l10n/spark_strings.dart` → `orbSemanticsIdle`, `orbSemanticsSuccess` |
| Barrel export | `lib/widgets/ui/_barrel.dart` |
| Widget tests | `test/widgets/ui/spark_orb_test.dart` |
| Deprecation | `lib/widgets/animated_microphone.dart` |

Design QA: wrap `SparkOrb.preview()` in a `Scaffold` for a 4-state gallery.

---

## 1. `AnimatedMicrophone` references

| File | Line | Notes |
|------|------|-------|
| `lib/widgets/animated_microphone.dart` | 4–5 | Definition only — **deprecated**, not deleted |
| `lib/screens/*.dart` | — | **No imports** today |
| `gemini_prompts/step2_home_page_redesign.md` | 64 | Doc only — ignore |

---

## 2. `home_page.dart` — `_SmartMicButton` (~L1607–1695)

**Current:** 72×72 circular `Container` + `AnimatedBuilder` scale + `BouncyButton` wrapper (no `AnimatedMicrophone`).

**Call site (parent):** ~L1058–1063

```dart
child: _SmartMicButton(
  isListening: _isListening,
  isEvaluating: _isEvaluating,
  onPressed: _handleSpeech,
  animation: _micPulseController,
),
```

### Proposed `_SmartMicButton` inner replacement

```dart
// KEEP BouncyButton when idle; skip bounce when listening/evaluating (existing rule).

final now = DateTime.now();
final orbState = isListening
    ? OrbState.listening
    : isEvaluating
        ? OrbState.thinking
        : (lastResultWasSuccess &&
                now.difference(lastResultAt).inMilliseconds < 1200)
            ? OrbState.success
            : OrbState.idle;

final orb = SparkOrb(
  state: orbState,
  soundLevel: soundLevel,
  onTap: null, // BouncyButton handles tap
  size: 144,
);

// Replace Container/AnimatedBuilder column orb with:
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    orb,
    const SizedBox(height: 8),
    Text(label, /* existing label style */),
  ],
);
```

### New / threaded state in `_MyHomePageState`

| Field | Status | Purpose |
|-------|--------|---------|
| `_soundLevel` | **exists** (~L83) | Pass to `SparkOrb.soundLevel` |
| `_isListening` | exists | `OrbState.listening` |
| `_isEvaluating` | exists | `OrbState.thinking` |
| `_lastResultSuccess` | exists as `_lastResultSuccess` (~L95) | Success gate |
| `_lastResultAt` | **add** | `DateTime?` set in `_showFeedback` / evaluation `setState` when result arrives |
| `_micPulseController` | **may remove** from mic UI | Pulse moves into `SparkOrb` rings/swell |

**`_SmartMicButton` signature change (proposed):**

```dart
class _SmartMicButton extends StatelessWidget {
  final bool isListening;
  final bool isEvaluating;
  final bool lastResultWasSuccess;
  final DateTime? lastResultAt;
  final double soundLevel;
  final VoidCallback onPressed;
  // drop: Animation<double> animation
}
```

**Imports:** `import 'package:english_learning_app/widgets/ui/spark_orb.dart';` (or `_barrel.dart`).

---

## 3. `ai_conversation_screen.dart` — mic (~L661–691)

**Current:** `GestureDetector` → `AnimatedBuilder` + grey/red circular `Container` + `Icons.mic` / `Icons.mic_none`.

| File | Line | Pattern |
|------|------|---------|
| `ai_conversation_screen.dart` | 662–690 | Custom mic container |

### Proposed replacement

```dart
SparkOrb(
  state: _isListening
      ? OrbState.listening
      : _isBusy
          ? OrbState.thinking
          : OrbState.idle,
  soundLevel: _soundLevel,
  onTap: !_speechReady || _isBusy ? null : _toggleListening,
  size: 96, // tune to match bottom bar
),
```

### New state in `_AiConversationScreenState`

| Field | Status | Purpose |
|-------|--------|---------|
| `_soundLevel` | **add** `double _soundLevel = 0.0` | Mic amplitude |
| `_isBusy` / `_isListening` | exist | Map to `OrbState` |
| Success punch | optional v2 | No `_lastResult*` today — add later if quiz feedback lands here |

**Plumb sound level** (in `initState` / speech setup, mirror `home_page.dart`):

```dart
_kidSpeechService.onSoundLevelChange = (level) {
  if (!mounted) return;
  setState(() => _soundLevel = level);
};
```

Clear on dispose / stop listening if home page does.

**May remove:** `_micPulseController` if unused after migration.

---

## 4. Acceptance checklist (post-migration)

- [ ] Tap mic on home → coral rings + orb swells with louder speech (`_soundLevel`)
- [ ] Correct answer → mint success punch within ~1.2s of result
- [ ] Evaluating → plum orb + orbiting dots
- [ ] Reduce motion → static color + slow opacity pulse only
- [ ] `flutter analyze` clean on touched screens
- [ ] `AnimatedMicrophone` still compiles with deprecation warning if any import remains

---

## 5. Evidence (PART 1 + 2)

```
flutter test test/widgets/ui/spark_orb_test.dart
00:01 +4: All tests passed!

flutter analyze lib/widgets/ui/spark_orb.dart lib/widgets/ui/_barrel.dart \
  lib/widgets/animated_microphone.dart lib/l10n/spark_strings.dart \
  test/widgets/ui/spark_orb_test.dart
No issues found! (ran in 8.8s)
```

---

**Migration applied:** `home_page.dart` `_SmartMicButton` + `ai_conversation_screen.dart` input bar mic.
