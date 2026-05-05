import 'package:flutter/material.dart';

import '../providers/spark_overlay_controller.dart';

/// NavigatorObserver that notifies [SparkOverlayController] when the user
/// navigates to a new screen, so Spark can briefly change animation state
/// (e.g. happy) when moving between Map, Shop, Missions, etc.
class SparkRouteObserver extends NavigatorObserver {
  SparkRouteObserver(this.controller);

  final SparkOverlayController controller;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final name = route.settings.name ?? 'screen_${route.hashCode}';
    controller.onNavigatedToScreen(name);
  }
}
