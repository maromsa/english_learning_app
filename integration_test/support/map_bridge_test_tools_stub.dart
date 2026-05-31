/// Non-web stub — map bridge integration tests run on Chrome only.
Future<bool> waitForMap3dIframe({
  Duration timeout = const Duration(seconds: 30),
}) async {
  throw UnsupportedError('Map bridge integration tests require Flutter Web (Chrome).');
}

void simulateMap3dPostMessage(Map<String, dynamic> message) {
  throw UnsupportedError('Map bridge integration tests require Flutter Web (Chrome).');
}

void signalMap3dLoaded() {
  throw UnsupportedError('Map bridge integration tests require Flutter Web (Chrome).');
}
