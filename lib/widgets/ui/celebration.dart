import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/providers/spark_overlay_controller.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:english_learning_app/services/spark_voice_service.dart';
import 'package:english_learning_app/utils/aurora_tokens.dart';
import 'package:english_learning_app/widgets/ui/kid_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Tiered celebration entry point — replaces inline [ConfettiController] usage.
enum CelebrationTier { micro, small, big, epic }

/// Routes success feedback to micro / small / big / epic experiences.
class Celebration {
  Celebration._();

  static Future<void> fire(
    BuildContext context, {
    required CelebrationTier tier,
    String? word,
    String? compliment,
    int coinsEarned = 0,
    int starsEarned = 0,
    Offset? burstOrigin,
  }) async {
    final sfx = context.read<SoundService>();
    final spark = context.read<SparkOverlayController>();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final effectiveCompliment = compliment ?? SparkStrings.randomCompliment();

    switch (tier) {
      case CelebrationTier.micro:
        await _fireMicro(
          context,
          sfx: sfx,
          spark: spark,
          reduceMotion: reduceMotion,
          word: word,
          compliment: effectiveCompliment,
        );
      case CelebrationTier.small:
        await _fireSmall(
          context,
          sfx: sfx,
          reduceMotion: reduceMotion,
          burstOrigin: burstOrigin,
        );
      case CelebrationTier.big:
        await _fireBig(
          context,
          sfx: sfx,
          spark: spark,
          reduceMotion: reduceMotion,
          word: word,
          compliment: effectiveCompliment,
          coinsEarned: coinsEarned,
          starsEarned: starsEarned,
        );
      case CelebrationTier.epic:
        await _fireEpic(context, sfx: sfx, reduceMotion: reduceMotion);
    }
  }

  static Future<void> _fireMicro(
    BuildContext context, {
    required SoundService sfx,
    required SparkOverlayController spark,
    required bool reduceMotion,
    String? word,
    required String compliment,
  }) async {
    sfx.playSoftChime();
    if (reduceMotion) {
      _showMicroBubble(context, word ?? compliment);
      return;
    }
    unawaited(spark.flash(SparkEmotion.happy));
  }

  static Future<void> _fireSmall(
    BuildContext context, {
    required SoundService sfx,
    required bool reduceMotion,
    Offset? burstOrigin,
  }) async {
    sfx.playPopSound();
    if (!reduceMotion) {
      await _confettiPuff(context, count: 12, origin: burstOrigin);
    }
  }

  static Future<void> _fireBig(
    BuildContext context, {
    required SoundService sfx,
    required SparkOverlayController spark,
    required bool reduceMotion,
    String? word,
    required String compliment,
    required int coinsEarned,
    required int starsEarned,
  }) async {
    sfx.playFanfare();
    spark.markCelebrating();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (dialogContext) => _BigBurstOverlay(
        word: word ?? '',
        compliment: compliment,
        coinsEarned: coinsEarned,
        starsEarned: starsEarned.clamp(0, 3),
        reduceMotion: reduceMotion,
        onDismiss: () {
          Navigator.of(dialogContext).pop();
        },
      ),
    );

    if (context.mounted) {
      spark.markIdle();
    }
  }

  static Future<void> _fireEpic(
    BuildContext context, {
    required SoundService sfx,
    required bool reduceMotion,
  }) async {
    sfx.playEpic();
    debugPrint('[FCM stub] Queued parent push notification: chapter complete');

    unawaited(
      SparkVoiceService().speak(
        text: SparkStrings.chapterDone,
        emotion: SparkEmotion.excited,
      ),
    );

    if (!context.mounted) return;

    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        fullscreenDialog: true,
        pageBuilder: (_, __, ___) => _EpicRiveCelebration(
          reduceMotion: reduceMotion,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  static void _showMicroBubble(BuildContext context, String text) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 24,
        right: 24,
        bottom: MediaQuery.paddingOf(ctx).bottom + 120,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AuroraTokens.s12,
                vertical: AuroraTokens.s8,
              ),
              decoration: BoxDecoration(
                color: AuroraTokens.plum.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AuroraTokens.rLg),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: GoogleFonts.heebo(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      entry.remove();
    });
  }
}

