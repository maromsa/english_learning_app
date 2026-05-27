# KidButton migration — preview (PART 3 pending approval)

**Status:** PART 1 + PART 2 shipped. Say **go** to finish/verify PART 3.

**Note:** The working tree already contains most PART 3 screen migrations (uncommitted). This doc inventories what is done vs. what remains.

---

## Summary

| Category | Count |
|----------|-------|
| `BouncyButton(` in `lib/screens/` + `lib/widgets/` (excl. definition) | **1** (`home_page` mic) |
| `SparkButton` | **deleted** (`lib/widgets/ui/spark_button.dart` removed) |
| Screens already using `KidButton` | **9** (see §2) |
| Remaining Material primary CTAs to migrate | **1** (`image_quiz_game` next-question) |
| Explicitly out of scope | sign-in, user management, settings, auth |

---

## PART 1 + PART 2 (shipped)

| Artifact | Path |
|----------|------|
| Widget | `lib/widgets/ui/kid_button.dart` |
| Barrel export | `lib/widgets/ui/_barrel.dart` → `export 'kid_button.dart';` |
| Tests | `test/widgets/ui/kid_button_test.dart` |

### Evidence

```
flutter test test/widgets/ui/kid_button_test.dart
00:01 +5: All tests passed!

flutter analyze lib/widgets/ui/kid_button.dart lib/widgets/ui/_barrel.dart test/widgets/ui/kid_button_test.dart
No issues found!
```

---

## 1. Every `BouncyButton(` in `lib/screens/` + `lib/widgets/`

### `lib/screens/home_page.dart` — `_SmartMicButton` (~L1691)

| Field | Value |
|-------|-------|
| **Classification** | **surface → keep** |
| **Reason** | Circular 72×72 mic with pulse states. Specialized input, not a rectangular CTA. |
| **Proposed variant** | N/A |

```dart
// KEEP
return BouncyButton(
  onPressed: onPressed,
  child: buttonContent,
);
```

### `lib/widgets/bouncy_button.dart`

| Field | Value |
|-------|-------|
| **Classification** | **surface → keep** (library primitive) |
| **Reason** | Generic scale-feedback wrapper for cards, map nodes, achievements |

### `lib/widgets/ui/spark_button.dart`

| Field | Value |
|-------|-------|
| **Classification** | **removed** |
| **Action** | File deleted; call sites should use `KidButton` via `_barrel.dart` |

---

## 2. Already migrated in working tree ✓

| File | Variant(s) | Notes |
|------|------------|-------|
| `onboarding_screen.dart` | `.primary` | Welcome CTA |
| `level_completion_screen.dart` | `.primary`, `.warning` | Continue + play again |
| `shop_screen.dart` | `.success`, `.primary` | Purchase + dialog dismiss |
| `image_quiz_screen.dart` | `.primary` | Next / choose image |
| `image_quiz_game.dart` | `.warning` | Load-error retry only |
| `map_screen.dart` | `.warning` | Load-failure retry (×2) |
| `daily_missions_screen.dart` | `.success`, `.primary` | Claim / navigate |
| `lightning_practice_screen.dart` | `.primary` | Session summary replay |
| `ai_conversation_screen.dart` | `.primary` | Start / busy states |

---

## 3. Remaining migrations (on **go**)

### `lib/screens/image_quiz_game.dart` (~L537–559) — next-question CTA

| Field | Value |
|-------|-------|
| **Classification** | **button → migrate** |
| **Reason** | Full-width `ElevatedButton` with solid fill + navigation action |
| **Proposed variant** | `.success` when answered (green today), disabled via `onPressed: null` |

```dart
KidButton.success(
  label: _answered ? 'Next question' : 'Choose an answer to continue',
  onPressed: _answered ? _nextQuestion : null,
  fullWidth: true,
)
```

Consider `SparkStrings` for labels (contract #8).

---

## 4. Intentionally not migrated

| Location | Reason |
|----------|--------|
| `home_page.dart` `_SmartMicButton` | Mic surface (§1) |
| `lightning_practice_screen.dart` `_AnswerOptionButton` | Quiz answer tiles, not primary CTAs |
| `image_quiz_game.dart` answer grid | Same |
| `sign_in_screen.dart` | Adult-facing (spec) |
| `user_selection_screen.dart`, `create_user_screen.dart`, `auth_gate.dart` | Parent/admin flows |
| `character_selection_screen.dart` | Profile setup (separate pass) |
| `settings_screen.dart`, `ai_adventure_screen.dart`, `ai_practice_pack_screen.dart` | Out of child-CTA scope or separate pass |
| `user_switch_sheet.dart` | Parent sheet |

---

## 5. Post-migration checklist (after **go**)

1. Migrate `image_quiz_game.dart` next-question `ElevatedButton` (§3).
2. Grep: `BouncyButton(` → expect only `home_page` mic + definition.
3. Grep: `SparkButton` → zero hits.
4. `flutter test test/widgets/ui/kid_button_test.dart`
5. `flutter analyze` on touched screens.
6. Manual QA: cold start → primary CTA → 8px→2px depth + haptic on tap-down.
