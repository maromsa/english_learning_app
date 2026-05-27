# Aurora UI · Primitives

Child-facing primitives for ages 5–10. Every widget in this folder MUST follow these contracts.

## Design contracts (non-negotiable)

1. **64pt minimum tap target.** No exceptions for primary actions. Wrap visually-smaller icons in a 64×64 GestureDetector.
2. **Haptic on every tap.** `HapticFeedback.lightImpact()` on tap-down, no exceptions.
3. **Reduce-motion aware.** Check `MediaQuery.of(context).disableAnimations`. If true, replace bounces/breathes with cross-fades.
4. **No bare English in Hebrew Text widgets.** Every English token inside a Hebrew sentence must use `EnglishWordChip` (see P-07).
5. **Glass effects only on hero surfaces.** SoftGlass is for Spark thought-bubbles, chapter intros, lock-screen widget. NEVER on repeating lists or cards.
6. **No red color in child flows.** Closest to "warning" is butter. `AuroraTokens.coral` is for the mic only.
7. **Use AuroraTokens.** No hard-coded hex strings. No raw Duration() literals for motion — use AuroraTokens.dPress, dBounce, dBreathe, dBurst.
8. **Pull strings from SparkStrings.** No hard-coded Hebrew (see P-03).

## File checklist for every new primitive

- [ ] Documented public API at the top of the file
- [ ] Uses AuroraTokens for all colors, radii, durations
- [ ] Respects `MediaQuery.disableAnimations`
- [ ] Has a `Foo.preview()` static helper that returns a sample for design QA
- [ ] Exported from `_barrel.dart`
- [ ] Has at least one widget test in `test/widgets/ui/`

## Import convention

```dart
import 'package:english_learning_app/widgets/ui/_barrel.dart';
```

Do not import individual files. The barrel keeps refactors cheap.
