import 'package:english_learning_app/utils/aurora_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Primary tappable for child-facing flows (ages 5–10).
///
/// Encodes the Aurora UI contracts: 64pt minimum height, haptic on tap-down,
/// 3D press depth, and reduce-motion fallback.
///
/// ```dart
/// KidButton.primary(label: 'בואו נתחיל!', onPressed: _start);
/// KidButton.success(label: 'כל הכבוד!', onPressed: _next);
/// KidButton.warning(label: 'נסו שוב', onPressed: _retry);
/// ```
class KidButton extends StatefulWidget {
  const KidButton({
    super.key,
    required this.label,
    required this.color,
    required this.shadowColor,
    this.onPressed,
    this.leadingIcon,
    this.isLoading = false,
    this.fullWidth = false,
    this.useInkLabel = false,
  });

  final String label;
  final Color color;
  final Color shadowColor;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final bool isLoading;
  final bool fullWidth;
  final bool useInkLabel;

  /// Plum — for "Let's start", "Continue".
  factory KidButton.primary({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? leadingIcon,
    bool isLoading = false,
    bool fullWidth = false,
  }) {
    return KidButton(
      key: key,
      label: label,
      color: AuroraTokens.plum,
      shadowColor: const Color(0xFF5D2EBF),
      onPressed: onPressed,
      leadingIcon: leadingIcon,
      isLoading: isLoading,
      fullWidth: fullWidth,
    );
  }

  /// Mint — for "Correct!", positive confirmations.
  factory KidButton.success({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? leadingIcon,
    bool isLoading = false,
    bool fullWidth = false,
  }) {
    return KidButton(
      key: key,
      label: label,
      color: AuroraTokens.mint,
      shadowColor: const Color(0xFF1FA888),
      onPressed: onPressed,
      leadingIcon: leadingIcon,
      isLoading: isLoading,
      fullWidth: fullWidth,
    );
  }

  /// Butter — soft warnings, retries.
  factory KidButton.warning({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? leadingIcon,
    bool isLoading = false,
    bool fullWidth = false,
  }) {
    return KidButton(
      key: key,
      label: label,
      color: AuroraTokens.butter,
      shadowColor: const Color(0xFFE0A82E),
      onPressed: onPressed,
      leadingIcon: leadingIcon,
      isLoading: isLoading,
      fullWidth: fullWidth,
      useInkLabel: true,
    );
  }

  /// Static preview helper for design QA.
  static Widget preview() {
    return Wrap(
      spacing: AuroraTokens.s8,
      runSpacing: AuroraTokens.s8,
      alignment: WrapAlignment.center,
      children: [
        KidButton.primary(label: 'Primary', onPressed: () {}),
        KidButton.success(label: 'Success', onPressed: () {}),
        KidButton.warning(label: 'Warning', onPressed: () {}),
      ],
    );
  }

  @override
  State<KidButton> createState() => _KidButtonState();
}

class _KidButtonState extends State<KidButton>
    with SingleTickerProviderStateMixin {
  static const double _idleShadowOffset = 8;
  static const double _pressedShadowOffset = 2;
  static const double _pressedTranslateY = 6;

  late AnimationController _pressController;
  late Animation<double> _pressAnimation;

  double _reduceMotionOpacity = 1.0;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: AuroraTokens.dPress,
      reverseDuration: AuroraTokens.dBounce,
    );
    _pressAnimation = CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeIn,
      reverseCurve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  Future<void> _flashReduceMotionFeedback() async {
    setState(() => _reduceMotionOpacity = 0.7);
    await Future<void>.delayed(AuroraTokens.dPress);
    if (!mounted) return;
    setState(() => _reduceMotionOpacity = 1.0);
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_isEnabled) return;

    HapticFeedback.lightImpact();

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _flashReduceMotionFeedback();
      return;
    }

    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_isEnabled) return;

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      widget.onPressed?.call();
      return;
    }

    _pressController.reverse();
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    if (!_isEnabled) return;
    if (MediaQuery.of(context).disableAnimations) return;
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final theme = Theme.of(context);
    final labelColor = widget.useInkLabel ? AuroraTokens.ink : Colors.white;
    final iconColor = widget.useInkLabel ? AuroraTokens.ink : Colors.white;

    Widget buttonFace = AnimatedBuilder(
      animation: _pressAnimation,
      builder: (context, child) {
        final pressT =
            _isEnabled && !reduceMotion ? _pressAnimation.value : 0.0;
        final translateY = _pressedTranslateY * pressT;
        final shadowOffsetY = _idleShadowOffset +
            ((_pressedShadowOffset - _idleShadowOffset) * pressT);

        return Transform.translate(
          offset: Offset(0, translateY),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(AuroraTokens.rXl),
              boxShadow: [
                BoxShadow(
                  color: widget.shadowColor,
                  offset: Offset(0, shadowOffsetY),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.leadingIcon != null) ...[
                        Icon(widget.leadingIcon, size: 26, color: iconColor),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        widget.label,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: labelColor),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    if (reduceMotion) {
      buttonFace = Opacity(opacity: _reduceMotionOpacity, child: buttonFace);
    }

    buttonFace = Opacity(
      opacity: _isEnabled ? 1.0 : 0.6,
      child: buttonFace,
    );

    final tappable = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: buttonFace,
    );

    if (widget.fullWidth) {
      return SizedBox(width: double.infinity, child: tappable);
    }
    return tappable;
  }
}
