// lib/services/difficulty_engine.dart
//
// DifficultyEngine — אדפטציה דינמית לקושי
//
// Tracks the learner's success rate in a sliding window of recent answers
// and emits a DifficultyLevel (easy / medium / hard) that other screens
// consume to adjust their parameters in real-time.
//
// Parameters adjusted per level:
//   Lightning:   timer speed (not yet), option count
//   ImageQuiz:   number of answer choices (2 / 3 / 4)
//
// The window has a minimum sample size before any adjustment is made, so
// the first few questions always run at the default (medium) difficulty.

import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DifficultyLevel {
  /// Success rate < 40 % — reduce options, show hints.
  easy,

  /// Success rate 40–75 % — standard experience.
  medium,

  /// Success rate > 75 % — add options, remove hints.
  hard,
}

/// Recommended parameters for a quiz question at a given difficulty.
class DifficultyParams {
  const DifficultyParams({
    required this.level,
    required this.optionCount,
    required this.showHint,
    required this.bonusMultiplier,
  });

  final DifficultyLevel level;

  /// How many answer choices to display (2 = easiest, 4 = hardest).
  final int optionCount;

  /// Whether to show the Hebrew hint below the word.
  final bool showHint;

  /// Coin reward multiplier (0.8× easy, 1× medium, 1.3× hard).
  final double bonusMultiplier;

  static const DifficultyParams easy = DifficultyParams(
    level: DifficultyLevel.easy,
    optionCount: 2,
    showHint: true,
    bonusMultiplier: 0.8,
  );

  static const DifficultyParams medium = DifficultyParams(
    level: DifficultyLevel.medium,
    optionCount: 3,
    showHint: false,
    bonusMultiplier: 1.0,
  );

  static const DifficultyParams hard = DifficultyParams(
    level: DifficultyLevel.hard,
    optionCount: 4,
    showHint: false,
    bonusMultiplier: 1.3,
  );
}

class DifficultyEngine extends ChangeNotifier {
  DifficultyEngine({
    int windowSize = 10,
    int minSamplesBeforeAdjust = 5,
    SharedPreferences? prefs,
    String? storageKey,
  })  : _windowSize = windowSize,
        _minSamples = minSamplesBeforeAdjust,
        _prefsFuture = prefs != null
            ? Future.value(prefs)
            : SharedPreferences.getInstance(),
        _storageKey = storageKey ?? _defaultKey;

  static const String _defaultKey = 'difficulty_engine.v1';

  final int _windowSize;
  final int _minSamples;
  final Future<SharedPreferences> _prefsFuture;
  final String _storageKey;

  // Ring buffer of recent answers: true = correct, false = incorrect.
  final Queue<bool> _window = Queue<bool>();
  DifficultyLevel _current = DifficultyLevel.medium;

  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Current difficulty level based on recent performance.
  DifficultyLevel get level => _current;

  /// Recommended parameters for the current difficulty.
  DifficultyParams get params {
    switch (_current) {
      case DifficultyLevel.easy:
        return DifficultyParams.easy;
      case DifficultyLevel.medium:
        return DifficultyParams.medium;
      case DifficultyLevel.hard:
        return DifficultyParams.hard;
    }
  }

  /// Success rate in [0, 1] over the current window. 0 if no samples yet.
  double get successRate {
    if (_window.isEmpty) return 0.5; // neutral default
    final correct = _window.where((b) => b).length;
    return correct / _window.length;
  }

  /// Total answers recorded in the current window.
  int get sampleCount => _window.length;

  /// Records a new answer and updates difficulty if the window is large enough.
  void recordAnswer(bool correct) {
    _window.addLast(correct);
    if (_window.length > _windowSize) _window.removeFirst();
    _updateLevel();
    _saveAsync();
  }

  /// Resets the window — call when starting a new session for a different level.
  void reset() {
    _window.clear();
    _current = DifficultyLevel.medium;
    _notify();
  }

  /// Restores persisted state (call once on app start or level open).
  Future<void> load(String levelId) async {
    try {
      final prefs = await _prefsFuture;
      final key = '${_storageKey}_$levelId';
      final raw = prefs.getString(key);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final answers = (json['answers'] as List<dynamic>?)
              ?.map((e) => e as bool)
              .toList() ??
          [];
      _window
        ..clear()
        ..addAll(answers.take(_windowSize));
      _updateLevel(notify: false);
    } catch (e) {
      debugPrint('DifficultyEngine.load: $e');
    }
  }

  Future<void> save(String levelId) async {
    try {
      final prefs = await _prefsFuture;
      final key = '${_storageKey}_$levelId';
      await prefs.setString(
        key,
        jsonEncode({'answers': _window.toList()}),
      );
    } catch (e) {
      debugPrint('DifficultyEngine.save: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _updateLevel({bool notify = true}) {
    if (_window.length < _minSamples) return; // Not enough data yet.

    final rate = successRate;
    DifficultyLevel next;
    if (rate < 0.40) {
      next = DifficultyLevel.easy;
    } else if (rate > 0.75) {
      next = DifficultyLevel.hard;
    } else {
      next = DifficultyLevel.medium;
    }

    if (next != _current) {
      _current = next;
      if (notify) _notify();
    }
  }

  void _saveAsync() {
    // Fire-and-forget — use a fixed key for in-session persistence.
    Future(() async {
      try {
        final prefs = await _prefsFuture;
        await prefs.setString(
          _storageKey,
          jsonEncode({'answers': _window.toList()}),
        );
      } catch (_) {}
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
