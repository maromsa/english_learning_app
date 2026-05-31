// lib/utils/map_view_registry_stub.dart
//
// Stub used on non-web platforms (Android, iOS, desktop).
// The function body is intentionally empty — registering a platform view
// is a no-op on these targets because the kIsWeb branch in the widget is
// never reached.

/// View-type identifier used as the key for [HtmlElementView].
const String kMap3dViewType = 'map_3d_iframe';

/// No-op on mobile/desktop. Called during widget initialization so that
/// the call-site in map_screen.dart compiles on every platform.
void registerMap3dView() {
  // Nothing to do outside Flutter Web.
}

/// No-op on mobile/desktop. Returns a no-op dispose callback.
void Function() setupMap3dLoadListener(void Function() onLoaded) => () {};

/// No-op on mobile/desktop. Returns a no-op dispose callback.
void Function() setupMap3dMessageListener(
  void Function(String type, Map<String, dynamic> payload) onMessage,
) =>
    () {};

/// No-op on mobile/desktop.
void postMessageToMap3dIframe(Map<String, dynamic> message) {}
