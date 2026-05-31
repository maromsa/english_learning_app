import 'package:integration_test/integration_test.dart';

import 'map_interaction_scenario.dart';

/// Map 3D ↔ Flutter postMessage bridge integration test.
///
/// **Chrome (local):** Flutter blocks `flutter test integration_test/… -d chrome`.
/// Run via [scripts/run_fast_tests.sh], which starts chromedriver and invokes:
/// `flutter drive --driver=test_driver/integration_test.dart
/// --target=integration_test/map_interaction_test.dart -d chrome`
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerMapInteractionTests(binding: binding);
}
