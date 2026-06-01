import 'dart:async';

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/pronunciation_feedback.dart';
import 'package:english_learning_app/services/kid_speech_service.dart';
import 'package:english_learning_app/services/speech_feedback_service.dart';
import 'package:english_learning_app/utils/aurora_tokens.dart';
import 'package:english_learning_app/widgets/bouncy_button.dart';
import 'package:english_learning_app/widgets/ui/spark_orb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Kid-friendly mic control: pulse while recording, live transcript, animated stars.
class PronunciationMicButton extends StatefulWidget {
  const PronunciationMicButton({
    super.key,
    required this.targetWord,
    required this.speechService,
    this.onFeedback,
    this.onListeningChanged,
    this.onEvaluatingChanged,
    this.enabled = true,
    this.height = 220,
  });

  final String targetWord;
  final SpeechFeedbackService speechService;
  final void Function(PronunciationFeedback feedback, String transcript)?
      onFeedback;
  final ValueChanged<bool>? onListeningChanged;
  final ValueChanged<bool>? onEvaluatingChanged;
  final bool enabled;
  final double height;

  @override
  State<PronunciationMicButton> createState() => _PronunciationMicButtonState();
}

class _PronunciationMicButtonState extends State<PronunciationMicButton>
    with TickerProviderStateMixin {
  bool _isListening = false;
  bool _isEvaluating = false;
  double _soundLevel = 0;
  String _transcript = '';
  String? _statusHint;
  PronunciationFeedback? _lastFeedback;
  int _displayedStars = 0;
  bool _lastAttemptSuccess = false;
  DateTime? _lastSuccessAt;

  late final AnimationController _starController;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void didUpdateWidget(PronunciationMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetWord != widget.targetWord) {
      _resetForNewWord();
    }
  }

  void _resetForNewWord() {
    setState(() {
      _transcript = '';
      _statusHint = null;
      _lastFeedback = null;
      _displayedStars = 0;
      _lastAttemptSuccess = false;
      _lastSuccessAt = null;
    });
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  OrbState get _orbState {
    final now = DateTime.now();
    if (_isListening) return OrbState.listening;
    if (_isEvaluating) return OrbState.thinking;
    if (_lastAttemptSuccess &&
        _lastSuccessAt != null &&
        now.difference(_lastSuccessAt!).inMilliseconds < 1400) {
      return OrbState.success;
    }
    return OrbState.idle;
  }

  String get _actionLabel {
    if (_statusHint != null) return _statusHint!;
    if (_isListening) return SparkStrings.micListening;
    if (_isEvaluating) return SparkStrings.micChecking;
    return SparkStrings.micSpeakBtn;
  }

  Future<void> _onMicPressed() async {
    if (!widget.enabled || _isListening || _isEvaluating) return;

    if (widget.speechService.isListening) {
      await _finishAndEvaluate();
      return;
    }

    setState(() {
      _isListening = true;
      _transcript = '';
      _statusHint = SparkStrings.micListening;
      _displayedStars = 0;
      _lastFeedback = null;
    });
    widget.onListeningChanged?.call(true);

    try {
      await widget.speechService.startListening(
        onTranscript: (text) {
          if (!mounted) return;
          setState(() => _transcript = text);
        },
        onFinalTranscript: (_) {
          if (!mounted || !_isListening) return;
          unawaited(_finishAndEvaluate());
        },
        onSoundLevel: (level) {
          if (!mounted) return;
          setState(() => _soundLevel = level);
        },
        onStatus: (status) {
          if (!mounted) return;
          if (KidSpeechService.isSessionEndStatus(status) &&
              _isListening &&
              !_isEvaluating) {
            unawaited(_finishAndEvaluate());
          }
        },
      );
    } on MicrophonePermissionException catch (error) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _soundLevel = 0;
        _statusHint = _permissionMessage(error.status);
      });
      widget.onListeningChanged?.call(false);
      _maybeShowSettingsSnack(error.status);
    } on SpeechRecognitionUnavailableException {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _statusHint = SparkStrings.micStartFailed;
      });
      widget.onListeningChanged?.call(false);
    } catch (error) {
      debugPrint('PronunciationMicButton listen error: $error');
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _statusHint = SparkStrings.micStartFailed;
      });
      widget.onListeningChanged?.call(false);
    }
  }

  Future<void> _finishAndEvaluate() async {
    if (_isEvaluating) return;

    setState(() {
      _isListening = false;
      _isEvaluating = true;
      _soundLevel = 0;
      _statusHint = SparkStrings.micChecking;
    });
    widget.onListeningChanged?.call(false);
    widget.onEvaluatingChanged?.call(true);

    try {
      await widget.speechService.stopListening();
    } catch (error) {
      debugPrint('PronunciationMicButton stop error: $error');
    }

    final heard = _transcript.trim();
    if (heard.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isEvaluating = false;
        _statusHint = SparkStrings.micHeardNothing;
      });
      widget.onEvaluatingChanged?.call(false);
      return;
    }

    try {
      final feedback = await widget.speechService.evaluatePronunciation(
        targetWord: widget.targetWord,
        transcribedText: heard,
      );

      if (!mounted) return;
      await _animateStars(feedback.stars);

      if (!mounted) return;
      setState(() {
        _lastFeedback = feedback;
        _lastAttemptSuccess = feedback.isStrongAttempt;
        _lastSuccessAt = feedback.isStrongAttempt ? DateTime.now() : null;
        _statusHint = null;
      });

      widget.onFeedback?.call(feedback, heard);
    } catch (error) {
      debugPrint('PronunciationMicButton evaluate error: $error');
      if (!mounted) return;
      setState(() {
        _statusHint = SparkStrings.micRetry;
      });
    } finally {
      if (mounted) {
        setState(() => _isEvaluating = false);
      } else {
        _isEvaluating = false;
      }
      widget.onEvaluatingChanged?.call(false);
    }
  }

  Future<void> _animateStars(int targetStars) async {
    for (var star = 1; star <= targetStars; star++) {
      if (!mounted) return;
      setState(() => _displayedStars = star);
      _starController.forward(from: 0);
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }
  }

  String _permissionMessage(MicrophoneAccessStatus status) {
    switch (status) {
      case MicrophoneAccessStatus.permanentlyDenied:
      case MicrophoneAccessStatus.restricted:
        return SparkStrings.micPermissionSettings;
      case MicrophoneAccessStatus.denied:
      case MicrophoneAccessStatus.unavailable:
        return SparkStrings.micPermissionAsk;
      case MicrophoneAccessStatus.granted:
        return SparkStrings.micPermissionAsk;
    }
  }

  void _maybeShowSettingsSnack(MicrophoneAccessStatus status) {
    if (status != MicrophoneAccessStatus.permanentlyDenied &&
        status != MicrophoneAccessStatus.restricted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: const Text(SparkStrings.micPermissionSettings),
        action: SnackBarAction(
          label: SparkStrings.micOpenSettings,
          onPressed: () {
            widget.speechService.openSystemSettings();
          },
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedbackMessage = _lastFeedback?.feedbackMessage;

    return SizedBox(
      height: widget.height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_transcript.isNotEmpty || _isListening)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TranscriptBubble(
                text: _transcript.isEmpty
                    ? SparkStrings.micListening
                    : _transcript,
                isLive: _isListening,
              ),
            ),
          if (feedbackMessage != null && !_isListening && !_isEvaluating)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FeedbackBubble(message: feedbackMessage),
            ),
          _StarRow(
            displayedStars: _displayedStars,
            animating: _isEvaluating || _displayedStars > 0,
            starController: _starController,
          ),
          const SizedBox(height: 6),
          if (_isListening || _isEvaluating)
            _MicCore(
              orbState: _orbState,
              soundLevel: _soundLevel,
              label: _actionLabel,
              onTap:
                  _isListening ? () => unawaited(_finishAndEvaluate()) : null,
            )
          else if (widget.enabled)
            BouncyButton(
              onPressed: () => unawaited(_onMicPressed()),
              child: _MicCore(
                orbState: _orbState,
                soundLevel: _soundLevel,
                label: _actionLabel,
                onTap: null,
              ),
            )
          else
            _MicCore(
              orbState: _orbState,
              soundLevel: _soundLevel,
              label: _actionLabel,
              onTap: null,
            ),
        ],
      ),
    );
  }
}

