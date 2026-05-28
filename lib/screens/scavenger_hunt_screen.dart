import 'dart:io';

import 'package:camera/camera.dart';
import 'package:english_learning_app/app_config.dart';
import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/daily_mission.dart';
import 'package:english_learning_app/models/scavenger_hunt_challenge.dart';
import 'package:english_learning_app/providers/daily_mission_provider.dart';
import 'package:english_learning_app/providers/spark_overlay_controller.dart';
import 'package:english_learning_app/services/gemini_proxy_service.dart';
import 'package:english_learning_app/services/scavenger_hunt_service.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:english_learning_app/services/spark_voice_service.dart';
import 'package:english_learning_app/widgets/scavenger_teaching_moment_sheet.dart';
import 'package:english_learning_app/widgets/ui/glass_card.dart';
import 'package:english_learning_app/widgets/living_spark.dart';
import 'package:english_learning_app/widgets/ui/_barrel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// Interactive "find it in the real world" camera game powered by Spark + Gemini proxy.
class ScavengerHuntScreen extends StatefulWidget {
  const ScavengerHuntScreen({
    super.key,
    required this.geminiProxy,
    this.roundsPerSession = 5,
  });

  final GeminiProxyService geminiProxy;
  final int roundsPerSession;

  @override
  State<ScavengerHuntScreen> createState() => _ScavengerHuntScreenState();
}

enum _HuntPhase {
  loading,
  ready,
  validating,
  success,
  retry,
  sessionDone,
  error,
}

class _ScavengerHuntScreenState extends State<ScavengerHuntScreen> {
  late final ScavengerHuntService _huntService;
  late final SparkVoiceService _sparkVoice;
  late List<ScavengerHuntChallenge> _challenges;

  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;
  bool _useImagePickerFallback = false;

  _HuntPhase _phase = _HuntPhase.loading;
  int _roundIndex = 0;
  String? _feedbackText;
  bool _showSuccessBurst = false;

  ScavengerHuntChallenge get _currentChallenge => _challenges[_roundIndex];

