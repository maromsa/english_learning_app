import 'package:english_learning_app/widgets/bouncy_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Primary call-to-action button for the app.
///
/// Wraps [BouncyButton] and triggers [HapticFeedback.lightImpact] on every tap
/// for consistent sensory feedback across the app.
class SparkButton extends StatelessWidget {
  const SparkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;

  void _onPressed() {
    HapticFeedback.lightImpact();
    onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Color effectiveBackground =
        backgroundColor ?? colorScheme.primaryContainer;
    final Color effectiveText = textColor ?? colorScheme.onPrimaryContainer;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: effectiveText),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: effectiveText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return BouncyButton(
      onPressed: _onPressed,
      enableHaptic: true,
      child: content,
    );
  }
}

