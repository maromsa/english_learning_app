# Cloud sync for Magic Shop customization

## Overview
Protect children's shop purchases (unlocked map themes / victory sounds and the
equipped choice of each) by mirroring them to Firestore via the existing
`ChildProfile` document. Local `SharedPreferences` (`ShopCustomizationService`)
stays the source of truth; the cloud is a mirror. Merge is **loss-proof**:
unlocked lists union, equipped scalars follow the newer `updatedAt`.

## Correction to the brief — `firestore.rules`

**No rules change is needed and none is made.** The
`users/{uid}/childProfiles/{profileId}` path is `allow read, write: if
isOwner(userId)` — there is **no `hasOnly()` field whitelist** on it (unlike
`/leaderboard/{entryId}`). A parent may write any field to their own child's
profile document. `firestore_rules_test.dart` only guards the *leaderboard*
whitelist.

Shop data must **never** reach the leaderboard (privacy contract, CLAUDE.md
§2.3 — leaderboard fields are frozen at `profileId`, `displayName`, `coins`,
`dailyStreak`, `avatarColor`, `avatarId`, `updatedAt`). So instead of widening a
whitelist we add a **reverse drift guard**: a test asserting the leaderboard
`hasOnly([...])` list contains none of the shop fields.

## Files

- `lib/models/child_profile.dart` — +4 fields: `unlockedThemes`
  (`List<String>`, default `const []`), `unlockedSounds` (`List<String>`,
  default `const []`), `equippedTheme` (`String?`), `equippedSound`
  (`String?`). Tolerant `fromMap` (absent / wrong-type → default, never throw —
  `avatarId` pattern), conditional `toMap` (lists always; equipped only when
  non-null), `copyWith`.
- `lib/services/shop_customization_service.dart` — `readSnapshot(userId)` →
  `ShopCustomizationSnapshot` (all four values); `applyMergedSnapshot(userId,
  …)` unions incoming unlocked ids with what's on device (**never shrinks**)
  and writes equipped ids, then persists.
- `lib/services/child_profile_service.dart` — `updateProgressSnapshot` gains
  optional `unlockedThemes` / `unlockedSounds` / `equippedTheme` /
  `equippedSound` params (same shape as `coins`).
- `lib/services/child_profile_sync_service.dart` —
  - inject optional `ShopCustomizationService` (real default);
  - `syncFromCloud`: after the existing "newer wins" pick, override the merged
    profile's shop fields with a real merge — `unlockedThemes` /
    `unlockedSounds` = set-union(local, cloud); `equippedTheme` /
    `equippedSound` = value from the profile with the newer `updatedAt`
    (non-null fallback). Then push the merged result back into
    `ShopCustomizationService.applyMergedSnapshot(profile.id, …)` so the device
    store reflects cloud unlocks.
  - `syncProfileToCloud` needs no change — it already serialises
    `profile.toMap(forCloud: true)`.
- `lib/utils/active_profile_scope.dart` — before `updateProgressSnapshot`, read
  `ShopCustomizationService.readSnapshot(profile.id)` and pass the four values
  through, so a profile switch uploads the child's current shop state.

## Merge rules (CLAUDE.md §2.3)

| Field | Strategy |
| --- | --- |
| `unlockedThemes`, `unlockedSounds` | **union** (lists) |
| `equippedTheme`, `equippedSound` | **newer `updatedAt` wins** (scalar) |

A purchased theme/sound can never be lost: even if the "losing" side of the
profile-level merge had a unique unlock, the union keeps it.

## Tests

- `test/models/child_profile_test.dart` — new fields round-trip; `fromMap`
  tolerates absent + malformed (`unlockedThemes: 'not a list'` → `[]`);
  `toMap` omits null equipped + empty lists behaviour; `copyWith`.
- `test/services/shop_customization_service_test.dart` — `readSnapshot` /
  `applyMergedSnapshot` union semantics (device keeps local-only unlocks).
- `test/services/child_profile_sync_service_test.dart` —
  - upload: cloud doc carries `unlockedThemes` etc.;
  - download union: local `{theme_space}` + cloud `{theme_gold}` → merged
    profile has both, and `ShopCustomizationService` for that id has both;
  - equipped follows newer `updatedAt`.
- `test/firestore_rules_test.dart` — leaderboard `hasOnly` list excludes every
  shop field (reverse drift guard).

## Residual risk

- After `syncFromCloud` writes merged unlocks to `SharedPreferences`, an
  already-constructed `ShopCustomizationProvider` is stale until its next
  `load()` (driven by `map_screen._loadCurrentUser` on session change). Self
  -heals on the next map entry; noted for a follow-up if it proves visible.
- Snapshot upload happens on profile switch (via `ActiveProfileScope`), same
  cadence as `coins` today — a purchase made mid-session syncs on the next
  switch / scope apply, not instantly.
- Guest (`guest_` namespace) purchases still don't migrate into a profile on
  sign-in (unchanged from the shop-customization PR).
