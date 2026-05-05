import 'package:flutter/foundation.dart';

/// Event describing that a learner has made meaningful progress on a word.
class WordMasteredEvent {
  const WordMasteredEvent({
    required this.userId,
    required this.levelId,
    required this.word,
    required this.masteryLevel,
  });

  final String userId;
  final String levelId;
  final String word;

  /// Mastery level in the range \[0.0, 1.0] after the latest update.
  final double masteryLevel;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'userId': userId,
        'levelId': levelId,
        'word': word,
        'masteryLevel': masteryLevel,
      };
}

typedef WordMasteredListener = void Function(WordMasteredEvent event);

/// Lightweight bridge between the learning logic (where words are practised)
/// and the 3D map (which lives inside a WebView on the map screen).
///
/// The service does not depend on Flutter widgets and can be safely used from
/// providers, repositories and services. The map screen will register a single
/// listener that forwards events to JavaScript (e.g. `spawnWordAsset`).
class MapBridgeService {
  MapBridgeService._();

  static final MapBridgeService _instance = MapBridgeService._();

  static MapBridgeService get instance => _instance;

  WordMasteredListener? _wordMasteredListener;

  /// Registers a listener that will be invoked whenever a word is marked as
  /// mastered. Only one active listener is supported at a time; registering a
  /// new one replaces the previous.
  void registerWordMasteredListener(WordMasteredListener listener) {
    _wordMasteredListener = listener;
  }

  /// Clears the current listener if it matches the provided instance.
  void unregisterWordMasteredListener(WordMasteredListener listener) {
    if (identical(_wordMasteredListener, listener)) {
      _wordMasteredListener = null;
    }
  }

  /// Emits a word-mastery event to any registered listener.
  void emitWordMastered(WordMasteredEvent event) {
    final listener = _wordMasteredListener;
    if (listener == null) {
      debugPrint(
        'MapBridgeService: word mastered event dropped (no listener registered) '
        'for level=${event.levelId}, word=${event.word}',
      );
      return;
    }

    try {
      listener(event);
    } catch (error, stackTrace) {
      debugPrint('MapBridgeService: listener error: $error');
      debugPrint('$stackTrace');
    }
  }
}

