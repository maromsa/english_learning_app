// lib/utils/map_view_registry.dart
//
// Conditional import: on Flutter Web the real web implementation is used;
// on every other platform (Android, iOS, desktop) the stub is used instead.
// This prevents dart:ui_web / dart:html from being compiled into mobile builds.

export 'map_view_registry_stub.dart'
    if (dart.library.ui_web) 'map_view_registry_web.dart';
