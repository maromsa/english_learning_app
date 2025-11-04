import 'dart:collection';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class TelemetryService {
  TelemetryService({FirebaseAnalytics? analytics, this.enableDebugLogging = kDebugMode})
      : _analytics = analytics ?? _tryGetAnalytics();

  final FirebaseAnalytics? _analytics;
  final bool enableDebugLogging;
  final Map<String, DateTime> _activeSessions = HashMap<String, DateTime>();

  static FirebaseAnalytics? _tryGetAnalytics() {
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  static TelemetryService? maybeOf(BuildContext context, {bool listen = false}) {
    try {
      return Provider.of<TelemetryService>(context, listen: listen);
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> logOnboardingTipsShown({
    required List<String> tipIds,
    required List<String> appliedRules,
    required bool returningLearner,
  }) {
    return _logEvent('onboarding_tips_shown', {
      'tip_count': tipIds.length,
      'tip_ids': _flattenList(tipIds),
      'rule_ids': _flattenList(appliedRules),
      'returning': returningLearner,
    });
  }

  Future<void> logOnboardingCompleted({
    required List<String> tipIds,
    required bool returningLearner,
    required List<String> appliedRules,
    required int millisecondsToComplete,
  }) {
    return _logEvent('onboarding_completed', {
      'tip_count': tipIds.length,
      'tip_ids': _flattenList(tipIds),
      'rule_ids': _flattenList(appliedRules),
      'returning': returningLearner,
      'elapsed_ms': millisecondsToComplete,
    });
  }

  Future<void> logCameraValidation({
    required String word,
    required bool accepted,
    required String validatorType,
    double? confidence,
  }) {
    return _logEvent('camera_validation', {
      'word': _truncate(word),
      'accepted': accepted,
      'validator_type': _truncate(validatorType, maxLength: 24),
      if (confidence != null) 'confidence': confidence,
    });
  }

  Future<void> logQuizAnswered({
    required String word,
    required bool correct,
    required int reward,
    required int streak,
    required int questionIndex,
    bool hintUsed = false,
  }) {
    return _logEvent('quiz_answered', {
      'word': _truncate(word),
      'correct': correct,
      'reward': reward,
      'streak': streak,
      'question_index': questionIndex,
      'hint_used': hintUsed,
    });
  }

  Future<void> logHintUsed({
    required String word,
    required int optionsRemaining,
  }) {
    return _logEvent('hint_used', {
      'word': _truncate(word),
      'options_remaining': optionsRemaining,
    });
  }

  void startScreenSession(String screenName) {
    _activeSessions[screenName] = DateTime.now();
  }

  Future<void> endScreenSession(String screenName, {Map<String, Object?> extra = const {}}) {
    final start = _activeSessions.remove(screenName);
    if (start == null) {
      return Future<void>.value();
    }
    final durationMs = DateTime.now().difference(start).inMilliseconds;
    return _logEvent('screen_session', {
      'screen': _truncate(screenName, maxLength: 24),
      'duration_ms': durationMs,
      ...extra,
    });
  }

  Future<void> _logEvent(String name, Map<String, Object?> params) async {
    final sanitized = <String, Object>{};
    params.forEach((key, value) {
      if (value == null) {
        return;
      }
      if (value is bool) {
        sanitized[key] = value ? 1 : 0;
      } else {
        sanitized[key] = value as Object;
      }
    });

    final analytics = _analytics;
    if (analytics != null) {
      try {
        await analytics.logEvent(name: name, parameters: sanitized);
        return;
      } catch (error) {
        if (enableDebugLogging) {
          debugPrint('[Telemetry] logEvent failed for $name: $error');
        }
      }
    }

    if (enableDebugLogging) {
      debugPrint('[Telemetry] $name -> $sanitized');
    }
  }

  static String _flattenList(List<String> values, {int maxValues = 6}) {
    if (values.isEmpty) {
      return 'none';
    }
    return values.take(maxValues).map((value) => _truncate(value)).join('|');
  }

  static String _truncate(String value, {int maxLength = 32}) {
    if (value.length <= maxLength) {
      return value;
    }
    return value.substring(0, maxLength);
  }
}
