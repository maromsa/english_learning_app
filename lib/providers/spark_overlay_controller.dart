import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/spark_voice_service.dart';

/// High-level animation/visibility state for the global Spark companion.
enum SparkOverlayAnimationState {
  idle,
  thinking,
  celebrating,
}

/// Where the Spark overlay is anchored on screen.
enum SparkOverlayPosition {
  bottomRight,
  bottomLeft,
  topRight,
  topLeft,
}

/// Controller for the global Spark overlay.
///
/// This is a [ChangeNotifier] so it can be provided via [ChangeNotifierProvider]
/// and consumed by the `LivingSpark` overlay widget on every screen.
/// Reacts to navigation (e.g. Map → Shop) with a brief animation state change.
class SparkOverlayController extends ChangeNotifier {
  SparkOverlayController();

  /// When > 0, the global Spark overlay is hidden (e.g. auth / onboarding).
  int _sparkOverlaySuppressDepth = 0;

  /// Manual visibility (e.g. future modal flows); combined with suppress depth.
  bool _userWantsSparkVisible = true;
  SparkEmotion _emotion = SparkEmotion.neutral;
  SparkOverlayAnimationState _animationState = SparkOverlayAnimationState.idle;
  SparkOverlayPosition _position = SparkOverlayPosition.bottomRight;
  String? _lastScreenLabel;

  /// True when Spark should render in [LivingSparkOverlay].
  bool get isVisible =>
      _sparkOverlaySuppressDepth == 0 && _userWantsSparkVisible;

  SparkEmotion get emotion => _emotion;
  SparkOverlayAnimationState get animationState => _animationState;
  SparkOverlayPosition get position => _position;

  /// Show Spark overlay (e.g. when entering map or learning flows).
  void show() {
    final was = isVisible;
    _userWantsSparkVisible = true;
    if (was != isVisible) {
      notifyListeners();
    }
  }

  /// Hide Spark overlay (e.g. on sensitive screens or full-screen modals).
  void hide() {
    final was = isVisible;
    _userWantsSparkVisible = false;
    if (was != isVisible) {
      notifyListeners();
    }
  }

  /// Increment suppress depth while an auth / onboarding subtree is mounted.
  /// Pair with [endSparkOverlaySuppress] in [dispose].
  void beginSparkOverlaySuppress() {
    final was = isVisible;
    _sparkOverlaySuppressDepth++;
    if (was != isVisible) {
      notifyListeners();
    }
  }

  /// Decrement suppress depth after [beginSparkOverlaySuppress].
  void endSparkOverlaySuppress() {
    if (_sparkOverlaySuppressDepth <= 0) {
      return;
    }
    final was = isVisible;
    _sparkOverlaySuppressDepth--;
    if (was != isVisible) {
      notifyListeners();
    }
  }

  /// Update Spark's emotional tone, typically driven by conversation or
  /// learning state.
  void setEmotion(SparkEmotion emotion) {
    if (_emotion == emotion) return;
    _emotion = emotion;
    notifyListeners();
  }

  /// Update the overlay's high-level animation state.
  ///
  /// - [idle]: gentle breathing / ambient motion.
  /// - [thinking]: subtle pulse while AI is generating.
  /// - [celebrating]: short celebration sequence after success.
  void setAnimationState(SparkOverlayAnimationState state) {
    if (_animationState == state) return;
    _animationState = state;
    notifyListeners();
  }

  /// Move Spark to a different screen corner.
  void setPosition(SparkOverlayPosition position) {
    if (_position == position) return;
    _position = position;
    notifyListeners();
  }

  /// Convenience helpers for common flows.
  void markThinking() {
    setAnimationState(SparkOverlayAnimationState.thinking);
    setEmotion(SparkEmotion.empathetic);
  }

  void markCelebrating() {
    setAnimationState(SparkOverlayAnimationState.celebrating);
    setEmotion(SparkEmotion.excited);
  }

  void markIdle() {
    setAnimationState(SparkOverlayAnimationState.idle);
    setEmotion(SparkEmotion.neutral);
  }

  /// Called when the user navigates to a new screen. Spark briefly reacts
  /// (e.g. happy) then returns to idle so the overlay feels responsive to
  /// navigation (Map, Shop, Missions, etc.) without blocking interaction.
  void onNavigatedToScreen(String screenLabel) {
    if (screenLabel == _lastScreenLabel) return;
    _lastScreenLabel = screenLabel;

    setEmotion(SparkEmotion.happy);
    setAnimationState(SparkOverlayAnimationState.idle);

    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      markIdle();
    });
  }
}

