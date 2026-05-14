import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/spark_overlay_controller.dart';

/// Hides the global [LivingSparkOverlay] while this widget is mounted.
///
/// Uses ref-counting on [SparkOverlayController] so overlapping auth screens
/// do not flash Spark when switching between them.
class SparkOverlaySuppressor extends StatefulWidget {
  const SparkOverlaySuppressor({super.key, required this.child});

  final Widget child;

  @override
  State<SparkOverlaySuppressor> createState() => _SparkOverlaySuppressorState();
}

class _SparkOverlaySuppressorState extends State<SparkOverlaySuppressor> {
  SparkOverlayController? _spark;

  @override
  void initState() {
    super.initState();
    _spark = context.read<SparkOverlayController>();
    _spark!.beginSparkOverlaySuppress();
  }

  @override
  void dispose() {
    _spark?.endSparkOverlaySuppress();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
