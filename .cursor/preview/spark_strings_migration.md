# SparkStrings migration — preview (do not apply yet)

**Status:** Preview only. No files created or refactored until you reply **`go`**.

**Scope:** Child-facing Hebrew in `lib/screens/` and `lib/widgets/` (grep: `'[א-ת][^']*'`).

**Out of scope (later pass):** Sign-in, user management, parent-style errors with `שגיאה:` + exception text — `create_user_screen.dart`, `user_selection_screen.dart`, `character_selection_screen.dart`, most of `auth_gate.dart`.

---

## 1. Full `SparkStrings` file (edit copy here before apply)

This is the exact file to create at `lib/l10n/spark_strings.dart`:

```dart
import 'dart:math';

/// All child-facing Hebrew copy in the app.
///
/// Tone rules: 1st person plural inclusive ("בואו ננסה!"),
/// never "שגיאה", pair every problem with an action,
/// max 8 words per error string.
///
/// A non-engineer (teacher/parent) should be able to review
/// and edit every string in this file without touching code.
class SparkStrings {
  SparkStrings._();
  static final _rand = Random();

  // ─── Mic & speech recognition ─────────────────
  static const String micPrompt        = 'בואו נדבר! לחצו על המיקרופון 🎤';
  static const String micListening     = 'אני מקשיבה...';
  static const String micRetry         = 'אופס, לא שמעתי. ננסה שוב?';
  static const String micTooQuiet      = 'קצת יותר חזק? אני כאן 💛';
  static const String micPermissionAsk = 'צריך הרשאת מיקרופון כדי לדבר איתי';

  // ─── TTS / audio playback ─────────────────────
  static const String ttsError = 'הקול נחבא 🙈 נלחץ שוב על המילה?';

  // ─── Loading / thinking states ────────────────
  static const String thinking         = 'רגע, אני חושבת... ✨';
  static const String imageAnalyzing   = 'מסתכלת על התמונה...';
  static const String generatingQuiz   = 'מכינה לכם משחק חדש 🎲';

  // ─── Network / Gemini failures ────────────────
  static const String offline       = 'אין אינטרנט כרגע. ננסה עוד רגע?';
  static const String aiTimeout     = 'לקח לי קצת. בואו ננסה שוב?';
  static const String aiUnavailable = 'אני קצת עייפה עכשיו. נחזור עוד מעט?';

  // ─── Wrong-answer ladder (3 strikes, soft) ────
  static const String wrong1 = 'כמעט! ננסה עוד פעם?';
  static const String wrong2 = 'בואו נשמע איך זה נשמע באנגלית 👂';
  static const String wrong3 = 'נמשיך הלאה — נחזור למילה הזאת אחר כך 💛';

  // ─── Compliments (Celebration + home) ─────────
  static const List<String> compliments = <String>[
    'מעולה!', 'וואו!', 'אלוף!', 'מדהים!',
    'כל הכבוד!', 'נהדר!', 'מצוין!', 'פנטסטי!',
    'ענק!', 'שיחקת אותה!',
  ];

  static String randomCompliment() =>
      compliments[_rand.nextInt(compliments.length)];

  // ─── Level / chapter ──────────────────────────
  static const String levelLocked   = 'נסיים את הקודם קודם 🔒';
  static const String levelUnlocked = 'שלב חדש פתוח! 🎉';
  static const String chapterDone   = 'סיימנו פרק! מטורף 🏆';

  // ─── Generic button labels ────────────────────
  static const String tryAgain    = 'ננסה שוב';
  static const String continueBtn = 'נמשיך!';
  static const String letsStart   = 'נתחיל ללמוד!';
  static const String skipForNow  = 'נדלג בינתיים';
  static const String backToMap   = 'חזרה למפה';
}
```

---

## 2. Proposed **new** constants (add to `SparkStrings` on apply)

These child-facing strings have no exact match in section 1. Wording follows your tone rules (inclusive plural, no `שגיאה`, problem + action, ≤8 words on errors).

