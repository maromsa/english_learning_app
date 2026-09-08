# Weekly Parent Recap

## Overview
A summary card on the Parent Dashboard covering the **last 7 calendar days**
(today + the 6 before): active practice days, words practised, practice
minutes, coins earned, best day, and words reached to mastery this week. All
data comes from existing on-device stores plus one new lightweight per-profile
coin log. Offline-first — no network, no Firestore.

## The 7-day window

`[startOfDay(today) - 6 days  ..  today]`, inclusive. A record dated exactly
`today - 6` is **in**; `today - 7` is **out**. The window boundary is the
headline thing the service tests pin down, with an injectable `now`.

## Data sources

| Metric | Source | Notes |
| --- | --- | --- |
| active days, words, minutes, best day | `parent_activity.v1_<userId>` prefs log (`{day,words,minutes}` list, written by `ParentProgressService.recordSession`) | already populated by Lightning / quiz sessions |
| coins earned this week | **new** `user_<id>_daily_coins_earned` prefs log (`{day: coins}` map) | written fire-and-forget from `CoinProvider` |
| words mastered this week | `srs.v1.<userId>.<level>.<word>` prefs entries | count where `masteryLevel >= 1.0` **and** `lastReviewDate` is inside the window |

Day-key format matches `ParentProgressService._dayKey` exactly:
`"$year-${MM}-${dd}"` (year not zero-padded).

## Files

- `lib/models/weekly_recap.dart` — **new**. `WeeklyRecap` (7 × `DailyActivity`
  reused from `parent_dashboard_stats.dart`, `coinsEarned`,
  `wordsMasteredThisWeek`). Computed getters: `activeDays`, `wordsPracticed`,
  `minutesPracticed`, `bestDay`, `isEmpty`.
- `lib/services/weekly_recap_service.dart` — **new**. `loadRecap({required
  String userId, DateTime? now, ...})`. Firebase-agnostic, prefs + optional
  `LocalUserDataService` injected.
- `lib/services/local_user_data_service.dart` — add `recordCoinsEarned(userId,
  amount)` (upsert today's entry, trim to 35 days) and `weeklyCoinsEarned(
  userId, {now})` (sum inside the window). Per-profile key, §2.3-compliant.
- `lib/providers/coin_provider.dart` — after the in-memory grant in `addCoins`
  and `claimDailyPracticeReward`, `unawaited(_localUserDataService
  .recordCoinsEarned(...))` when a profile id is set. Best-effort, never blocks
  or fails the grant. `setCoins` / `spendCoins` are **not** hooked (restore /
  spend ≠ earned).
- `lib/widgets/weekly_recap_card.dart` — **new**. `WeeklyRecapCard extends
  StatelessWidget` taking a `WeeklyRecap`. Four stat tiles + best-day line + a
  7-bar mini sparkline + a mastery line when `> 0`; a friendly empty state when
  `recap.isEmpty`.
- `lib/screens/parent_dashboard_screen.dart` — `_loadStats` also fetches the
  recap; return becomes a record `({ParentDashboardStats stats, WeeklyRecap
  recap})`; `WeeklyRecapCard` renders just under `_HeaderCard`.
- `lib/l10n/spark_strings.dart` — recap card copy.

## Tests

- `test/services/weekly_recap_service_test.dart` —
  - **window boundary**: activity on `now-6` counts, `now-7` doesn't;
  - `activeDays` counts distinct days with any activity;
  - `wordsPracticed` / `minutesPracticed` sums;
  - `coinsEarned` sums only in-window daily coin entries;
  - `wordsMasteredThisWeek`: mastered + reviewed in-window counts; mastered but
    last reviewed 10 days ago doesn't; mastery 0.6 doesn't;
  - empty prefs → `WeeklyRecap.isEmpty`.
- `test/widgets/weekly_recap_card_test.dart` — renders the four numbers; best
  day line; mastery line hidden at 0; empty-state copy when `isEmpty`.
- `test/providers/coin_provider_test.dart` — `addCoins` writes a daily coin
  entry for the active profile; `spendCoins` does not; guest (no id) is a
  no-op.

## Residual risk

- `wordsMasteredThisWeek` is "at mastery **and** reviewed this week" — a word
  already mastered that gets one more review this week is counted. There is no
  per-word `mastered_at`; this is the honest approximation and the card copy
  says "practised to mastery this week", not "newly mastered".
- The coin log starts empty on existing installs, so the first week's
  "coins earned" under-reports until activity accrues. Acceptable for a
  forward-looking recap; noted, not backfilled.
- Coins earned before a profile id is set (pure guest) aren't logged — the
  dashboard requires a profile anyway.