/// Short confetti puff overlay — auto-disposes after [duration].
Future<void> _confettiPuff(
  BuildContext context, {
  int count = 12,
  Offset? origin,
  Duration duration = const Duration(milliseconds: 600),
}) async {
  final overlay = Overlay.of(context);
  final controller = ConfettiController(duration: duration);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) {
      final alignment = origin != null
          ? Alignment(
              (origin.dx / MediaQuery.sizeOf(ctx).width) * 2 - 1,
              (origin.dy / MediaQuery.sizeOf(ctx).height) * 2 - 1,
            )
          : Alignment.center;

      return Positioned.fill(
        child: IgnorePointer(
          child: Align(
            alignment: alignment,
            child: ConfettiWidget(
              confettiController: controller,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: count,
              maxBlastForce: 18,
              minBlastForce: 6,
              emissionFrequency: 0.08,
              gravity: 0.15,
              colors: const [
                AuroraTokens.mint,
                AuroraTokens.plum,
                AuroraTokens.butter,
                AuroraTokens.coral,
                AuroraTokens.blueberry,
              ],
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);
  controller.play();
  await Future<void>.delayed(duration);
  controller.dispose();
  entry.remove();
}

/// Level-complete overlay: confetti, stars, coin shower, tap-to-dismiss.
class _BigBurstOverlay extends StatefulWidget {
  const _BigBurstOverlay({
    required this.word,
    required this.compliment,
    required this.coinsEarned,
    required this.starsEarned,
    required this.reduceMotion,
    required this.onDismiss,
  });

  final String word;
  final String compliment;
  final int coinsEarned;
  final int starsEarned;
  final bool reduceMotion;
  final VoidCallback onDismiss;

  @override
  State<_BigBurstOverlay> createState() => _BigBurstOverlayState();
}

class _BigBurstOverlayState extends State<_BigBurstOverlay> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    if (!widget.reduceMotion) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _dismiss() {
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismiss,
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: Colors.black.withValues(alpha: 0.4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!widget.reduceMotion)
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    AuroraTokens.mint,
                    AuroraTokens.plum,
                    AuroraTokens.butter,
                    AuroraTokens.coral,
                    AuroraTokens.blueberry,
                  ],
                ),
              ),
            Center(
              child: GestureDetector(
                onTap: () {},
                child: _BigCelebrationCard(
                  word: widget.word,
                  compliment: widget.compliment,
                  coinsEarned: widget.coinsEarned,
                  starsEarned: widget.starsEarned,
                  reduceMotion: widget.reduceMotion,
                  onContinue: _dismiss,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigCelebrationCard extends StatelessWidget {
  const _BigCelebrationCard({
    required this.word,
    required this.compliment,
    required this.coinsEarned,
    required this.starsEarned,
    required this.reduceMotion,
    required this.onContinue,
  });

  final String word;
  final String compliment;
  final int coinsEarned;
  final int starsEarned;
  final bool reduceMotion;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: math.min(MediaQuery.sizeOf(context).width * 0.88, 400),
          margin: const EdgeInsets.symmetric(horizontal: AuroraTokens.s12),
          padding: const EdgeInsets.fromLTRB(
            AuroraTokens.s12,
            AuroraTokens.s16,
            AuroraTokens.s12,
            AuroraTokens.s12,
          ),
          decoration: BoxDecoration(
            color: AuroraTokens.paper,
            borderRadius: BorderRadius.circular(AuroraTokens.rXl),
            boxShadow: AuroraTokens.softCard(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                compliment,
                textAlign: TextAlign.center,
                style: GoogleFonts.heebo(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AuroraTokens.plum,
                ),
              ),
              const SizedBox(height: AuroraTokens.s8),
              if (word.isNotEmpty)
                Text(
                  word,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                    color: AuroraTokens.ink,
                    height: 1.05,
                  ),
                ),
              const SizedBox(height: AuroraTokens.s8),
              _StarRevealRow(
                starsEarned: starsEarned,
                reduceMotion: reduceMotion,
              ),
              const SizedBox(height: AuroraTokens.s12),
              KidButton.primary(
                label: SparkStrings.continueBtn,
                onPressed: onContinue,
                fullWidth: true,
              ),
            ],
          ),
        ),
        if (coinsEarned > 0)
          Positioned.fill(
            child: _CoinShower(
              coinCount: math.min(coinsEarned * 2, 30),
              reduceMotion: reduceMotion,
            ),
          ),
      ],
    );
  }
}

class _StarRevealRow extends StatelessWidget {
  const _StarRevealRow({
    required this.starsEarned,
    required this.reduceMotion,
  });

  final int starsEarned;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(3, (index) {
        final earned = index < starsEarned;
        final star = Icon(
          Icons.star_rounded,
          size: 48,
          color: earned
              ? AuroraTokens.butter
              : AuroraTokens.inkMute.withValues(alpha: 0.35),
        );

        if (reduceMotion) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: star,
          );
        }

        final delayMs = index * 250;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: star
              .animate(delay: Duration(milliseconds: delayMs))
              .fadeIn(duration: const Duration(milliseconds: 200))
              .scale(
                begin: const Offset(0.2, 0.2),
                end: const Offset(1, 1),
                curve: Curves.elasticOut,
                duration: const Duration(milliseconds: 400),
              ),
        );
      }),
    );
  }
}

class _CoinShower extends StatefulWidget {
  const _CoinShower({
    required this.coinCount,
    required this.reduceMotion,
  });

  final int coinCount;
  final bool reduceMotion;

  @override
  State<_CoinShower> createState() => _CoinShowerState();
}

class _CoinShowerState extends State<_CoinShower>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (!widget.reduceMotion) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.sizeOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: List<Widget>.generate(widget.coinCount, (index) {
            final stagger = index / widget.coinCount;
            final t = ((_controller.value - stagger * 0.4).clamp(0.0, 1.0));
            final x =
                _random.nextDouble() * size.width * 0.7 + size.width * 0.1;
            final y = 40 + t * (size.height * 0.35);
            return Positioned(
              left: x,
              top: y,
              child: Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: Icon(
                  Icons.monetization_on_rounded,
                  color: AuroraTokens.butter,
                  size: 20 + _random.nextDouble() * 8,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Chapter-complete full-screen celebration (Rive stub until asset ships).
class _EpicRiveCelebration extends StatelessWidget {
  const _EpicRiveCelebration({required this.reduceMotion});

  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AuroraTokens.s12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!reduceMotion)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.elasticOut,
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AuroraTokens.butter,
                            AuroraTokens.plum.withValues(alpha: 0.2),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AuroraTokens.plum.withValues(alpha: 0.5),
                            blurRadius: 32,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        size: 96,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(
                      Icons.emoji_events_rounded,
                      size: 120,
                      color: AuroraTokens.butter,
                    ),
                  const SizedBox(height: AuroraTokens.s16),
                  Text(
                    SparkStrings.chapterDone,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.heebo(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AuroraTokens.s24),
                  KidButton.primary(
                    label: SparkStrings.continueBtn,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