  @override
  void initState() {
    super.initState();
    _huntService = ScavengerHuntService(widget.geminiProxy);
    _sparkVoice = SparkVoiceService();
    _challenges =
        _huntService.startSession(rounds: widget.roundsPerSession);
    _initCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announceChallenge());
  }

  Future<void> _initCamera() async {
    if (kIsWeb) {
      setState(() {
        _useImagePickerFallback = true;
        _phase = _HuntPhase.ready;
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _useImagePickerFallback = true;
          _phase = _HuntPhase.ready;
        });
        return;
      }

      final controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _cameraController = controller;
      _cameraInitFuture = controller.initialize();
      await _cameraInitFuture;

      if (!mounted) return;
      setState(() => _phase = _HuntPhase.ready);
    } catch (error) {
      debugPrint('ScavengerHunt camera init failed: $error');
      if (!mounted) return;
      setState(() {
        _useImagePickerFallback = true;
        _phase = _HuntPhase.ready;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _announceChallenge() async {
    final prompt = _currentChallenge.promptHebrew;
    await _sparkVoice.speak(
      text: SparkStrings.scavengerSparkIntro(prompt),
      emotion: SparkEmotion.teaching,
    );
  }

  Future<void> _captureAndValidate() async {
    if (_phase == _HuntPhase.validating) return;

    setState(() {
      _phase = _HuntPhase.validating;
      _feedbackText = SparkStrings.scavengerValidating;
      _showSuccessBurst = false;
    });

    context.read<SparkOverlayController>().markThinking();

    Uint8List? imageBytes;
    try {
      if (_useImagePickerFallback) {
        final picker = ImagePicker();
        final file = await picker.pickImage(source: ImageSource.camera);
        if (file == null) {
          if (!mounted) return;
          setState(() => _phase = _HuntPhase.ready);
          context.read<SparkOverlayController>().markIdle();
          return;
        }
        imageBytes = await file.readAsBytes();
      } else {
        final controller = _cameraController;
        if (controller == null || !controller.value.isInitialized) {
          throw StateError('Camera not ready');
        }
        await _cameraInitFuture;
        final photo = await controller.takePicture();
        imageBytes = await File(photo.path).readAsBytes();
      }
    } catch (error) {
      debugPrint('ScavengerHunt capture error: $error');
      if (!mounted) return;
      setState(() {
        _phase = _HuntPhase.error;
        _feedbackText = SparkStrings.cameraGenericFail;
      });
      context.read<SparkOverlayController>().markIdle();
      return;
    }

    final result = await _huntService.validateFind(
      imageBytes,
      _currentChallenge,
    );

    if (!mounted) return;

    if (result.approved) {
      await _onRoundSuccess(
        result.feedbackHebrew ?? SparkStrings.randomCompliment(),
        imageBytes,
      );
    } else {
      await _onRoundRetry(result.feedbackHebrew ?? SparkStrings.scavengerTryAgain(
          _currentChallenge.promptHebrew));
    }
  }

  Future<void> _onRoundSuccess(String message, Uint8List imageBytes) async {
    context.read<SoundService>().playSuccessSound();
    context.read<SparkOverlayController>().markCelebrating();
    context.read<DailyMissionProvider>().incrementByType(DailyMissionType.camera);

    setState(() {
      _phase = _HuntPhase.success;
      _feedbackText = message;
      _showSuccessBurst = true;
    });

    await _sparkVoice.speak(
      text: message,
      emotion: SparkEmotion.excited,
    );

    if (!mounted) return;

    await Celebration.fire(context, tier: CelebrationTier.small);

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final isLastRound = _roundIndex >= _challenges.length - 1;

    setState(() => _showSuccessBurst = false);

    await _presentTeachingMoment(
      imageBytes,
      isLastRound: isLastRound,
    );
  }

  Future<void> _presentTeachingMoment(
    Uint8List imageBytes, {
    required bool isLastRound,
  }) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ScavengerTeachingMomentSheet(
        geminiProxy: widget.geminiProxy,
        imageBytes: imageBytes,
        challenge: _currentChallenge,
        isLastRound: isLastRound,
        onContinue: () => Navigator.pop(sheetContext),
      ),
    );

    if (!mounted) return;
    await _advanceAfterTeachingMoment(isLastRound: isLastRound);
  }

  Future<void> _advanceAfterTeachingMoment({required bool isLastRound}) async {
    if (isLastRound) {
      setState(() {
        _phase = _HuntPhase.sessionDone;
        _feedbackText = SparkStrings.scavengerSessionComplete;
      });
      await _sparkVoice.speak(
        text: SparkStrings.scavengerSessionComplete,
        emotion: SparkEmotion.excited,
      );
      if (!mounted) return;
      context.read<SparkOverlayController>().markCelebrating();
      return;
    }

    setState(() {
      _roundIndex += 1;
      _phase = _HuntPhase.ready;
      _feedbackText = SparkStrings.scavengerNextRound;
    });
    context.read<SparkOverlayController>().markIdle();

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await _announceChallenge();
  }

  Future<void> _onRoundRetry(String message) async {
    context.read<SparkOverlayController>().setEmotion(SparkEmotion.empathetic);
    setState(() {
      _phase = _HuntPhase.retry;
      _feedbackText = message;
    });
    await _sparkVoice.speak(
      text: message,
      emotion: SparkEmotion.empathetic,
    );
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _phase = _HuntPhase.ready;
      _feedbackText = null;
    });
    context.read<SparkOverlayController>().markIdle();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_roundIndex + 1) / _challenges.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text(
          SparkStrings.scavengerTitle,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraLayer(),
          _buildGradientOverlay(),
          SafeArea(
            child: Column(
              children: [
                _buildProgressBar(progress),
                const SizedBox(height: 8),
                _buildChallengeCard(),
                const Spacer(),
                if (_feedbackText != null) _buildFeedbackBanner(),
                const SizedBox(height: 12),
                _buildSparkRow(),
                const SizedBox(height: 16),
                _buildCaptureControl(),
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (_showSuccessBurst) _buildSuccessBurst(),
          if (_phase == _HuntPhase.validating) _buildValidatingOverlay(),
          if (_phase == _HuntPhase.sessionDone) _buildSessionDoneOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraLayer() {
    if (_phase == _HuntPhase.loading) {
      return const ColoredBox(
        color: Color(0xFF1B263B),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                SparkStrings.scavengerLoading,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (_useImagePickerFallback) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF415A77), Color(0xFF1B263B)],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.photo_camera_front_rounded,
            size: 120,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
      );
    }

    final controller = _cameraController;
    if (controller == null || _cameraInitFuture == null) {
      return const ColoredBox(color: Color(0xFF1B263B));
    }

    return FutureBuilder<void>(
      future: _cameraInitFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        return CameraPreview(controller);
      },
    );
  }

  Widget _buildGradientOverlay() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.45),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.55),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${SparkStrings.scavengerRoundLabel} ${_roundIndex + 1}/${_challenges.length}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              color: const Color(0xFFFFD93D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard() {
    final challenge = _currentChallenge;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        borderRadius: 24,
        surfaceOpacity: 0.28,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              challenge.emoji,
              style: const TextStyle(fontSize: 42),
            )
                .animate(
                  onPlay: (c) => c.repeat(reverse: true),
                )
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.08, 1.08),
                  duration: 1200.ms,
                ),
            const SizedBox(height: 8),
            Text(
              challenge.promptHebrew,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            if (challenge.englishHint != null) ...[
              const SizedBox(height: 6),
              Text(
                challenge.englishHint!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildFeedbackBanner() {
    final isSuccess = _phase == _HuntPhase.success;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassCard(
        borderRadius: 20,
        surfaceOpacity: 0.35,
        backgroundColor: isSuccess
            ? Colors.green.withValues(alpha: 0.35)
            : Colors.orange.withValues(alpha: 0.25),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          _feedbackText!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 250.ms)
        .shake(hz: isSuccess ? 2 : 3, duration: 400.ms);
  }

  Widget _buildSparkRow() {
    final emotion = switch (_phase) {
      _HuntPhase.validating => SparkEmotion.teaching,
      _HuntPhase.success || _HuntPhase.sessionDone => SparkEmotion.excited,
      _HuntPhase.retry => SparkEmotion.empathetic,
      _ => SparkEmotion.happy,
    };

    return LivingSpark(emotion: emotion, size: 88);
  }

  Widget _buildCaptureControl() {
    final canCapture =
        _phase == _HuntPhase.ready || _phase == _HuntPhase.retry;

    return Column(
      children: [
        GestureDetector(
          onTap: canCapture ? _captureAndValidate : null,
          child: AnimatedOpacity(
            opacity: canCapture ? 1 : 0.45,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFFFFD93D), width: 4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD93D).withValues(alpha: 0.45),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 36,
                color: Color(0xFF0D1B2A),
              ),
            ),
          ),
        )
            .animate(target: canCapture ? 1 : 0)
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.06, 1.06),
              duration: 900.ms,
            ),
        const SizedBox(height: 10),
        Text(
          _useImagePickerFallback
              ? SparkStrings.scavengerUsePicker
              : SparkStrings.scavengerTapToCapture,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildValidatingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFFFD93D)),
            SizedBox(height: 16),
            Text(
              SparkStrings.scavengerValidating,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessBurst() {
    return IgnorePointer(
      child: Center(
        child: const Icon(
          Icons.star_rounded,
          color: Color(0xFFFFD93D),
          size: 120,
        )
            .animate()
            .scale(
              begin: const Offset(0.2, 0.2),
              end: const Offset(1.4, 1.4),
              duration: 500.ms,
              curve: Curves.elasticOut,
            )
            .fadeOut(delay: 400.ms, duration: 300.ms),
      ),
    );
  }

  Widget _buildSessionDoneOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: GlassCard(
            borderRadius: 28,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                const Text(
                  SparkStrings.scavengerSessionComplete,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                KidButton.primary(
                  label: 'סיום',
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the scavenger hunt when the Gemini proxy endpoint is configured.
Future<void> openScavengerHunt(BuildContext context) async {
  final endpoint = AppConfig.geminiProxyEndpoint;
  final proxy = GeminiProxyService(endpoint);
  await Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ScavengerHuntScreen(geminiProxy: proxy),
    ),
  );
  proxy.dispose();
}
