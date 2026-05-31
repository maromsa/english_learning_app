// Web-only helpers for integration tests (postMessage bridge).
// ignore: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Waits until the 3D map iframe is present in the DOM (HtmlElementView mounted).
Future<bool> waitForMap3dIframe({
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final iframes = web.document.querySelectorAll('iframe');
    for (var i = 0; i < iframes.length; i++) {
      final node = iframes.item(i);
      if (node == null || !node.isA<web.HTMLIFrameElement>()) continue;
      final src = (node as web.HTMLIFrameElement).src;
      if (src.contains('map_3d') || src.contains('assets/assets/map_3d')) {
        return true;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return false;
}

/// Dispatches a [MessageEvent] on [web.window], matching iframe → parent postMessage.
void simulateMap3dPostMessage(Map<String, dynamic> message) {
  final event = web.MessageEvent(
    'message',
    web.MessageEventInit(data: message.jsify()),
  );
  web.window.dispatchEvent(event);
}

/// Signals map readiness (same types [setupMap3dLoadListener] accepts).
void signalMap3dLoaded() {
  simulateMap3dPostMessage(const {'type': 'map3d_loaded'});
}
