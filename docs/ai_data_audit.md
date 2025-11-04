## AI Data Audit – Phase 1

### Summary
- The app is entirely client-side today; it uses `SharedPreferences` for persistence and has no analytics or backend writebacks.
- Core learning loops revolve around levels (`assets/data/levels.json`), quizzes (`QuizItem` statics), word collections (`WordRepository`), and rewards (coins, achievements, daily streak).
- Signals most ready for AI include: per-word completion, per-level rewards, quiz streaks, hint usage, coin balance changes, purchase history, camera submissions, and daily reward streaks.
- Major gaps: zero telemetry, no user segmentation, and no central content schema beyond static JSON.

### Data Stores & Surfaces
- **Levels & Maps** (`LevelRepository`, `assets/data/levels.json`): static map describing stages, associated rewards, unlock thresholds, coordinates.
- **Word Progress** (`WordRepository`): caches remote or local words; tracks completion/`stickerUnlocked`. Cached JSON written to `SharedPreferences` (`word_repository.cache.*`).
- **Quizzes** (`ImageQuizGame`): in-memory list of `QuizItem`s; rewards coins via `CoinProvider`. Tracks `_streak`, `_bestStreak`, hint use in-state only.
- **Coins** (`CoinProvider`): total balance persisted as `totalCoins`; level-run delta tracked transiently (`levelCoins`).
- **Shop** (`ShopProvider`): product catalog hardcoded; purchases persisted as `purchased_items` list.
- **Achievements** (`AchievementService`): unlock flags stored as `achievement_<id>` booleans.
- **Daily Reward** (`DailyRewardService`): last claim timestamp and streak stored as `daily_reward_last_claim`, `daily_reward_streak`.
- **Onboarding** (`OnboardingScreen`): single flag `onboarding_seen`.
- **Camera Submissions** (`CameraScreen` → `WordData.imageUrl`): captures local path but no validation, upload, or analytics yet.

### Event Hooks & Signals
- Quiz answer -> coin reward (`CoinProvider.addCoins`), streak increments, hint use. No global observer or logging.
- Achievement checks triggered manually via `AchievementService.checkForAchievements`, but only logs to console.
- Shop purchases change `purchased_items`; no recommendation logic or tracking of failed purchases.
- Daily reward claim returns `DailyRewardResult` with `claimed`, `reward`, `streak`; consumer can log metrics.
- Word cache refresh chooses remote vs. fallback; remote fetch includes optional `AiImageValidator` gating during web image augmentation.

### AI-Ready Opportunities
- **Adaptive difficulty**: combine `WordData.isCompleted`, quiz streaks, hint usage to adjust word ordering/difficulty.
- **Personalized onboarding**: use onboarding flag, first-session streaks, and initial quiz accuracy.
- **Shop recommendations**: coin balance trends + `purchased_items` history.
- **Camera moderation loop**: plug `AiImageValidator` into submission flow; log accept/reject outcomes for feedback.
- **Reward optimization**: daily streak + claim intervals for reinforcement scheduling.

### Instrumentation Gaps
- No analytics SDK configured (Firebase Analytics, Sentry, etc.).
- No user/session identifiers beyond local device state.
- No telemetry for camera outcomes, quiz answers, or onboarding path.
- No schema describing content difficulty, which limits model inputs.

### Immediate Next Steps
1. Introduce analytics abstraction (e.g., `TelemetryService`) with log points for onboarding completion, quiz answered, hint used, achievement unlocked, camera validation result, shop purchase.
2. Backfill event payloads with fields listed above to feed AI pipelines.
3. Document SharedPreferences keys and migrate to structured storage if scale grows.