```dart
  // ─── Mic (extra states) ───────────────────────
  static const String micChecking      = 'רגע, בודקת מה שמעתם...';
  static const String micHeardNothing    = 'לא שמעתי. בואו נדבר שוב?';
  static const String micStartFailed     = 'אופס, לא הצלחתי. ננסה שוב?';

  /// When fuzzy match hears something close (home pronunciation).
  static String wrongAlmostHeard(String heard) =>
      'כמעט! שמעתי $heard. עוד פעם?';

  // ─── Camera / photo identify ──────────────────
  static const String cameraUnclearUi    = 'לא רואה ברור. בואו נצלם שוב?';
  static const String cameraUnclearSpeak = 'לא ראיתי ברור. בואו ננסה שוב!';
  static String cameraCenterWord(String word) =>
      'שימו את $word במרכז וצלמו שוב?';
  static String cameraFoundWord(String word) =>
      'וואו! רואה $word. בואו נלמד!';
  static String cameraSpeakFound(String word) =>
      'מצוין! רואה $word.';
  static const String cameraGenericFail  = 'אופס! בואו ננסה שוב?';

  // ─── Camera mission screen ────────────────────
  static String cameraShootTarget(String word) => 'צלמו: $word';
  static const String cameraValidating   = 'בודקת את התמונה...';
  static String cameraSuccessBadge(String word) =>
      'מצוין! זיהינו $word ✅';
  static String cameraTryAgainTarget(String word) =>
      'עוד לא $word. בואו נצלם שוב?';

  // ─── Map / load ───────────────────────────────
  static const String mapLoading3d       = 'טוענת את העולם... ✨';
  static const String mapLoadFailed      = 'לא הצלחנו לטעון. ננסה שוב?';
  static const String mapNoLevels        = 'אין שלבים עכשיו. נחזור עוד רגע?';
  static String levelUnlockNeed(String prev, String next, int remaining) =>
      'נסיים $prev — עוד $remaining מילים ל$next';
  static String levelUnlockNeedShort(String prev, String next) =>
      'נסיים $prev כדי לפתוח $next';

  // ─── Quiz / lightning ─────────────────────────
  static const String quizLoadFailed     = 'לא הצלחנו לטעון. ננסה שוב?';
  static const String quizNeedMoreWords  = 'צריך עוד מילים כדי לשחק!';
  static String quizCorrectCoins(int n)  => 'כל הכבוד! +$n מטבעות';
  static String quizWrongAnswer(String w) => 'כמעט! התשובה: $w';
  static const String quizRemovedWrong   = 'הסרתי תשובה אחת 😉';
  static const String lightningLoadFailed = 'לא הצלחנו לטעון. ננסה שוב?';
  static String lightningWinCoins(int n) => 'מעולה! +$n מטבעות ⚡';
  static String lightningWrong(String w) => 'כמעט! התשובה: $w';
  static const String lightningNeedWords = 'צריך עוד מילים לריצת ברק!';
  static const String lightningTimeUp    = 'נגמר הזמן! בואו נסכם?';

  // ─── Home / missions UI ───────────────────────
  static const String homeNeedWordsLightning =
      'צריך שתי מילים לפחות לריצת ברק!';
  static const String homeNoWordsYet       =
      'אין מילים עדיין. בואו נצלם אחת!';
  static const String dailyMissionTitle    = 'משימה יומית';
  static String dailyMissionRemaining(int n) =>
      'עוד $n וננצח!';
  static const String dailyMissionKeepGoing = 'ממשיכים יפה!';

  // ─── Shop ─────────────────────────────────────
  static const String shopNotEnoughCoins = 'אופס! אין מספיק מטבעות 🪙';

  // ─── Level complete ───────────────────────────
  static const String levelCompleteTitle = 'כל הכבוד!';
  static String levelCompleteNamed(String name) => 'סיימנו את $name!';
  static const String levelCompleteMap   = 'חזרה למפה';
  static const String levelPlayAgain     = 'נשחק שוב';

  // ─── Onboarding ───────────────────────────────
  static const String welcomeTitle       = 'ברוכים הבאים למסע המילים!';
  static const String welcomeBody        =
      'יש לנו טיפים קטנים ללמוד באנגלית בקצב שלכם.';
  static const String welcomeGo          = 'קדימה!';

  // ─── AI conversation (child errors) ─────────
  static const String aiChatRetry        = 'אופס! בואו ננסה שוב?';
  static const String aiChatStartFirst   = 'בואו נפתח שיחה עם ספרק קודם';
  static const String aiChatStuck        = 'ספרק נתקעה. ננסה שוב?';
  static const String aiChatCantHear     = 'לא שמעתי. נדבר או נכתוב?';

  // ─── Widgets ──────────────────────────────────
  static String welcomeBackUser(String name) => 'היי $name, כיף שחזרת!';
  static const String achievementNew     = 'הישג חדש! 🎉';
  static String wordsProgress(int done, int total) =>
      '$done מתוך $total מילים';
```

