# Multi-Profile & Cloud Sync

## Overview
Child profiles under a parent's Firebase account with offline-first SharedPreferences storage and Firestore sync at `users/{parentUid}/childProfiles/{profileId}`.

## Design decisions
- **ChildProfile model** stores metadata + progress summary; detailed progress remains in per-profile SharedPreferences keys (`user_{profileId}_*`).
- **Offline-first**: local writes always succeed; `pendingSync` flag queues cloud upload when online.
- **Migration**: legacy `local_users` JSON auto-migrates to `child_profiles_v1` on first launch.
- **Auth flow**: Google sign-in → profile selection ("מי משחק?") → MapScreen.

## Files created
- `lib/models/child_profile.dart`
- `lib/services/child_profile_service.dart`
- `lib/services/child_profile_sync_service.dart`
- `lib/providers/child_profile_provider.dart`
- `lib/screens/child_profile_selection_screen.dart`
- `lib/utils/active_profile_scope.dart`
- Tests under `test/models/`, `test/services/`, `test/providers/`

## Files modified
- `firestore.rules` — childProfiles + gameData subcollections
- `lib/main.dart` — ChildProfileProvider registration
- `lib/screens/auth_gate.dart` — profile gate after login
- `lib/services/daily_reward_service.dart` — per-profile streak keys
- `lib/services/achievement_service.dart` — per-profile achievement keys
- `lib/providers/daily_mission_provider.dart` — per-profile mission keys
- `lib/services/parent_progress_service.dart` — scoped stats aggregation
- `lib/providers/user_session_provider.dart` — switchToChildProfile
- `lib/widgets/user/user_switch_sheet.dart` — profile switcher
- `lib/screens/settings_screen.dart` — switch profile entry
- `lib/screens/parent_dashboard_screen.dart` — switch profile action

## Testing strategy
Unit tests for model, local service, sync service, profile switching, updated ParentProgressService and DailyRewardService.

## Risks
- Deploy updated `firestore.rules` before cloud sync works in production.
- Google Sign-In web client ID must be configured for auth on mobile.
