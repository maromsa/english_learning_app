## AI Success Metrics & Telemetry Wiring

### Core Metrics
- **Engagement Lift**: captured through `quiz_answered` (correctness, rewards, streak progression) and `hint_used` events to track interaction depth and adaptive hint demand.
- **Validation Accuracy**: measured via the `camera_validation` event, which reports approval outcome, validator strategy (`Gemini`, HTTP function, etc.), and optional confidence scores where available.
- **Session Length & Retention Signals**: tracked with `screen_session` events (start/end timestamps per screen) plus onboarding completion timing.

### Event Instrumentation Map
- `onboarding_tips_shown`: fires once tips are rendered; emits `tip_ids`, `rule_ids`, and a returning-user flag.
- `onboarding_completed`: emitted when onboarding finishes, recording tip configuration and time-to-complete.
- `quiz_answered`: records every question attempt with result, streak, reward, and hint usage flag.
- `hint_used`: fired whenever the learner invokes a hint, containing the remaining option count.
- `camera_validation`: wraps each camera submission outcome with validator type and optional confidence.
- `screen_session`: emitted when key screens (e.g., `home`) finish, with total duration and completion stats.

### Analysis Notes
- Events are routed through `TelemetryService`, which defaults to Firebase Analytics when configured and gracefully falls back to console logs in debug builds.
- All parameters are trimmed/sanitized to stay within analytics constraints while preserving segmentation keys.
- Session and onboarding events provide baseline timing metrics needed for iterative AI experiments (e.g., adaptive onboarding, reward scheduling).
