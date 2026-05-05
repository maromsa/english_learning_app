import 'dart:ui';

import 'package:flutter/material.dart';

/// Reusable glassmorphism card / overlay built on [BackdropFilter].
///
/// Uses blur sigma 10 and surface opacity 0.2 for a high-end frosted glass
/// effect. Intended for stats pills, banners, and bottom sheets.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.blurSigma = 10.0,
    this.surfaceOpacity = 0.2,
    this.borderColor,
    this.backgroundColor,
    this.padding,
  });

  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final double surfaceOpacity;
  final Color? borderColor;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveBackground = backgroundColor ??
        colorScheme.surface.withValues(alpha: surfaceOpacity);
    final effectiveBorderColor =
        borderColor ?? Colors.white.withValues(alpha: 0.45);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                effectiveBackground,
                effectiveBackground.withValues(alpha: surfaceOpacity + 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: effectiveBorderColor,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: padding ?? const EdgeInsets.all(12),
          child: child,
        ),
      ),
    );
  }
}

