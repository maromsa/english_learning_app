# CLAUDE.md — Roles & Rules

Operating guide for any AI agent or contributor working in this repository.
Two tiers: **Tier 1** is *how* we build (engineering + behavior, portable across
projects). **Tier 2** is *what* this project is (domain rules that only make
sense here). When a Tier 2 rule conflicts with a Tier 1 default, Tier 2 wins for
this repo.

---

## 0. Project Snapshot — orient here first

**english_learning_app** — a gamified, **offline-first** English-vocabulary app
for children (families + teachers). Boots into a travel map; kids unlock levels
by earning stars, practise words with speech/camera/mini-games, and are coached
by "Spark", an optional Gemini-powered buddy.

| Area | Choice |
| --- | --- |
| Framework | Flutter (stable ≥ 3.24 locally; **CI pins 3.44.0**), Dart SDK `>=3.4.0 <4.0.0` |
| State management | `provider` (`ChangeNotifier` + `MultiProvider` in `lib/main.dart`) |
| Local persistence | `shared_preferences` (flags, per-key progress) + `sqflite` (`AppDatabase`, SRS cards) |
| Cloud | Firebase: Auth, Cloud Firestore, Analytics, Crashlytics, Storage |
| Sync | Custom offline-first engine (`SyncEngine`, `*SyncService`) — local is source of truth, cloud is a mirror |
| AI | Gemini + Google TTS, **only** via the authenticated Cloud Function proxy in `functions/` — no AI keys in the client |
| Media | `cached_network_image` + Cloudinary word packs, with an offline image cache fallback |
| Tests | `flutter_test`, `mockito`, `fake_cloud_firestore`, `sqflite_common_ffi` — ~379 test cases |
| Entry point | `lib/main.dart` → `AuthGate` → map |

**Identity model (three tiers — see §2.3):**
1. **Guest** — no account, progress in `SharedPreferences` only.
2. **Local user / child profile** — `LocalUser` / `ChildProfile`, multiple per device, still local-first.
3. **Firebase user** — signed-in parent account; child profiles + game data sync to Firestore.

---

# TIER 1 — Global Engineering & Behavior Standards

## 1.1 Working agreement

- **Read before you write.** Open the file and its neighbours (same folder,
  one downstream consumer) before editing. Match the surrounding style, naming,
  and comment density.
- **Plan non-trivial work before coding.** For anything beyond a typo or a
  one-line fix, write a short plan (affected files, design choice, test plan,
  risks) and get sign-off. Trivial changes: a two-line summary is enough.
  Larger feature plans live in `.cursor/plans/{slug}.plan.md`.
- **Evidence over claims.** Never say "tests pass" / "analyze is clean" without
  pasting the actual command output (the summary line is fine).
- **No silent scope skips.** If you skip a step (tests, integration check),
  say so and why.
- **Finish end-to-end.** No dead or half-wired features — a new field, service,
  or provider must be wired from UI → state → persistence → sync, or the gap
  must be called out explicitly. (This has bitten us before; see §2.3.)
- **Autonomy target:** analysis → change → `flutter analyze` + `flutter test` →
  PR. Report outcomes, not option menus. The PR is the deliverable; humans
  merge anything user-facing.

## 1.2 Coding style & linting

- **`analysis_options.yaml` is the contract.** It extends `flutter_lints` and
  adds `strict-casts`, `strict-raw-types`, and `use_build_context_synchronously:
  error`. Do not weaken it to make code pass.
- **Target: `flutter analyze` reports 0 issues.** Fix every lint you introduce
  before moving to the next file. Don't fix unrelated pre-existing lints in a
  feature PR (note them / spin off a task instead).
- **`dart format .`** before every commit. No unformatted diffs.
- Enforced conventions worth remembering: single quotes, `const` constructors
  wherever possible, trailing commas, `prefer_final_locals`, ordered directives,
  no `print` (`debugPrint` only), `cancel_subscriptions` / `close_sinks`,
  `unawaited_futures` (wrap fire-and-forget in `unawaited(...)`).
- `scripts/**` is excluded from analysis — keep throwaway tooling there, never
  app logic.
