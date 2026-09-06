# 🗺️ Project Roadmap — English Word Journey ("מסע המילים באנגלית")

A gamified English‑vocabulary app for Hebrew‑speaking children **aged 4–8**.
Because many users cannot yet read fluently (in either language), every feature
is held to one bar: **a 4‑year‑old should understand it from icons, colour, motion
and sound alone.**

Status legend: ✅ shipped · 🚧 in progress · 🔜 next · 💡 future / exploratory

---

## Phase 1 — Completed Foundations ✅

The stable core the rest of the product is built on.

### Learning loop
- ✅ Asset‑driven world map with multi‑stage level progression and star gates
- ✅ Themed vocabulary levels (fruits, animals, vehicles, space, magic items…)
- ✅ Image + audio word presentation with multiple‑choice mastery checks
- ✅ Spaced‑repetition review (`SrsService`) with per‑word mastery tracking
- ✅ Mini‑games: Lightning Practice, Image Quiz, Memory Match, Voice Challenge,
  Scavenger Hunt

### AI companion — "Spark"
- ✅ Server‑side Gemini proxy (Firebase Functions) — no API keys in the client,
  Firebase‑ID‑token auth, per‑user rate limiting
- ✅ AI Conversation, AI Adventure Story, AI Practice Pack
- ✅ Camera word discovery with Gemini image validation
- ✅ Server‑side Google TTS with on‑device voice caching

### Platform & data
- ✅ Offline‑first architecture: local word cache, offline practice, sync engine
- ✅ Multi‑profile support (local profiles + optional Google Sign‑In → Firestore sync)
- ✅ Child profile avatars (animal emojis)
- ✅ Parent dashboard & parental gate
- ✅ Firestore security rules, secret hardening, CI running `flutter analyze`,
  `flutter test` and `dart format --set-exit-if-changed`

---

## Phase 2 — Current: Gamification & Engagement 🚧

Turning a working learning tool into something kids *choose* to open. Focus:
visible progress, collectible rewards, and daily reasons to return.

- ✅ Coin economy (earn on correct answers / level completion / streaks)
- ✅ Magic Shop — stickers, frames, Spark cosmetics, consumable Streak Shield
- ✅ Daily reward streak + Streak Shield protection
- ✅ Daily Missions (3 rotating tasks, 24h reset) with Spark celebrations
- ✅ `AchievementService` — 28 achievements across 7 categories, coin rewards,
  Firestore sync, animated unlock notifications
- ✅ Leaderboard
- 🚧 **Achievements Showcase screen** — a highly visual "Trophy Room" where a
  pre‑reader can instantly see earned vs. locked medals (icon/colour/shine
  driven, minimal text, tap a medal for a friendly spoken explanation).
  *Current focus — see `feat/achievements-showcase`.*
- 🔜 Achievement detail dialog with Spark voice‑over ("You earned this for…")
- 🔜 Progress‑aware locked medals (show "3 / 10" as a ring, not a sentence)
- 🔜 Map‑level celebration when a new medal is earned (confetti + Spark)
- 🔜 Weekly recap card for parents (words learned, streak, new medals)

---

## Phase 3 — Future 💡

Longer‑horizon bets. Not scheduled; listed so design decisions today stay
compatible.

### Deeper engagement
- 💡 Avatar / Spark customisation tied to achievements (unlock hats, pets, worlds)
- 💡 Collectible "sticker album" that fills in as words are mastered
- 💡 Friendly co‑op or family challenges (compare progress with a sibling/parent)
- 💡 Seasonal / themed limited‑time events and medals

### Learning depth
- 💡 Sentence‑ and phrase‑level practice (beyond single words)
- 💡 Adaptive difficulty engine tuning session length to attention span
- 💡 Reading‑readiness track (phonics mini‑games) for the older end of 4–8
- 💡 Offline AI fallback (on‑device model) for story / practice generation

### Reach & platform
- 💡 Localised UI beyond Hebrew (Arabic, Spanish, …)
- 💡 Native tablet‑optimised layouts
- 💡 Teacher / classroom mode with multi‑student dashboards
- 💡 Accessibility pass: full screen‑reader support, dyslexia‑friendly fonts,
  colour‑blind‑safe medal palette

---

_Last updated: 2026-09-06_
