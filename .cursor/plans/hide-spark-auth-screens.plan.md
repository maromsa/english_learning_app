# Hide global Spark on auth / onboarding

## Overview
`LivingSparkOverlay` is stacked globally in `main.dart`. Suppress it while auth/onboarding screens are mounted using ref-counted `beginSparkOverlaySuppress` / `endSparkOverlaySuppress` on `SparkOverlayController`, driven by a small `SparkOverlaySuppressor` widget.

## Files
- `lib/providers/spark_overlay_controller.dart` — suppress depth + effective visibility
- `lib/widgets/spark_overlay_suppressor.dart` — new Stateful wrapper
- `lib/screens/auth_gate.dart` — wrap loading scaffold
- `lib/screens/user_selection_screen.dart`, `sign_in_screen.dart`, `onboarding_screen.dart` — wrap root UI
- `test/providers/spark_overlay_controller_test.dart` — unit tests for suppress depth

## DB
None
