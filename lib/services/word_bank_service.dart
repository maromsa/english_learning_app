import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/learned_word.dart';

/// Local persistence for the child's Word Bank ("My Vocabulary").
///
/// State is **per-child**: the key is namespaced by profile id
/// (`user_<id>_word_bank`), matching `DailyStreakService` /
/// `AvatarInventoryService`. A signed-out guest falls back to a stable
/// `guest` prefix so their words survive until they create a profile.
///
/// Firebase-agnostic by design (CLAUDE.md §2.1) — an optional
/// [SharedPreferences] can be injected in tests.
class WordBankService {
  WordBankService({SharedPreferences? prefs}) : _injectedPrefs = prefs;

  final SharedPreferences? _injectedPrefs;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sharedPrefs async =>
      _injectedPrefs ?? (_prefs ??= await SharedPreferences.getInstance());

  static const String _guestPrefix = 'guest';

  String _key(String? userId) =>
      'user_${(userId == null || userId.isEmpty) ? _guestPrefix : userId}'
      '_word_bank';

  /// Loads persisted words for [userId], or an empty list if nothing has
  /// been saved yet or the stored value can't be parsed.
  Future<List<LearnedWord>> load(String? userId) async {
    try {
      final prefs = await _sharedPrefs;
      final raw = prefs.getString(_key(userId));
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final words = <LearnedWord>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          final word = LearnedWord.fromJson(Map<String, dynamic>.from(item));
          if (word.word.isEmpty) continue;
          words.add(word);
        } catch (e) {
          debugPrint('WordBankService: skipping malformed word: $e');
        }
      }
      return words;
    } catch (e) {
      debugPrint('Error loading word bank: $e');
      return const [];
    }
  }

  /// Persists [words] for [userId]. Best-effort: a write failure is
  /// logged and swallowed rather than thrown.
  Future<void> save(String? userId, List<LearnedWord> words) async {
    try {
      final prefs = await _sharedPrefs;
      final payload = words.map((w) => w.toJson()).toList();
      await prefs.setString(_key(userId), jsonEncode(payload));
    } catch (e) {
      debugPrint('Error saving word bank: $e');
    }
  }
}
