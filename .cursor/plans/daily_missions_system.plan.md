## Overview

Daily Missions already exist in the app (model, provider, and screen). This plan refines them to match the new spec: clearer model semantics, 24‑hour reset via SharedPreferences, proper integration with `KidSpeechService` and quiz/level flows, coin rewards via `CoinProvider`, and Spark celebrations when missions complete, while reusing the existing architecture.

## Design decisions

- **Reuse existing model and provider** rather than replacing them:
  - Map requested fields to existing ones:
    - `targetValue` → `DailyMission.target`
    - `currentValue` → `DailyMission.progress`
    - `rewardCoins` → `DailyMission.reward`
    - `isClaimed` → `DailyMission.rewardClaimed`
  - Add documentation/comments instead of renaming fields to avoid breaking persistence and existing UI.
- **Enum values**:
  - Keep `DailyMissionType` values `speakPractice`, `lightningRound`, `quizPlay` (already used across the app).
  - Optionally add a `camera`-style value later for camera missions without changing current flows.
- **24‑hour reset**:
  - Reuse current date‑key approach in `DailyMissionProvider.initialize()`, which stores `daily_missions_date` and serialized missions in `SharedPreferences`.
  - Ensure we always generate a fresh set when the stored date != today; expose a small helper so tests can simulate date changes easily.
- **Random mission generation**:
  - Replace the fixed `_buildDefaultMissions()` list with:
    - A **catalog** of candidate missions (at least 5–6 entries across speak/quiz/lightning).
    - Simple random selection of 3 missions per day using `Random` while preserving type diversity (at least one speak mission when possible).
  - Persist the chosen missions for the day so they don’t reshuffle until the next reset.
- **Listening to progress events**:
  - Keep the existing pattern where **screens/services call the provider**:
    - `HomePage` already calls `incrementByType(DailyMissionType.speakPractice)` after successful `KidSpeechService` recognition.
    - `LightningPracticeScreen` calls `incrementByType(DailyMissionType.lightningRound)` at the end of a run.
    - `ImageQuizGame` calls `incrementByType(DailyMissionType.quizPlay)` after a quiz session.
  - This effectively makes `DailyMissionProvider` a sink for `KidSpeechService` and quiz/level events without adding a new event bus.
  - We will add documentation in the provider and the key screens to make this intent explicit.
- **Coin rewards and Spark celebrations**:
  - `DailyMissionProvider.claimReward` already accepts a `rewardCallback`; keep this and use `CoinProvider.addCoins` from the UI layer.
  - Inject `SparkOverlayController` into `DailyMissionProvider` (via constructor, wired in `main.dart`), similar to `AchievementService`.
  - On **first‑time completion** of a mission (transition from not completed → completed) inside `incrementByType` / `incrementById`, call:
    - `sparkOverlayController.setAnimationState(SparkOverlayAnimationState.celebrating);`
- **UI technology choices**:
  - Reuse the existing `DailyMissionsScreen` layout, but:
    - Wrap each mission card in a `GlassCard` for glassmorphism.
    - Replace the “Claim” `FilledButton` with `SparkButton`:
      - Enabled (calls `onClaim`) only when `mission.isClaimable`.
      - Disabled or replaced with a “Continue mission” CTA when in progress.
    - Keep the confetti overlay for an extra layer of celebration on claim.

## Files to create / modify

- **Model**
  - `lib/models/daily_mission.dart` (modify):
    - Add documentation mapping fields to the requested spec (`targetValue`, `currentValue`, `rewardCoins`, `isClaimed`).
    - Optionally add getters `targetValue`, `currentValue`, `rewardCoins`, `isClaimed` that proxy to existing fields for semantic clarity.
    - Consider adding a `camera` enum value (not yet used) in a backward‑compatible way.

