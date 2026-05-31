// lib/utils/map_view_registry_web.dart
//
// Web-only implementation. Imported exclusively on Flutter Web via the
// conditional export in map_view_registry.dart.
//
// Uses dart:ui_web (Flutter 3.16+) and package:web (the modern replacement
// for dart:html) so no deprecation warnings are emitted.
// This file is NEVER compiled on Android / iOS / desktop.

// ignore: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// View-type identifier — must match the string passed to [HtmlElementView].
/// IMPORTANT: this exact string must be used in HtmlElementView(viewType: kMap3dViewType).
const String kMap3dViewType = 'map_3d_iframe';

/// Registers the iframe factory with Flutter's platform-view registry.
///
/// Safe to call multiple times; the SDK silently ignores duplicate
/// registrations. Call this before the first [HtmlElementView] with
/// [kMap3dViewType] is built (e.g. in [State.initState]).
///
/// Asset path: Flutter Web compiles pubspec `assets/…` entries to
/// `build/web/assets/assets/…`, so the iframe must use the double prefix.
void registerMap3dView() {
  ui_web.platformViewRegistry.registerViewFactory(
    kMap3dViewType,
    (int viewId) {
      final iframe = web.document.createElement('iframe')
          as web.HTMLIFrameElement
        // Flutter Web quirk: root pubspec assets land under assets/assets/…
        ..src = 'assets/assets/map_3d/index.html'
        // Explicit size constraints are required to avoid unbounded-constraint
        // rendering errors (drawFrame / finalizeTree) in the Flutter Web pipeline.
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.position = 'absolute'
        ..style.top = '0'
        ..style.left = '0'
        // Allow ES-module scripts, same-origin access and pointer lock for Three.js.
        ..setAttribute(
          'sandbox',
          'allow-scripts allow-same-origin allow-forms allow-pointer-lock allow-modals',
        );
      return iframe;
    },
  );
}

/// Listens for iframe `postMessage` load signals and calls [onLoaded].
///
/// Handles both [main.js] (`3D_MAP_LOADED`) and [index.html] (`map3d_loaded`).
/// Returns a callback that removes the listener (call from [State.dispose]).
void Function() setupMap3dLoadListener(void Function() onLoaded) {
  void handleMessage(web.Event event) {
    if (!event.isA<web.MessageEvent>()) return;

    final data = (event as web.MessageEvent).data?.dartify();
    if (data is! Map) return;

    final type = data['type'];
    if (type == '3D_MAP_LOADED' || type == 'map3d_loaded') {
      debugPrint('3D map load signal received: $type');
      onLoaded();
    }
  }

  final listener = handleMessage.toJS;
  web.window.addEventListener('message', listener);

  return () {
    web.window.removeEventListener('message', listener);
  };
}

const _kMap3dLoadMessageTypes = {'3D_MAP_LOADED', 'map3d_loaded', 'map3d_load_error'};

/// Extracts the payload from an iframe [postMessage] body.
///
/// Supports both shapes used in this project:
/// - `{ type, data: { index: 0 } }` (MapChannel / [notifyFlutter])
/// - `{ type, index: 0 }` (flat parent postMessage)
Map<String, dynamic> _payloadFromPostMessage(Map data) {
  final nested = data['data'];
  if (nested is Map) {
    return Map<String, dynamic>.from(nested);
  }
  final payload = <String, dynamic>{};
  for (final entry in data.entries) {
    if (entry.key == 'type') continue;
    payload[entry.key.toString()] = entry.value;
  }
  return payload;
}

/// Listens for iframe `postMessage` events from the 3D map (e.g. `enter_level`).
///
/// Load-only signals are ignored here; use [setupMap3dLoadListener] for those.
/// Returns a dispose callback — call from [State.dispose].
void Function() setupMap3dMessageListener(
  void Function(String type, Map<String, dynamic> payload) onMessage,
) {
  void handleMessage(web.Event event) {
    if (!event.isA<web.MessageEvent>()) return;

    final data = (event as web.MessageEvent).data?.dartify();
    if (data is! Map) return;

    final type = data['type']?.toString();
    if (type == null || type.isEmpty) return;
    if (_kMap3dLoadMessageTypes.contains(type)) return;

    onMessage(type, _payloadFromPostMessage(data));
  }

  final listener = handleMessage.toJS;
  web.window.addEventListener('message', listener);

  return () {
    web.window.removeEventListener('message', listener);
  };
}

/// Sends a command to the map iframe via `contentWindow.postMessage`.
void postMessageToMap3dIframe(Map<String, dynamic> message) {
  final encoded = jsonEncode(message);
  final iframes = web.document.querySelectorAll('iframe');
  for (var i = 0; i < iframes.length; i++) {
    final node = iframes.item(i);
    if (node == null || !node.isA<web.HTMLIFrameElement>()) continue;
    final iframe = node as web.HTMLIFrameElement;
    if (!iframe.src.contains('map_3d')) continue;
    iframe.contentWindow?.postMessage(encoded.toJS, '*'.toJS);
  }
}