class _MicCore extends StatelessWidget {
  const _MicCore({
    required this.orbState,
    required this.soundLevel,
    required this.label,
    required this.onTap,
  });

  final OrbState orbState;
  final double soundLevel;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SparkOrb(
          state: orbState,
          soundLevel: soundLevel,
          onTap: onTap,
          size: 132,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _TranscriptBubble extends StatelessWidget {
  const _TranscriptBubble({required this.text, required this.isLive});

  final String text;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive ? AuroraTokens.coral : AuroraTokens.sky,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(left: 6),
              decoration: const BoxDecoration(
                color: AuroraTokens.coral,
                shape: BoxShape.circle,
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .fade(duration: 600.ms)
                .then()
                .fade(begin: 1, end: 0.3, duration: 600.ms),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: AuroraTokens.ink,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackBubble extends StatelessWidget {
  const _FeedbackBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AuroraTokens.plum, AuroraTokens.blueberry],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AuroraTokens.plum.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        textAlign: TextAlign.center,
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.15, end: 0);
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.displayedStars,
    required this.animating,
    required this.starController,
  });

  final int displayedStars;
  final bool animating;
  final AnimationController starController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          final filled = index < displayedStars;
          final star = Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: filled ? AuroraTokens.butter : Colors.white54,
            size: 32,
            shadows: filled
                ? [
                    Shadow(
                      color: AuroraTokens.butter.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          );

          if (!filled || !animating) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: star,
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedBuilder(
              animation: starController,
              builder: (context, child) {
                final scale = 0.85 + (starController.value * 0.35);
                return Transform.scale(scale: scale, child: child);
              },
              child: star,
            ),
          );
        }),
      ),
    );
  }
}