> **Note:** Section 2 will be merged into the same class body as section 1 when you approve. You may rename or shorten any line before `go`.

---

## 3. Migration table — child-facing matches

| File | Line | Old string | Proposed replacement | Rationale |
|------|------|------------|----------------------|-----------|
| **home_page.dart** | 80 | `לחצו על המיקרופון כדי לדבר` | `SparkStrings.micPrompt` | High-priority; inclusive + emoji per spec |
| | 104–117 | `_successCompliments` list + `_getRandomCompliment()` | **DELETE** → `SparkStrings.randomCompliment()` | Single compliment source; adds `ענק!`, `שיחקת אותה!` |
| | 228 | `שגיאה בהשמעת הקול. אנא נסו שוב.` | `SparkStrings.ttsError` | Remove `שגיאה`; playful + action |
| | 316 | `שגיאה באתחול שירות ה-AI. אנא נסו שוב.` | `SparkStrings.aiUnavailable` | Persona “tired Spark”, not technical error |
| | 334 | `מנתחים את התמונה שלכם...` | `SparkStrings.imageAnalyzing` | 1st person, warmer |
| | 360 | `לא הצלחתי לראות ברור. נסו לצלם מחדש.` | `SparkStrings.cameraUnclearUi` | Inclusive `בואו`; shorter |
| | 362 | `לא ראיתי ברור. בואו ננסה שוב.` (TTS) | `SparkStrings.cameraUnclearSpeak` | Pair UI + spoken copy |
| | 377 | `התמונה עדיין לא נראית כמו $identifiedWord...` | `SparkStrings.cameraCenterWord(identifiedWord)` | Shorter; centers action |
| | 387 | `בואו ננסה שוב. שמרו את $identifiedWord...` (TTS) | `SparkStrings.cameraCenterWord(identifiedWord)` | Same guidance, one template |
| | 401 | `איזה יופי! אני רואה ${newWord.word}...` | `SparkStrings.cameraFoundWord(newWord.word)` | Tighter celebration |
| | 413 | `מצוין! אני רואה ${newWord.word}.` (TTS) | `SparkStrings.cameraSpeakFound(newWord.word)` | Matches UI tone |
| | 427 | `מצטער, משהו השתבש. אנא נסו שוב.` | `SparkStrings.cameraGenericFail` | No apology lecture; `אופס` |
| | 429 | `אוי, משהו השתבש. נסו שוב.` (TTS) | `SparkStrings.cameraGenericFail` | Align UI + voice |
| | 550, 786 | `לא שמעתי כלום. בוא ננסה שוב.` | `SparkStrings.micHeardNothing` | Fix informal `בוא` → `בואו` |
| | 586–587 | `"$compliment +10 מטבעות"` | `'${SparkStrings.randomCompliment()} +10 מטבעות'` | Central compliments |
| | 647 | `כמעט! זה נשמע כמו '$recognizedWord'...` | `SparkStrings.wrongAlmostHeard(recognizedWord)` | Keeps hint; ≤8 words core |
| | 702 | `הרשאת מיקרופון לא זמינה. אנא בדוק...` | `SparkStrings.micPermissionAsk` | Child-friendly permission |
| | 709 | `מקשיב...` | `SparkStrings.micListening` | Spark voice (“אני מקשיבה”) |
| | 735 | `סיימתי להקשיב. בודק...` | `SparkStrings.micChecking` | Thinking state |
| | 763 | `לא הצלחתי להתחיל להקשיב. אנא נסה שוב.` | `SparkStrings.micStartFailed` | No `שגיאה`; inclusive |
| | 795 | `שגיאה. אנא נסה שוב.` | `SparkStrings.micRetry` | Remove `שגיאה` |
| | 903 | `הוסיפו לפחות שתי מילים...` | `SparkStrings.homeNeedWordsLightning` | Shorter imperative → inclusive |
| | 1053 | `אין עדיין מילים לתרגול...` | `SparkStrings.homeNoWordsYet` | Warm nudge to camera |
| | 1258 | `משימה יומית` | `SparkStrings.dailyMissionTitle` | Label centralization |
| | 1329–1330 | `עוד ${mission.remaining}...` / `המשיכו להצליח!` | `dailyMissionRemaining` / `dailyMissionKeepGoing` | Mission copy bundle |
| **camera_screen.dart** | 126 | `✅ מצוין! זיהינו את "..."` | `cameraSuccessBadge(targetWord)` | Keep ✅; child tone |
| | 136 | `❌ לא זיהינו "...". נסו שוב!` | `cameraTryAgainTarget(targetWord)` | No ❌ discipline tone optional — see review |
| | 144 | `שגיאה בצילום. נסו שוב.` | `SparkStrings.cameraGenericFail` | **Removes `שגיאה`** |
| | 180 | `צלמו: ${widget.targetWord}` | `cameraShootTarget(...)` | |
| | 226 | `בודק תמונה…` | `SparkStrings.cameraValidating` | Matches `imageAnalyzing` voice |
| **lightning_practice_screen.dart** | 277 | `שגיאה בטעינת המילים. נסו שוב.` | `SparkStrings.lightningLoadFailed` | **Removes `שגיאה`** |
| | 333 | `אין מספיק מילים כדי להתחיל...` | `SparkStrings.lightningNeedWords` | Shorter |
| | 470 | `מעולה! הרווחתם $reward מטבעות ⚡️` | `lightningWinCoins(reward)` | |
| | 488 | `כמעט! התשובה הנכונה: "..."` | `lightningWrong(word)` | Align with `wrong1` ladder tone |
| | 575 | `הזמן נגמר! בואו נסקור...` | `SparkStrings.lightningTimeUp` | |
| | 858 | `שחקו שוב` | `SparkStrings.levelPlayAgain` or keep — see review | Imperative vs inclusive |
| | 863 | `חזרה למסע` | `SparkStrings.backToMap` (close) — see review | Semantic mismatch? |
| | 438 / 905–911 | various “need more words” | `quizNeedMoreWords` / `lightningNeedWords` | Consolidate duplicates |
| **image_quiz_screen.dart** | 136 | `לא ניתן לטעון מילים. נסו שוב.` | `SparkStrings.quizLoadFailed` | |
| | 226 | `כל הכבוד! הרווחת $reward מטבעות` | `quizCorrectCoins(reward)` | |
| | 234 | `לא הפעם. המילה הנכונה: ${target.word}` | `quizWrongAnswer(target.word)` | Softer than “לא הפעם” alone |
| | 438 | `נסו שוב` | `SparkStrings.tryAgain` | Button label |
| **image_quiz_game.dart** | 234 | `לא ניתן לטעון מילים. נסו שוב.` | `quizLoadFailed` | Same as quiz screen |
| | 291 | `הסרתי אפשרות שגויה אחת 😉` | `quizRemovedWrong` | |
| | 320, 339 | success / wrong feedback | `quizCorrectCoins` / `quizWrongAnswer` | |
| | 430 | `נדרשות לפחות $_minWords מילים...` | `quizNeedMoreWords` | |
| | 438 | `נסו שוב` | `tryAgain` | |
| **level_completion_screen.dart** | 142 | `כל הכבוד!` | `SparkStrings.levelCompleteTitle` or `compliments[0]` | Static celebration |
| | 169 | `סיימת את ${widget.levelName}` | `levelCompleteNamed(levelName)` | Inclusive `סיימנו` |
| | 588 | `המשך למפה` | `SparkStrings.continueBtn` or `backToMap` — see review | |
| | 613 | `שחק שוב` | `levelPlayAgain` | |
| **map_screen.dart** | 812 | `השלב הזה נעול.` | `SparkStrings.levelLocked` | Friendlier lock message |
| | 841–842, 860 | unlock dialogs with `${...}` | `levelUnlockNeed` / `levelUnlockNeedShort` | Centralize long copy |
| | 1186 | `אין שלבים זמינים כרגע. נסו שוב מאוחר יותר.` | `mapNoLevels` | |
| | 1217, 1762 | `טוען עולם תלת-מימדי...` | `mapLoading3d` | Spark voice |
| | 1267 | `שגיאה בטעינת המפה` | `mapLoadFailed` | **Removes `שגיאה`** (child-visible) |
| | 1272 | `נסו לסגור ולפתוח...` | **DROP** or fold into `mapLoadFailed` — see review | Adult troubleshooting tone |
| | 1287, 1803 | `נסה שוב` | `SparkStrings.tryAgain` | Singular → inclusive |
| | 1785, 1795 | map load failure block | `mapLoadFailed` + `SparkStrings.offline` — see review | |
| **shop_screen.dart** | 65 | `אופס! אין מספיק מטבעות 🪙` | `shopNotEnoughCoins` | Already good; centralize |
| **onboarding_screen.dart** | 92, 100, 144 | welcome copy | `welcomeTitle`, `welcomeBody`, `welcomeGo` | Child onboarding bundle |
| **daily_missions_screen.dart** | 68 | `כל הכבוד! הרווחת ${mission.reward}...` | `quizCorrectCoins(mission.reward)` | Reuse coin praise |
| **ai_conversation_screen.dart** | 822 | `משהו השתבש. נסו שוב בעוד רגע.` | `aiChatRetry` | Already soft; centralize |
| | 836 | `פתחו שיחה עם ספרק לפני...` | `aiChatStartFirst` | |
| | 927 | `ספרק נתקע בתשובה. נסו שוב.` | `aiChatStuck` | Feminine Spark (`נתקעה`) optional |
| | 1042 | `לא הצלחנו לשמוע אתכם...` | `aiChatCantHear` | Pairs with mic strings |
| **user_switch_sheet.dart** | 73 | `היי ${newUser.name}, כיף שחזרת!` | `welcomeBackUser(name)` | Child greeting |
| **achievement_notification.dart** | 85 | `🎉 הישג חדש! 🎉` | `achievementNew` | Single emoji budget |
| **words_progress_bar.dart** | 24 | `'$completedWords מתוך $totalWords מילים'` | `wordsProgress(done, total)` | |