- Never guard `BuildContext` use across an `await` without a `mounted` check.

## 1.3 Testing — TDD

- **Tests ship with the code, not after.** Every new public method, service,
  provider mutation, or widget behavior gets a test in the same change. A new
  file with no test is a rule violation.
- **Establish a green baseline first.** Run the affected tests before you touch
  them; don't build on red.
- **Isolation:** each test independent. Use
  `SharedPreferences.setMockInitialValues({})`, `fake_cloud_firestore`, and the
  `sqflite_common_ffi` helper in `test/support/` (`fresh_test_database.dart`,
  `fake_firebase_services.dart`). Never hit real Firebase or the network.
- **Async:** await everything; use `fakeAsync` / `pump`+`pumpAndSettle`
  deliberately. Avoid wall-clock assertions ("within 700ms") — they flake under
  CI load (known: `celebration_test`, `srs_service` persistence — pass on retry).
- Run before pushing:
  ```bash
  flutter analyze
  flutter test
  ```
- Cloud Functions have their own suite: `npm test --prefix functions`.
- Coverage aim: >80% on business logic (services, providers, models).

## 1.4 Git & PR workflow

- **Trunk-based.** Branch off `main`, one focused topic per branch.
- **Branch naming:** `feat/<slug>`, `fix/<slug>`, `chore/<slug>`,
  `docs/<slug>` (kebab-case). Matches existing history
  (`feat/leaderboard-avatars`, `feat/child-profile-switcher`).
- **Commits:** Conventional Commits — `feat:`, `fix:`, `chore:`, `docs:`,
  `test:`, `refactor:`. Imperative mood, present tense.
- **PRs** via `gh pr create`. Body covers: **what / why / validation
  (CI + manual) / residual risk**. CI is the validation authority.
- **Merging:** never merge a user-facing / production PR yourself — that merge
  is the human approval gate. Trivial non-production PRs may be merged only when
  asked. Keep PRs and branches synced via the `gh` CLI.
- Do not skip hooks, force-push shared branches, or rewrite published history
  without calling out the risk first.

## 1.5 Safety, secrets & privacy

- **No secrets in the client, ever.** Gemini + Google TTS keys live only in
  Cloud Function Secret Manager. The client authenticates to the proxy with the
  signed-in user's Firebase ID token.
- Runtime config comes from `--dart-define` (all platforms) or OS env vars
  (desktop dev), surfaced through `lib/app_config.dart`. `.env` is a local dev
  convenience only (`scripts/flutterw`) and is **never** bundled.
- `firebase_options.dart` is safe to commit (public by design); security is
  enforced by **`firestore.rules`** + API-key restrictions in the console.
- Before any hard-to-reverse action (history rewrite, force-push, deleting
  data, prod config, key rotation) — state the risk and consequence first.
- This is a **children's app**: no PII in logs, analytics, or the leaderboard;
  parental gate (`parental_gate_dialog.dart`) protects external links and
  destructive settings.

---

# TIER 2 — Project-Level Domain Rules

## 2.1 Architecture constraints

**Offline-first is non-negotiable.**
- Every feature must work with no network. Local store (`SharedPreferences` /
  `AppDatabase`) is the **source of truth**; Firestore is a mirror.
- All Firebase / HTTP calls: wrap in try/catch, time-bounded, degrade
  gracefully. A failed sync leaves local data intact and rows marked dirty for
  retry (see `SyncEngine`: dirty → upload → mark clean; never lose on failure).
- `lib/main.dart` loads persisted state in parallel with per-future timeouts so
  a slow disk/Firebase never blocks startup. Preserve that pattern.

**Reactive UI.**
- State lives in `ChangeNotifier` providers (`lib/providers/`), exposed via the
  `MultiProvider` in `main.dart`. Widgets read via `context.watch` /
  `Consumer` / `Selector`; never poll.
- Services (`lib/services/`) hold logic + IO and are Firebase-agnostic at the
  constructor boundary. UI does not call Firestore directly.

**Dependency injection.**
- Constructor injection everywhere. Services take optional deps with real
  defaults, e.g. `SrsService({SharedPreferences? prefs, FirebaseFirestore?
  firestore, AppDatabase? db, SyncEngine? syncEngine})`. This is what makes the
  suite fast and hermetic — keep every new service testable the same way.
