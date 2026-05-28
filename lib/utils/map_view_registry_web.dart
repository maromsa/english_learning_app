// lib/utils/map_view_registry_web.dart
//
// Web-only implementation. Imported exclusively on Flutter Web via the
// conditional export in map_view_registry.dart.
//
// Uses dart:ui_web (Flutter 3.16+) and package:web (the modern replacement
// for dart:html) so no deprecation warnings are emitted.
// This file is NEVER compiled on Android / iOS / desktop.

// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

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
/// Asset path: Flutter Web serves pubspec assets under the `/assets/` prefix,
/// so `assets/map_3d/index.html` in pubspec becomes `assets/map_3d/index.html`
/// at runtime (NOT `assets/assets/…`).
void registerMap3dView() {
  ui_web.platformViewRegistry.registerViewFactory(
    kMap3dViewType,
    (int viewId) {
      final iframe = web.document.createElement('iframe')
          as web.HTMLIFrameElement
        // Correct web asset path: Flutter Web serves pubspec assets at /assets/<path>.
        // Use 'assets/map_3d/index.html' (single 'assets/' prefix).
        ..src = 'assets/map_3d/index.html'
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
