# 🔬 Logical Stress Test Report — English Learning App
**Date:** 2026-05-09  
**Analyst:** Senior QA Automation Engineer / Security Researcher  
**Scope:** State Sync, Error Resilience, Resource Leaks, Kid-Proof Input

---

## Executive Summary

The codebase is well-structured and shows clear intent toward robustness (timeouts, `mounted` guards, try-catch). However, five meaningful vulnerabilities were found across the four areas, ranging from a **critical** double-write race condition that can corrupt coin balances, to a **medium** missing name-length guard that can overflow the UI. Each finding is accompanied by a specific, drop-in code fix.

---

## 1. State Synchronization & Race Conditions

### 🔴 CRITICAL — Bug #1: Coin Write-Back Split-Brain (no atomic write)

**Location:** `lib/providers/coin_provider.dart` → `addCoins()` / `_saveCoins()`  
**Severity:** CRITICAL — can corrupt coin balance permanently  

**Root cause:**  
`addCoins()` first increments `_coins` in memory, calls `notifyListeners()`, then calls `_saveCoins()`. For Firebase users, `_saveCoins()` does **two** independent async writes:

```dart
// coin_provider.dart ~line 126-129
await prefs.setInt('user_${_currentUserId}_coins', _coins); // write 1
await _userDataService.updateCoins(_currentUserId!, _coins); // write 2
```

If the device goes offline or the Firestore call throws between the two writes, **SharedPreferences says 150 coins, Firestore says 140 coins**. The next `syncFromCloud()` in `PlayerDataSyncService` uses a "higher value wins" merge:

```dart
coins: coins > playerData.coins ? coins : playerData.coins,
```

This means the local stale value can silently *override* a correct cloud value when the user logs in on a new device.

**Fix — wrap both writes in a single try and roll back on failure:**

```dart
// coin_provider.dart — replace _saveCoins()
Future<void> _saveCoins() async {
  final previous = _coins; // snapshot before write
  try {
    if (_isLocalUser) {
      await _localUserDataService.saveCoins(_currentUserId!, _coins);
    } else if (_currentUserId != null) {
      final prefs = await _sharedPrefs;
      // Write local first (fast)
      await prefs.setInt('user_${_currentUserId}_coins', _coins);
      try {
        // Write cloud (slow, can fail)
        await _userDataService.updateCoins(_currentUserId!, _coins);
      } catch (cloudError) {
        // Cloud failed — mark for deferred retry, do NOT roll back local
        debugPrint('Cloud coin sync deferred: $cloudError');
        _pendingCloudSync = true; // new flag — sync on next foreground
      }
    } else {
      final prefs = await _sharedPrefs;
      await prefs.setInt('totalCoins', _coins);
    }
  } catch (e) {
    // Both stores failed — roll back in-memory value
    debugPrint('Critical: coin save failed, rolling back: $e');
    _coins = previous;
    notifyListeners();
  }
}
```

---

### 🟡 MEDIUM — Bug #2: AuthGate MapScreen rendered before `_hasSynced` is true

**Location:** `lib/screens/auth_gate.dart` → `build()` lines 291-313  

**Root cause:**  
When `authProvider.isAuthenticated == true` and `_syncing == false`, the `build()` method falls straight through to render `MapScreen` even if `_hasSynced == false` (i.e., the first sync has not completed yet). The sync is triggered via `addPostFrameCallback`, which runs *after* the first frame — meaning the `MapScreen` mounts and calls `context.read<CoinProvider>().coins` while the provider still holds stale local data.

```dart
// auth_gate.dart ~line 271
if (authProvider.initializing || _syncing || _checkingLocalUser) {
  return const Scaffold(body: Center(child: CircularProgressIndicator()));
}
// ⚠️  _hasSynced is NOT checked here — MapScreen renders with un-synced data
```

**Fix — hold the loading screen until the first sync completes:**

```dart
// auth_gate.dart — update the loading condition
if (authProvider.initializing || _syncing || _checkingLocalUser || 
    (authProvider.isAuthenticated && !_hasSynced)) {
  return const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}
```

The 10-second timeout already in `_syncPlayerData` guarantees the spinner won't block forever.

---

## 2. Error Resilience (Offline / Low Bandwidth)