- No service locators, no global singletons except the deliberate
  `AppDatabase.instance` / `NotificationService.instance`.

**Layering:** `screens/` → `widgets/` → `providers/` → `services/` →
`models/` / `utils/`. Dependencies point downward only.

## 2.2 Gamification & Kids UX

- **Instant feedback.** Every answer / tap gets an immediate visible +
  audible response — no spinners on the hot path. Pre-cache sounds and images.
- **Celebrate progress.** Correct answers, level-ups, streak milestones,
  achievements, and daily rewards trigger `celebration.dart` / `confetti` /
  `spark_orb` / sound. Use the shared widgets in `lib/widgets/ui/` — don't
  hand-roll animations.
- **Spark** (`living_spark.dart`, overlay controller) is the emotional layer:
  encouraging, never punishing. Wrong answers → "try again", hints, scaffolding.
- **Sound is opt-out, respectful.** All audio routes through `SoundService` /
  `AudioSettings` / `BackgroundMusicService`; honour the mute setting and only
  play music where intended (map screen).
- **Reading-light.** Target pre-readers: large tap targets, icon + color + audio
  redundancy, minimal text, RTL-aware (Hebrew UI strings exist).
- Kid-facing copy currently mixes Hebrew and English — keep new strings
  consistent with the screen you're in; route through localization where set up.

## 2.3 Data integrity & sync

The hardest problem in this app. **Losing a child's stars, coins, or streak is
a P0 bug.**

- **Three identity tiers must all keep their data:** guest → local user /
  child profile → Firebase user. Signing in or creating a profile must **migrate,
  never wipe** existing local progress.
- **Namespace per-profile state by profile id.** Detailed progress lives in
  `SharedPreferences` keyed by profile id (`user_<id>_...`, `srs.v1.<userId>.
  <levelId>.<wordId>`). Any new per-child value must be namespaced the same way.
  ⚠️ Known inconsistency: some daily-reward keys are global
  (`daily_reward_streak`, `daily_reward_last_claim` in `CoinProvider`) while
  `DailyRewardService` uses `user_<id>_daily_reward_streak`. Do not add more
  global keys for per-child data; converging these is tracked in §3.
- **Merge strategy on sync:**
  - Stats (coins, stars, counts, streaks): take the **higher** value.
  - Lists (`purchasedItems`, achievements): **union**.
  - Timestamped records (SRS cards, profiles): **newer `updatedAt` wins**.
  - On sign-in, cloud data is applied to local providers, then user ids are set
    so subsequent writes dual-persist (local + cloud).
- **Nullable-forever for added fields.** New model fields (e.g. `avatarId`,
  `avatarUrl`) must deserialize cleanly from documents written before the field
  existed — default null / absent, never throw. Follow the `ChildProfile`
  pattern (conditional keys in `toMap`, tolerant `fromMap`).
- **Firestore writes must match `firestore.rules`.** The `/leaderboard/{entryId}`
  rule uses a strict `hasOnly([...])` field whitelist. **Any field you add to a
  leaderboard write must be added to the rule in the same PR**, or the write is
  rejected (and our catch blocks swallow it silently). ⚠️ `avatarId` is
  currently written by `child_profile_sync_service.dart` but **missing from the
  whitelist** — see §3.
- Leaderboard entries are privacy-safe by contract: `profileId`, `displayName`
  (≤40 chars), `coins`, `dailyStreak`, `avatarColor`, `avatarId`, `updatedAt` —
  never photos, ages, or any other child data.
- Every sync path is best-effort and non-fatal: a publish failure must never
  crash the app or block the local action that triggered it.

## 2.4 AI / Gemini proxy rules

- All AI (identify, scene description, image validation, text/story, TTS) goes
  through the **single authenticated proxy** (`functions/src/index.ts`,
  `GeminiProxyService` on the client). No direct provider calls from the app.
- Every request carries `Authorization: Bearer <Firebase ID token>`;
  unauthenticated → 401. Rate limit 30 req/min/user → 429, client degrades
  gracefully.
