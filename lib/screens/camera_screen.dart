// lib/screens/camera_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_mission.dart';
import '../providers/daily_mission_provider.dart';
import '../services/ai_image_validator.dart';

/// A full-screen camera UI that optionally validates captured images via AI.
///
/// **Daily-mission integration:**
/// When the [targetWord] parameter is provided (non-null), the screen runs the
/// captured photo through [AiImageValidator] after each shot.  On a successful
/// match it automatically calls
/// `DailyMissionProvider.incrementByType(DailyMissionType.camera)` so the
/// "Photograph a learned object" daily mission advances in real-time.
///
/// When [targetWord] is null the screen behaves exactly as before — it simply
/// pops with the image file path, leaving any further processing to the caller.
class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.cameras,
    this.targetWord,
    this.validator,
  });

  final List<CameraDescription> cameras;

  /// The English word the user is trying to photograph (e.g. "apple").
  /// Providing this enables AI validation and daily-mission progress.
  final String? targetWord;

  /// Override the default [PassthroughAiImageValidator].
  /// Inject a real [HttpFunctionAiImageValidator] in production.
  final AiImageValidator? validator;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  int _selectedCameraIndex = 0;

  bool _isValidating = false;
  String? _validationMessage;

  AiImageValidator get _validator =>
      widget.validator ?? const PassthroughAiImageValidator();

  @override
  void initState() {
    super.initState();
    _initializeCamera(_selectedCameraIndex);
  }

  void _initializeCamera(int cameraIndex) {
    _controller = CameraController(
      widget.cameras[cameraIndex],
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _switchCamera() {
    if (widget.cameras.length > 1) {
      setState(() {
        _selectedCameraIndex =
            (_selectedCameraIndex + 1) % widget.cameras.length;
        _initializeCamera(_selectedCameraIndex);
        _validationMessage = null;
      });
    }
  }

  Future<void> _takePicture() async {
    if (_isValidating) return;

    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      if (!mounted) return;

      // If no target word is provided, behave exactly as before.
      if (widget.targetWord == null) {
        Navigator.pop(context, image.path);
        return;
      }

      // ── AI Validation flow ────────────────────────────────────────────────
      setState(() {
        _isValidating = true;
        _validationMessage = null;
      });

      final Uint8List imageBytes = await File(image.path).readAsBytes();
      final bool isValid = await _validator.validate(
        imageBytes,
        widget.targetWord!,
        mimeType: 'image/jpeg',
      );

      if (!mounted) return;

      if (isValid) {
        // Advance the camera daily mission progress.
        context
            .read<DailyMissionProvider>()
            .incrementByType(DailyMissionType.camera);

        setState(() {
          _isValidating = false;
          _validationMessage = '✅ מצוין! זיהינו את "${widget.targetWord}"';
        });

        // Brief pause so the user sees the success feedback, then pop.
        await Future.delayed(const Duration(milliseconds: 1400));
        if (mounted) Navigator.pop(context, image.path);
      } else {
        setState(() {
          _isValidating = false;
          _validationMessage =
              '❌ לא זיהינו "${widget.targetWord}". נסו שוב!';
        });
      }
    } catch (e) {
      debugPrint('Camera error: $e');
      if (mounted) {
        setState(() {
          _isValidating = false;
          _validationMessage = 'שגיאה בצילום. נסו שוב.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller),

                // ── Target word banner (top) ──────────────────────────────
                if (widget.targetWord != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'צלמו: ${widget.targetWord}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Validation feedback banner (centre) ───────────────────
                if (_validationMessage != null)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _validationMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                // ── Validating spinner ────────────────────────────────────
                if (_isValidating)
                  Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'בודק תמונה…',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Controls bar (bottom) ─────────────────────────────────
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.all(30.0),
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Empty space to balance the layout
                        const SizedBox(width: 64),

                        // Capture button
                        GestureDetector(
                          onTap: _isValidating ? null : _takePicture,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  _isValidating ? Colors.grey : Colors.white,
                              border: Border.all(color: Colors.grey, width: 3),
                            ),
                          ),
                        ),

                        // Switch camera button
                        IconButton(
                          onPressed:
                              _isValidating ? null : _switchCamera,
                          icon: Icon(
                            Icons.flip_camera_ios,
                            color: _isValidating
                                ? Colors.grey
                                : Colors.white,
                            size: 35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
