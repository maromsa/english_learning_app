# Sound & Theme Customization in the Magic Shop

## Overview
Add purchasable **cosmetic customization** to the Magic Shop: map themes (Space,
Gold) and a victory sound. Coins are spent through `CoinProvider` (unchanged
source of truth for the balance). Unlocked + equipped state is **per-child**,
persisted locally, and surfaced through a dedicated `ShopCustomizationProvider`.
First visible payoff: the equipped theme recolours the MapScreen sky gradient;
the equipped sound replaces the level-complete fanfare.

## Architecture — theme/sound state

**New `ShopCustomizationProvider` (ChangeNotifier), not an extension of
`ThemeProvider`.**

- `ThemeProvider` owns *app brightness* (light/dark) behind a **global** key
  (`is_dark_mode`). Cosmetic customization is *per-child progress* (P0 data,
  CLAUDE.md §2.3) and must be namespaced `user_<id>_...`. Folding it into
  `ThemeProvider` would either force that stable file to become profile-aware
  (churn + regression risk) or add more global keys for per-child data — the
  exact anti-pattern flagged in §3 gap #4.
- The new provider mirrors `CoinProvider`'s shape: constructor-injected deps,
  `setUserId(userId, {isLocalUser})`, `load()`. That keeps it hermetically
  testable like the rest of the suite.
- Logic + IO live in a Firebase-agnostic `ShopCustomizationService`; the
  provider is a thin reactive wrapper.

State: `Set<String> unlockedThemeIds`, `Set<String> unlockedSoundIds`,
`String equippedThemeId`, `String equippedSoundId`. Default theme + default
sound are implicitly always unlocked and are the initial equipped values.

Purchase flow: `buy(item, coinProvider)` → reject if owned → `coinProvider
.spendCoins(item.cost)` → on success add to unlocked set, persist, **auto-equip**,
notify. Coin mutation never leaves `CoinProvider`.

Equip flow: `equip(item)` → only if owned → set equipped id → persist → notify →
for a sound, push its asset into `SoundService.victorySoundAsset`.

## Files

- `lib/models/customization_item.dart` — **new**. `CustomizationKind {theme,
  sound}`, `CustomizationItem` (id, Hebrew name, cost, kind, icon, optional
  `MapThemePalette`, optional `soundAsset`), `MapThemePalette` (gradient colors
  + stops), static `catalog`. Ids: `theme_default`, `theme_space`, `theme_gold`,
  `sound_default`, `sound_funny`.
- `lib/services/shop_customization_service.dart` — **new**. SharedPreferences
  persistence. Keys (comma-joined lists, matching `LocalUserDataService`
  style):
  - `user_<id>_unlocked_themes`, `user_<id>_unlocked_sounds`
  - `user_<id>_equipped_theme`, `user_<id>_equipped_sound`
  - guest (no user id) → `guest_` prefix.
- `lib/providers/shop_customization_provider.dart` — **new**. ChangeNotifier,
  `_disposed` guard pattern, `equippedMapPalette` getter.
- `lib/services/sound_service.dart` — add settable `String? victorySoundAsset`;
  `playFanfare()` / `playEpic()` prefer it when set. Default null → today's
  behaviour byte-for-byte.
- `lib/screens/shop_screen.dart` — new "ערכות נושא וסאונד" section above/below
  the grid: horizontal cards showing price + lock state + **קנה** (locked) /
  **הפעל** (owned, not equipped) / **פעיל** (equipped).
- `lib/screens/map_screen.dart` — `_MapSkyGradient` reads
  `context.watch<ShopCustomizationProvider>().equippedMapPalette`; default
  palette == current hardcoded values. `_loadCurrentUser` also drives
  `shopCustomizationProvider.setUserId(...)` + `load()`.
- `lib/main.dart` — construct `ShopCustomizationProvider`, `load()` in the
  parallel startup `Future.wait` (3s timeout), register in `MultiProvider`.

## Tests

- `test/services/shop_customization_service_test.dart` — persist/load unlocked
  + equipped; per-profile namespacing isolation; guest fallback.
- `test/providers/shop_customization_provider_test.dart` — buy deducts coins
  via `CoinProvider` + unlocks + auto-equips + persists; insufficient funds →
  no state change, no charge; equip non-owned rejected; equip owned updates;
  `equippedMapPalette` resolves.
- `test/screens/shop_screen_test.dart` — extend: section renders; buy a theme
  deducts coins and flips the card to הפעל/פעיל; equip switches the active card.

## Sync / Firestore

Local-only for v1. No leaderboard fields, no `firestore.rules` change. Cloud
mirroring of customization is a follow-up (noted as residual risk), consistent
with "local is the source of truth".

## Residual risk

- Guest→profile purchases are not migrated (matches current `CoinProvider`
  owned-item behaviour); low impact — cosmetic only.
- "Funny" victory sound maps to `assets/audio/startup_chime.wav` (a real
  bundled asset) as a placeholder until a dedicated SFX is added.
- Map theme is verified by provider unit test + manual run (MapScreen widget
  tests are WebView-heavy and skipped as usual).