### Intentionally **not** migrating (adult / parent / dev)

| File | Example lines | Reason |
|------|----------------|--------|
| `create_user_screen.dart` | 57, 114, 160, `שגיאה...` | Account setup; parent-facing errors |
| `user_selection_screen.dart` | 107, 153 | User admin |
| `auth_gate.dart` | 329, 340, 385 | App shell errors (parent/device) |
| `character_selection_screen.dart` | 82 | Save error with `$e` |
| `map_screen.dart` | 393–508 level **names/descriptions** | Content catalog — large copy pass; not error tone |
| `lightning_practice_screen.dart` | 105–174 hint map | Educational hints — separate content review |
| `ai_adventure_screen.dart` | 179 `GEMINI_PROXY_URL` | Developer setup message |
| `score_display.dart` | 40, 71, 82 | Explains star economy — parent-style; see review |
| `user_switch_sheet.dart` | 108, 164, 223 | “ניהול משתמשים” — parent UI |
| `home_page.dart` | 1820–1872 game menu titles | Navigation labels — optional pass 2 |

---

## 4. High-priority diff summary (`home_page.dart`)

| Item | Action on apply |
|------|-----------------|
| `_feedbackText` initial | `SparkStrings.micPrompt` |
| TTS failure | `SparkStrings.ttsError` |
| Image analyze | `SparkStrings.imageAnalyzing` |
| `_successCompliments` + `_getRandomCompliment()` | **Remove**; use `SparkStrings.randomCompliment()` |
| All `שגיאה` literals in file | Replaced per table (0 remaining) |

