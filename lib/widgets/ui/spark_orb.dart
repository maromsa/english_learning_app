import 'dart:math' as math;

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/utils/aurora_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Lifecycle state for the Spark mic orb.
enum OrbState { idle, listening, thinking, success }

/// Organic mic orb for child-facing speech flows (ages 5–10).
///
/// Four visual states: idle breathe, listening rings + sound swell,
/// thinking orbit dots, success mint punch.
class SparkOrb extends StatefulWidget {
  const SparkOrb({
    super.key,
    required this.state,
    this.soundLevel = 0.0,
    this.onTap,
    this.size = 180,
  });

  final OrbState state;
  final double soundLevel;
  final VoidCallback? onTap;
  final double size;

  /// Static helper for design QA — returns a [Wrap] of all four states.
  static Widget preview() {
    return const Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        SparkOrb(state: OrbState.idle, size: 120),
        SparkOrb(state: OrbState.listening, soundLevel: 0.65, size: 120),
        SparkOrb(state: OrbState.thinking, size: 120),
        SparkOrb(state: OrbState.success, size: 120),
      ],
    );
  }

  @override
  State<SparkOrb> createState() => _SparkOrbState();
}

class _SparkOrbState extends State<SparkOrb> with SingleTickerProviderStateMixin {
  static const Color _highlight = Color(0xFFFFE7E0);

  late AnimationController _orbitController;
  int _successTick = 0;
  double _reduceMotionOpacity = 1.0;
  double _reduceMotionTarget = 0.7;

  double get _orbDiameter => widget.size * 0.78;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncOrbitController();
  }

  @override
  void didUpdateWidget(SparkOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == OrbState.success &&
        oldWidget.state != OrbState.success) {
      setState(() => _successTick++);
    }
    _syncOrbitController();
  }

  void _syncOrbitController() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.state == OrbState.thinking && !reduceMotion) {
      if (!_orbitController.isAnimating) {
        _orbitController.repeat();
      }
    } else {
      _orbitController
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _orbitController.dispose();
    super.dispose();
  }

  Color _mainColorForState(OrbState state) {
    switch (state) {
      case OrbState.idle:
        return AuroraTokens.coral.withValues(alpha: 0.6);
      case OrbState.listening:
        return AuroraTokens.coral;
      case OrbState.thinking:
        return AuroraTokens.plum;
      case OrbState.success:
        return AuroraTokens.mint;
    }
  }

  String _semanticsLabel(OrbState state) {
    switch (state) {
      case OrbState.idle:
        return SparkStrings.orbSemanticsIdle;
      case OrbState.listening:
        return SparkStrings.micListening;
      case OrbState.thinking:
        return SparkStrings.micChecking;
      case OrbState.success:
        return SparkStrings.orbSemanticsSuccess;
    }
  }

  Widget _buildOrbCore(Color mainColor) {
    return Container(
      width: _orbDiameter,
      height: _orbDiameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 0.95,
          colors: [
            _highlight,
            mainColor,
            mainColor.withValues(alpha: 0.92),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        boxShadow: AuroraTokens.glow(mainColor),
      ),
      child: Icon(
        Icons.mic_rounded,
        color: Colors.white,
        size: _orbDiameter * 0.4,
      ),
    );
  }

  Widget _buildPulseRing(int index) {
    return SizedBox(
      width: _orbDiameter,
      height: _orbDiameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AuroraTokens.coral.withValues(alpha: 0.9),
            width: 2.5,
          ),
        ),
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(),
          delay: Duration(milliseconds: index * 700),
        )
        .scaleXY(
          begin: 0.9,
          end: 1.5,
          duration: AuroraTokens.dBreathe,
          curve: Curves.easeInOut,
        )
        .fadeOut(duration: AuroraTokens.dBreathe);
  }

  Widget _buildOrbitingDots() {
    final orbitRadius = _orbDiameter * 0.6;
    return AnimatedBuilder(
      animation: _orbitController,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: List<Widget>.generate(3, (index) {
              final degrees = index * 120 + _orbitController.value * 360;
              final radians = degrees * math.pi / 180;
              final dx = orbitRadius * math.cos(radians);
              final dy = orbitRadius * math.sin(radians);
              return Transform.translate(
                offset: Offset(dx, dy),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  void _onReduceMotionPulseEnd() {
    if (!mounted) return;
    setState(() {
      _reduceMotionOpacity = _reduceMotionTarget;
      _reduceMotionTarget = _reduceMotionTarget == 1.0 ? 0.7 : 1.0;
    });
  }

  Widget _applyMotion(Widget orb, bool reduceMotion) {
    if (reduceMotion) {
      return orb;
    }

    if (widget.state == OrbState.listening) {
      final level = widget.soundLevel.clamp(0.0, 1.0);
      orb = AnimatedScale(
        scale: 1 + level * 0.35,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: orb,
      );
    }

    if (widget.state == OrbState.success) {
      return orb
          .animate(key: ValueKey<int>(_successTick))
          .scaleXY(
            begin: 1,
            end: 1.15,
            duration: 140.ms,
            curve: Curves.easeOut,
          )
          .then()
          .scaleXY(
            begin: 1.15,
            end: 1,
            duration: 220.ms,
            curve: Curves.easeInOut,
          );
    }

    if (widget.state == OrbState.idle || widget.state == OrbState.thinking) {
      final breatheMs = widget.state == OrbState.thinking
          ? (AuroraTokens.dBreathe.inMilliseconds * 1.35).round()
          : AuroraTokens.dBreathe.inMilliseconds;
      orb = orb
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scaleXY(
            begin: 1,
            end: 1.04,
            duration: Duration(milliseconds: breatheMs),
            curve: Curves.easeInOut,
          );
    }

    return orb;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final mainColor = _mainColorForState(widget.state);

    Widget orb = _buildOrbCore(mainColor);
    orb = _applyMotion(orb, reduceMotion);

    final stackChildren = <Widget>[
      if (!reduceMotion && widget.state == OrbState.listening) ...[
        for (var i = 0; i < 3; i++) _buildPulseRing(i),
      ],
      Center(child: orb),
      if (!reduceMotion && widget.state == OrbState.thinking)
        _buildOrbitingDots(),
    ];

    Widget content = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: stackChildren,
      ),
    );

    if (reduceMotion) {
      content = TweenAnimationBuilder<double>(
        key: ValueKey<double>(_reduceMotionOpacity),
        tween: Tween<double>(
          begin: _reduceMotionOpacity,
          end: _reduceMotionTarget,
        ),
        duration: const Duration(milliseconds: 3000),
        curve: Curves.easeInOut,
        onEnd: _onReduceMotionPulseEnd,
        builder: (context, opacity, child) {
          return Opacity(opacity: opacity, child: child);
        },
        child: content,
      );
    }

    return Semantics(
      label: _semanticsLabel(widget.state),
      button: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => HapticFeedback.lightImpact(),
        onTap: widget.onTap,
        child: content,
      ),
    );
  }
}
