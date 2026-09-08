import 'package:flutter/material.dart';

import '../l10n/spark_strings.dart';
import '../services/audio_settings.dart';
import '../services/spark_voice_service.dart';

/// A round 🔊 button that pronounces an English [word] aloud, with a subtle
/// pulse while the audio plays.
///
/// Audio routes through [SparkVoiceService] (ElevenLabs / Google TTS via the
/// authenticated proxy, with its own memory + disk cache and offline
/// handling). Playback is best-effort: if TTS is unavailable the button just
/// settles back to idle — it never blocks the screen or throws.
///
/// The mute setting ([AudioSettings.muted]) is respected: while muted a tap is
/// a no-op and no pulse plays.
///
/// [speak] is a test seam — supply a fake `(word) async => bool` to avoid the
/// real network service in widget tests. Production callers leave it null.
class WordSpeakerButton extends StatefulWidget {
  const WordSpeakerButton({
    super.key,
    required this.word,
    this.size = 44,
    this.color,
    this.semanticLabel,
    this.speak,
  });

  /// The English word to pronounce.
  final String word;

  /// Overall diameter of the button in logical pixels.
  final double size;

  /// Icon + tint colour. Defaults to the theme's primary colour.
  final Color? color;

  /// Accessibility label. Defaults to [SparkStrings.hearWordSemantics].
  final String? semanticLabel;

  /// Test seam: returns whether audio played. Defaults to [SparkVoiceService].
  final Future<bool> Function(String word)? speak;

  @override
  State<WordSpeakerButton> createState() => _WordSpeakerButtonState();
}

class _WordSpeakerButtonState extends State<WordSpeakerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<bool> _defaultSpeak(String word) =>
      SparkVoiceService().speak(text: word, isEnglish: true);

  Future<void> _handleTap() async {
    if (_playing || widget.word.trim().isEmpty || AudioSettings().muted) {
      return;
    }

    setState(() => _playing = true);
    // `.ignore()` so disposing mid-pulse (child navigates away) can't surface
    // a TickerCanceled as an unhandled async error.
    _pulse.repeat(reverse: true).ignore();
    try {
      await (widget.speak ?? _defaultSpeak)(widget.word);
    } catch (_) {
      // Best-effort: TTS failures must never surface to a child.
    } finally {
      if (mounted) {
        _pulse.stop();
        _pulse.value = 0;
        setState(() => _playing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label:
          widget.semanticLabel ?? SparkStrings.hearWordSemantics(widget.word),
      child: Material(
        color: color.withValues(alpha: 0.10),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _handleTap,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: ScaleTransition(
                scale: _scale,
                child: Icon(
                  _playing ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                  size: widget.size * 0.58,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
