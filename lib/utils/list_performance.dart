import 'package:flutter/material.dart';

/// Shared tuning for scrollable lists — reduces off-screen build work.
abstract final class ListPerformance {
  /// Default cache extent (logical pixels) for long lazy lists.
  static const double defaultCacheExtent = 320;

  static const ScrollPhysics bouncingPhysics = BouncingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );
}
