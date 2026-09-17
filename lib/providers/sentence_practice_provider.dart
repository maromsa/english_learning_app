import 'package:flutter/foundation.dart';

import '../models/sentence_question.dart';
import '../services/gemini_sentence_service.dart';

/// Session queue for [SentencePracticeScreen].
///
/// Starts from the offline catalog (or any seed list). When that queue is
/// exhausted, optionally asks [GeminiSentenceService] for more sentences so
/// practice can keep going. A failed / empty Gemini reply leaves the queue
/// unchanged so the child can still finish on the static set.
class SentencePracticeProvider extends ChangeNotifier {
  SentencePracticeProvider({
    required List<SentenceQuestion> initial,
    GeminiSentenceService? gemini,
    this.refillCount = GeminiSentenceService.defaultCount,
  })  : _gemini = gemini,
        _queue = initial.where((q) => q.isPlayable).toList();

  GeminiSentenceService? _gemini;
  final List<SentenceQuestion> _queue;
  final int refillCount;

  bool _isLoadingAi = false;
  bool _aiExhausted = false;
  int _refillAttempts = 0;
  Future<bool>? _inFlight;

  static const int maxRefills = 4;

  List<SentenceQuestion> get questions => List.unmodifiable(_queue);
  bool get isLoadingAi => _isLoadingAi;
  bool get canRefill =>
      _gemini != null && !_aiExhausted && _refillAttempts < maxRefills;

  /// Used after the first frame when the screen reads Gemini from [Provider].
  void attachGemini(GeminiSentenceService? gemini) {
    _gemini = gemini;
  }

  /// Fetches more sentences when the static queue is empty (or the caller
  /// is about to run out). Returns true if at least one playable sentence
  /// was appended.
  Future<bool> refillIfNeeded() {
    return _inFlight ??= _refill().whenComplete(() {
      _inFlight = null;
    });
  }

  Future<bool> _refill() async {
    if (!canRefill) return false;
    _isLoadingAi = true;
    notifyListeners();
    var appended = false;
    try {
      _refillAttempts++;
      final avoid = _queue.map((q) => q.fullEnglishSentence).toList();
      final fresh = await _gemini!.generateSentences(
        count: refillCount,
        avoid: avoid,
      );
      final existing = {
        for (final q in _queue) q.fullEnglishSentence.toLowerCase(),
      };
      for (final question in fresh) {
        if (!question.isPlayable) continue;
        if (!existing.add(question.fullEnglishSentence.toLowerCase())) {
          continue;
        }
        _queue.add(question);
        appended = true;
      }
      if (!appended) {
        _aiExhausted = true;
      }
    } catch (error, stackTrace) {
      debugPrint('SentencePracticeProvider refill failed: $error\n$stackTrace');
      _aiExhausted = true;
    } finally {
      _isLoadingAi = false;
      notifyListeners();
    }
    return appended;
  }
}