- **Provider**
  - `lib/providers/daily_mission_provider.dart` (modify):
    - Add optional `SparkOverlayController sparkOverlayController` to the constructor.
    - In `incrementByType` / `incrementById`:
      - Before updating `mission.progress`, track `wasCompleted = mission.isCompleted`.
      - After updating, if `!wasCompleted && mission.isCompleted`, trigger `sparkOverlayController.setAnimationState(SparkOverlayAnimationState.celebrating)` (if provided).
      - Persist and notify as today.
    - Enhance `_buildDefaultMissions()`:
      - Split into `List<DailyMission> _allMissionTemplates()` producing a wider pool.
      - Implement `_pickDailyMissions()` that randomly selects 3 missions from the pool, ensuring diversity when possible.
      - Use `_pickDailyMissions()` in `initialize()` and `refreshMissions()`.
    - Keep `initialize()`’s date‑based reset using `_prefDateKey` and `_prefMissionsKey`.

- **UI**
  - `lib/screens/daily_missions_screen.dart` (modify):
    - Update `_QuestCard` to wrap its content in `GlassCard` instead of a plain `Container`.
    - Replace `_QuestActionButton`’s claim button with `SparkButton`:
      - For `isClaimable`: show a prominent `SparkButton(label: 'אסוף פרס!', icon: Icons.card_giftcard, onPressed: onClaim)`.
      - For in‑progress: either keep the existing InkWell “continue mission” button or restyle it subtly; no need for SparkButton here.
      - For claimed: keep the passive “reward collected” state as is.
    - No changes needed to the screen‑level confetti logic except maybe minor polish for timing.

- **Integration**
  - `lib/main.dart` (modify):
    - When constructing `DailyMissionProvider`, pass the shared `SparkOverlayController` instance used elsewhere:
      - `final dailyMissionProvider = DailyMissionProvider(sparkOverlayController: sparkOverlayController);`
  - **No direct changes** required to:
    - `HomePage`, `LightningPracticeScreen`, `ImageQuizGame` flows, since they already call `incrementByType` based on KidSpeech/quiz events.
    - We may update comments to clarify this is the mission‑progress integration point.

## Testing strategy

- **Unit tests**
  - New `test/providers/daily_mission_provider_test.dart`:
    - Verify `initialize()`:
      - On empty prefs, generates 3 missions and persists them (date + payload).
      - On same‑day launch, reloads existing missions instead of regenerating.
    - Verify 24‑hour reset:
      - Simulate old date in prefs; `initialize()` should regenerate missions and update `_prefDateKey`.
    - Verify `incrementByType`:
      - Increments `progress` up to `target`, persists, and notifies.
      - When crossing from `progress == target - 1` to `target`, calls the injected `SparkOverlayController.setAnimationState(SparkOverlayAnimationState.celebrating)` exactly once.
    - Verify `claimReward`:
      - Fails when mission not completed or already claimed.
      - Succeeds when `isClaimable`, marks `rewardClaimed`, calls reward callback with `reward`, persists, and notifies.
- **Widget tests**
  - Add a small test for `DailyMissionsScreen`:
    - With a mocked provider containing a mission that is claimable:
      - Verify that the card renders with `GlassCard` and that the `SparkButton` is present and enabled.
    - With an in‑progress mission:
      - Verify the “continue mission” CTA is shown instead of the claim button.
- **Manual tests**
  - Confirm that:
    - Missions refresh once per day (force date change to test).
    - Speaking successfully increments speak missions.
    - Lightning practice and image quiz increment their respective missions.
    - On first completion of a mission, Spark celebrates.
    - Claiming a reward adds coins, shows confetti, and disables the claim button.

## Risks / open questions

- **Randomization vs. curriculum**: random daily missions are fun but may conflict with a structured learning path; this plan keeps randomization simple and local to the provider so it can be tuned later (e.g., weightings or per‑level templates).
- **Camera mission type**: the spec mentions `camera`, but current flows do not yet expose a camera‑based daily mission; we will add enum support but defer actual camera missions to a later feature to avoid shipping half‑wired UX.
- **Multiple mission completions in one session**: if several missions finish at once (unlikely with current templates), Spark celebrations will trigger once per completion; we’ll keep it simple for now.