---

## 5. Post-apply verification (run after `go`)

```bash
# No "שגיאה" in child surfaces
rg "שגיאה" lib/screens/ lib/widgets/ \
  --glob '!create_user_screen.dart' \
  --glob '!user_selection_screen.dart' \
  --glob '!auth_gate.dart' \
  --glob '!character_selection_screen.dart'

flutter analyze
```

Expected: remaining `שגיאה` only in excluded adult files.

---

## 6. Needs human review

1. **`level_completion_screen.dart` — `המשך למפה` vs `SparkStrings.continueBtn` (`נמשיך!`)**  
   Button semantics differ. Prefer new `levelCompleteContinueToMap = 'נמשיך למפה!'`?

2. **`lightning_practice_screen.dart` — `חזרה למסע` vs `backToMap` (`חזרה למפה`)**  
   “מסע” ≠ “מפה”. Suggest dedicated `backToJourney = 'חזרה למסע'`.

3. **`camera_screen.dart` — ❌/✅ prefixes**  
   Keep emoji prefixes for instant kid feedback, or drop ❌ per “never disciplinary”?

4. **`map_screen.dart` — `נסו לסגור ולפתוח את האפליקציה`**  
   Adult IT instruction shown to kids. Fold into `mapLoadFailed` only, or parent-only screen?

