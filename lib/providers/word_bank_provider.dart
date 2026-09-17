import 'package:flutter/foundation.dart';

import '../models/learned_word.dart';
import '../services/word_bank_service.dart';

/// Reactive owner of the child's Word Bank ("My Vocabulary").
///
/// Persistence is per-child and local-first (see [WordBankService]).
/// [now] is injectable so tests can pin [LearnedWord.dateLearned].
class WordBankProvider with ChangeNotifier {
  WordBankProvider({
    List<LearnedWord>? initial,
    WordBankService? service,
    DateTime Function()? now,
  })  : _words = List<LearnedWord>.from(initial ?? const []),
        _service = service ?? WordBankService(),
        _now = now ?? DateTime.now;

  final WordBankService _service;
  final DateTime Function() _now;
  List<LearnedWord> _words;
  String? _userId;
  bool _disposed = false;

  /// Newest-first, unmodifiable view of the bank.
  List<LearnedWord> get words => List.unmodifiable(_words);

  int get count => _words.length;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Points persistence at [userId]'s namespace (guest when null).
  void setUserId(String? userId) {
    _userId = userId;
  }

  /// Whether [word] is already in the bank (case-insensitive, trimmed).
  bool containsWord(String word) {
    final needle = word.trim().toLowerCase();
    if (needle.isEmpty) return false;
    return _words.any((entry) => entry.word.toLowerCase() == needle);
  }

  /// Loads the persisted bank for the current profile. Best-effort: a
  /// read failure leaves the previous (or empty) state in place.
  Future<void> load() async {
    try {
      _words = await _service.load(_userId);
      _notify();
    } catch (e) {
      debugPrint('Error loading word bank: $e');
    }
  }

  /// Adds [word] if it is not already present (case-insensitive).
  ///
  /// Empty / whitespace-only strings are ignored. Returns `true` when a
  /// new entry was stored, `false` when it was a no-op.
  Future<bool> addWord(String word, {String? translation}) async {
    if (_disposed) return false;
    final trimmed = word.trim();
    if (trimmed.isEmpty) return false;
    if (containsWord(trimmed)) return false;

    final trimmedTranslation = translation?.trim();
    _words = [
      LearnedWord(
        word: trimmed,
        translation: (trimmedTranslation == null || trimmedTranslation.isEmpty)
            ? null
            : trimmedTranslation,
        dateLearned: _now(),
      ),
      ..._words,
    ];
    await _service.save(_userId, _words);
    _notify();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