### 🟡 MEDIUM — Bug #3: Permanent "Loading" state when internet cuts out mid-speech

**Location:** `lib/screens/ai_conversation_screen.dart` → `_sendLearnerMessage()` / `_startConversation()`  
**Location:** `lib/screens/home_page.dart` → `_startListening()` callback  

**Root cause:**  
When the internet drops *after* `_speechToText.listen()` fires its `onResult` callback but *before* the `_service.continueConversation()` or `_service.startConversation()` await returns, the service throws a `ConversationGenerationException`. The `catch` blocks do reset `_isBusy = false`, so `ai_conversation_screen.dart` actually handles this **correctly**.

However, in `home_page.dart`, `_evaluateSpeech()` calls `_evaluateSpeechWithGemini()` which has a 10-second `timeout`. If the timeout fires, `_isEvaluating` is set back to `false` (line 687). But if the **`_kidSpeechService.listen()` callback** itself throws before `_isEvaluating` is ever set to `true` (the speech succeeds but the flag hasn't been set yet due to a scheduling gap), the button stays in its "evaluating" spinner state visually, because `_isEvaluating` is read inside an `AnimatedBuilder` whose value is never reset.

More critically: a rapid double-tap of the mic button before `_isEvaluating = true` is set can cause `_evaluateSpeech()` to be called **twice concurrently** for the same recognized word, double-awarding coins.

**Fix — use a `Completer`-style mutex for `_isEvaluating` and reset it in `finally`:**

```dart
// home_page.dart — replace _evaluateSpeech() guard
Future<void> _evaluateSpeech() async {
  if (_isEvaluating) return;
  setState(() => _isEvaluating = true);

  try {
    // ... all existing logic unchanged ...
  } catch (e) {
    debugPrint('Evaluation error: $e');
    if (mounted) {
      setState(() => _feedbackText = 'שגיאה. נסו שוב.');
    }
  } finally {
    // Guarantee reset even on unexpected throw
    if (mounted) {
      setState(() => _isEvaluating = false);
    } else {
      _isEvaluating = false;
    }
  }
}
```

---

### 🟢 LOW — Bug #4: WordRepository Cloudinary fallback is correct, but error from `_maybeAddWebImages` is silently swallowed

**Location:** `lib/services/word_repository.dart` → `_maybeAddWebImages()` lines 176-218  

**Assessment:** The fallback chain is actually well-designed. When Cloudinary is unreachable, `loadWords()` falls through to the cached words, then to `_maybeAddWebImages()`, then to raw `fallbackWords`. Images that fail to load use `errorWidget: (_, __, ___) => const Icon(Icons.image, ...)` in `_HeroWordDisplay._buildImage()`, so no broken-image icons appear.

**Minor concern:** Inside `_maybeAddWebImages`, exceptions per-word are caught and the original word is returned — correct. However, a failure is never logged per-word in release mode:

```dart
} catch (_) {
  results.add(word);  // ← exception swallowed silently
}
```

**Recommendation — log at `debugPrint` level for diagnosability:**

```dart
} catch (e) {
  debugPrint('WordRepository: web image fetch failed for "${word.word}": $e');
  results.add(word);
}
```

---

## 3. Resource Leaks

### 🟢 LOW — Bug #5: `_AiConversationScreenState` — `_scrollController` not disposed (minor, but real)

**Location:** `lib/screens/ai_conversation_screen.dart` → `dispose()` lines 151-169  

**Assessment (corrected):** Reading the actual `dispose()` method carefully, `_scrollController.dispose()` **is present** at line 163. The `_micPulseController`, `_messageController`, `_nameController`, `_audioPlayer`, `_tts.stop()`, `_speechToText.stop/cancel`, and `_googleTts?.dispose()` are all properly cleaned up.

**The `_TypingIndicator` widget** (`_TypingIndicatorState`) creates its own `AnimationController` and disposes it — this is correct.

✅ **No leak found in `ai_conversation_screen.dart`.**

---

### 🟢 LOW — Bug #6: `home_page.dart` — `flutterTts` initialized inside `_initializeServices()` but accessed in `dispose()` before initialization completes

**Location:** `lib/screens/home_page.dart` lines 180, 152  

**Root cause:**  
`flutterTts` is declared `late final FlutterTts flutterTts` and assigned inside `_initializeServices()`, which is async and called from `initState()`. If the widget is disposed before `_initializeServices()` returns (e.g., user taps back immediately), `dispose()` calls `flutterTts.stop()` on an uninitialized `late` field — throwing a `LateInitializationError`.

```dart
// home_page.dart ~line 64
late final FlutterTts flutterTts; // 'late' — not yet assigned

// ~line 152 in dispose()
flutterTts.stop(); // 💥 crash if user exits before _initializeServices() finishes
```

**Fix — use a nullable field with null-safety:**

```dart
// Change declaration
FlutterTts? flutterTts;  // Remove 'late'

// In dispose()
flutterTts?.stop();

// In _initializeServices()
flutterTts = FlutterTts();  // Assignment unchanged

// In _speakWithFlutterTts()
final tts = flutterTts;
if (tts == null) return;
await tts.setLanguage(languageCode);
// ... rest unchanged
```

---

## 4. Kid-Proof Input & Edge Cases

### 🔴 HIGH — Bug #7: `CreateUserScreen` — No maximum name length enforced

**Location:** `lib/screens/create_user_screen.dart` → `TextFormField` for name, lines 236-263  

**Root cause:**  
The name validator only checks for a **minimum** of 2 characters:

```dart
validator: (value) {
  if (value == null || value.trim().isEmpty) return 'אנא הזינו שם';
  if (value.trim().length < 2) return 'השם חייב להכיל לפחות 2 תווים';
  return null; // ← no upper bound!
}
```

A child (or a parent testing) could type 500 characters. This causes:
1. **UI overflow** — the name is rendered in `CircleAvatar` labels, `AppBar` titles, and Firestore document fields across the app.
2. **Firestore document field bloat** — Firestore has a 1 MB document limit; a crafted name approaching that limit could corrupt the user document.
3. **Prompt injection risk** — the name is injected verbatim into the Gemini prompt via `ConversationCoachService._buildOpeningPrompt()`: `contextMap['learnerName'] = userName`. A long or specially crafted name could distort the AI prompt.

**Fix — add a maximum length validator and input formatter:**

```dart
// create_user_screen.dart — update name TextFormField
import 'package:flutter/services.dart'; // add to imports

TextFormField(
  controller: _nameController,
  textDirection: TextDirection.rtl,
  maxLength: 30,                         // hard cap in the field
  inputFormatters: [
    FilteringTextInputFormatter.allow(   // letters, spaces, hyphens only
      RegExp(r"[֐-׿a-zA-Z\s\-']"),
    ),
    LengthLimitingTextInputFormatter(30),
  ],
  // ... decoration unchanged ...
  validator: (value) {
    if (value == null || value.trim().isEmpty) return 'אנא הזינו שם';
    if (value.trim().length < 2) return 'השם חייב להכיל לפחות 2 תווים';
    if (value.trim().length > 30) return 'השם לא יכול להכיל יותר מ-30 תווים';
    // Block prompt-injection characters
    if (value.contains(RegExp(r'[<>{}\[\]\\\/]'))) {
      return 'השם מכיל תווים לא חוקיים';
    }
    return null;
  },
),
```

---

### 🔴 HIGH — Bug #8: `DailyMissionProvider.claimReward()` — Double-reward race condition

**Location:** `lib/providers/daily_mission_provider.dart` → `claimReward()` lines 106-131  

**Root cause:**  
The claim guard is `if (mission == null || !mission.isClaimable) return false;` where `isClaimable` checks `mission.rewardClaimed == false`. The sequence is:

```dart
mission.rewardClaimed = true;      // (A) mark as claimed
await rewardCallback(mission.reward); // (B) add coins — async!
await _persist();                   // (C) save to SharedPreferences
notifyListeners();
```

If the user double-taps "Collect Reward" rapidly, two calls to `claimReward()` can pass the `isClaimable` guard **before either call reaches line (A)**, because the second tap fires before `setState` from `notifyListeners()` rebuilds the widget. Both calls award coins. The widget only rebuilds after *both* complete.

**Fix — use an optimistic lock by setting `rewardClaimed = true` atomically before any await:**

```dart
// daily_mission_provider.dart — replace claimReward()
Future<bool> claimReward(
  String missionId,
  Future<void> Function(int reward) rewardCallback,
) async {
  if (!_initialized) return false;

  DailyMission? mission;
  for (final current in _missions) {
    if (current.id == missionId) {
      mission = current;
      break;
    }
  }

  if (mission == null || !mission.isClaimable) return false;

  // 🔑 Optimistic lock: mark BEFORE any await so re-entrant calls
  // see rewardClaimed == true and exit early.
  mission.rewardClaimed = true;
  notifyListeners(); // immediately rebuild UI to disable the button

  try {
    await rewardCallback(mission.reward);
    await _persist();
    return true;
  } catch (e) {
    // Roll back the optimistic lock if reward delivery failed
    mission.rewardClaimed = false;
    notifyListeners();
    debugPrint('claimReward failed, rolled back: $e');
    return false;
  }
}
```

Additionally, add a UI-level guard in `DailyMissionsScreen._handleClaim()` by disabling the button during the claim:

```dart
// daily_missions_screen.dart — add _claiming state
bool _isClaiming = false;

Future<void> _handleClaim(BuildContext context, DailyMission mission, 
    DailyMissionProvider provider) async {
  if (_isClaiming) return; // UI-level guard
  setState(() => _isClaiming = true);
  
  try {
    final coinProvider = context.read<CoinProvider>();
    await provider.claimReward(
      mission.id,
      (reward) => coinProvider.addCoins(reward),
    );
    // ... snackbar logic unchanged ...
  } finally {
    if (mounted) setState(() => _isClaiming = false);
  }
}
```

---

## Summary Table

| # | Severity | File | Issue | Fix Strategy |
|---|----------|------|-------|--------------|
| 1 | 🔴 Critical | `coin_provider.dart` | Split-brain coin write — local & cloud can diverge | Catch cloud failure, defer retry, roll back on total failure |
| 2 | 🟡 Medium | `auth_gate.dart` | `MapScreen` renders before first cloud sync completes | Add `!_hasSynced` to loading gate condition |
| 3 | 🟡 Medium | `home_page.dart` | `_isEvaluating` not reset in `finally` → possible double-coin award | Move reset to `finally` block |
| 4 | 🟢 Low | `word_repository.dart` | Per-word web-image errors silently swallowed | Add `debugPrint` per failure |
| 5 | 🟢 Low | `home_page.dart` | `late FlutterTts` accessed in `dispose()` before init | Change to nullable `FlutterTts?` |
| 6 | 🔴 High | `create_user_screen.dart` | No name max-length or character filter → UI overflow + prompt injection | Add `maxLength: 30`, `FilteringTextInputFormatter`, validator |
| 7 | 🔴 High | `daily_mission_provider.dart` | Double-tap can claim reward twice before `notifyListeners` rebuilds | Optimistic lock: set `rewardClaimed = true` before first `await` |

---

## Additional Recommendations

1. **Firestore Transactions for Coin Updates:** Consider wrapping `updateCoins()` in a Firestore transaction with server-side increment (`FieldValue.increment(amount)`) rather than reading then writing the full balance. This eliminates the last-write-wins problem entirely.

2. **Sanitize `learnerName` in Gemini Prompts:** Before inserting user-provided names into AI prompts, apply a server-side or client-side sanitizer that strips newlines, JSON control characters, and trims to 30 characters:
   ```dart
   final safeUserName = userName
       .replaceAll(RegExp(r'[\n\r\t{}"\\\[\]]'), '')
       .trim()
       .substring(0, userName.length.clamp(0, 30));
   ```

3. **Age Field Validation Gap:** `_ageController` accepts any integer via `TextInputType.number`, but on some keyboards a child can still type `0` or `999`. The validator range of 3-18 is correct. Consider adding `inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)]` so only 2-digit inputs are accepted at the field level.

4. **`claimReward` in `DailyMissionProvider`** mutates a `DailyMission` object from the `_missionCatalog` static list (the `_buildDailyMissions` does make fresh copies — ✅ that path is safe). However, `incrementByType` also mutates `mission.progress` on the live object in `_missions`. If `_missions` is ever accidentally set to `_missionCatalog` directly (e.g., during a copy-paste refactor), the static catalog objects would be mutated permanently in memory. Consider making `DailyMission` immutable (`@immutable` + `copyWith`) as a structural defense.