- Client caches proxy responses (`gemini_proxy_response_cache.dart`) and voice
  audio (`spark_voice_disk_cache*`) — reuse before re-requesting.
- If the proxy is unreachable, AI features **disable cleanly**; the core
  learning loop keeps working offline. Tests must not require a live proxy
  except the explicitly-tagged `test/gemini_proxy_live_test.dart`.

## 2.5 Directory map

```
lib/
  main.dart            MultiProvider wiring, startup sequence
  app_config.dart      runtime config from --dart-define / env
  models/              plain data classes, tolerant (de)serialization
  providers/           ChangeNotifier state (auth, coins, theme, profiles, missions…)
  services/            logic + IO; Firebase-agnostic constructors
    sync_engine.dart, *_sync_service.dart   offline-first sync
    srs_service.dart, srs_algorithm.dart, word_mastery_service.dart  SRS (SM-2)
    gemini_proxy_*, *_service.dart           AI via proxy
  screens/  widgets/   UI; widgets/ui/ = shared kid components (celebration, kid_button, spark_orb)
  utils/               pure helpers, theme tokens, platform shims (_io / _stub pairs)
functions/             Cloud Function proxy (TypeScript, own test suite)
test/                  mirrors lib/; support/ has DB + Firebase fakes
firestore.rules        security + field whitelists (keep in sync with writes)
.cursor/plans/         approved feature plans
```

---

# 3. Known gaps & technical debt

Tracked here so they don't get rediscovered the hard way. Fix opportunistically
or spin off tasks.

1. ~~**`avatarId` rejected by leaderboard security rules.**~~ ✅ **Fixed.**
   The `/leaderboard/{entryId}` `hasOnly([...])` whitelist now includes
   `avatarId` with a `is string` + size guard, and
   `test/firestore_rules_test.dart` statically guards the whitelist against
   drift from the publisher payload. **Rules must be redeployed**
   (`firebase deploy --only firestore:rules`) before / with PR #111 so the
   `avatarId` write from `child_profile_sync_service.dart` succeeds.

2. **CI does not enforce quality gates.** `.github/workflows/test.yml` runs
   `flutter analyze || true` and `dart format … continue-on-error: true`, so
   lint/format regressions merge silently. Only `flutter test` actually blocks.
   *Fix: drop `|| true` / `continue-on-error` on analyze + format once the tree
   is clean.*

3. **Stale `.cursor/rules/`.** `java-conventions.mdc`, `kafka-messaging.mdc`,
   `persistence-patterns.mdc`, `rest-controller.mdc`, `service-layer.mdc`, and
   `testing.mdc` describe a Java/Spring/Kafka backend — **wrong stack**, and two
   are `alwaysApply`-adjacent. `agent-behavior.mdc` / `feature-lifecycle.mdc`
   are sound process rules but reference Maven / `kubectl` / Liquibase.
   *Fix: delete the Java files, rewrite `testing.mdc` for `flutter_test`,
   Flutter-ify the lifecycle rules (or fold them into this file).*

4. **Global vs per-profile daily-reward keys** (see §2.3) — `CoinProvider`
   practice-reward state is not namespaced by profile, so switching child
   profiles can cross-contaminate the claim/streak state.

5. **Version drift.** README says Flutter 3.24+, CI pins 3.44.0, `pubspec`
   allows Dart 3.4+. Pick one supported floor and state it everywhere.

6. **`develop` branch referenced but unused.** CI triggers and `TESTING.md`
   mention `develop`; history is trunk-based on `main`. Drop `develop` or
   document the branching model.

7. **Docs scattered at repo root.** ~12 uppercase `*.md` files
   (`ISSUES_FOUND.md`, `ALL_ISSUES_FOUND.md`, `IMPROVEMENTS.md`,
   `QA_LOGICAL_STRESS_TEST_REPORT.md`, several `XCODE_*` / `IOS_*`) — consolidate
   under `docs/` and delete the obsolete audit dumps.

8. **Bilingual UI strings** are ad hoc (Hebrew + English mixed per screen).
   `flutter_localizations` is a dependency; decide on a localization strategy.