5. **`auth_gate.dart` map load errors**  
   Children may see this before play. Migrate like `map_screen` or keep adult copy until auth UX redesign?

6. **`home_page.dart` wrong-answer ladder**  
   Only one wrong message today. Wire `wrong1` → `wrong2` → `wrong3` by strike count, or keep `wrongAlmostHeard` only?

7. **`score_display.dart`**  
   Child-visible on home — include in SparkStrings or leave for “parent dashboard” pass?

8. **Feminine Spark (`מקשיבה`, `נתקעה`)**  
   Confirm persona gender matches character art everywhere.

9. **TTS strings duplicated from UI**  
   Some lines exist only in `_speak(...)`. Apply table rows to **both** UI and TTS call sites.

10. **Compliment consecutive repeat**  
    `Random()` does not prevent back-to-back duplicates. Accept for v1, or add `_lastComplimentIndex` in `SparkStrings` later?

---

## 7. Apply checklist (when you say `go`)

- [ ] Create `lib/l10n/spark_strings.dart` (section 1 + approved section 2 constants)
- [ ] Add `import 'package:english_learning_app/l10n/spark_strings.dart';`
- [ ] Refactor tables in section 3
- [ ] Delete `home_page.dart` `_successCompliments` / `_getRandomCompliment()`
- [ ] Run `flutter analyze` and paste output
- [ ] Run grep verification from section 5

---

**Reply `go` when copy in sections 1–2 looks right (edit this file first if needed).**
