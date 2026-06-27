// lib/services/story_service.dart
//
// StoryService — generates personalised Gemini stories for the child.
//
// Flow:
//   1. Accept the child's vocabulary words (from current level).
//   2. Pick up to 5 words with the lowest mastery to feature in the story.
//   3. Build a structured prompt and call GeminiProxyService.generateStory().
//   4. Parse the JSON response into SparkStory with StoryPages.
//   5. For each page, fetch a Pixabay image matching the highlight word.
//   6. Cache the result for 24 hours so the child can re-read without re-generating.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/spark_story.dart';
import '../models/srs_card.dart';
import '../models/word_data.dart';
import 'gemini_proxy_service.dart';
import 'srs_service.dart';

class StoryService {
  StoryService({
    required GeminiProxyService proxyService,
    SrsService? srsService,
    SharedPreferences? prefs,
  })  : _proxy = proxyService,
        _srsService = srsService ?? SrsService(),
        _prefsFuture = prefs != null
            ? Future.value(prefs)
            : SharedPreferences.getInstance();

  static const String _cachePrefix = 'spark_story.v1';
  static const Duration _cacheMaxAge = Duration(hours: 24);

  final GeminiProxyService _proxy;
  final SrsService _srsService;
  final Future<SharedPreferences> _prefsFuture;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generates (or loads from cache) a story for [levelId] using [words].
  ///
  /// Picks the weakest words (lowest SRS mastery) to reinforce learning.
  /// Returns null if generation fails or the proxy is unavailable.
  Future<SparkStory?> getStory({
    required String userId,
    required String levelId,
    required List<WordData> words,
    bool forceRefresh = false,
  }) async {
    // Check cache first.
    if (!forceRefresh) {
      final cached = await _loadFromCache(userId, levelId);
      if (cached != null) return cached;
    }

    // Select featured words — weakest first.
    final featured = await _selectFeaturedWords(
      userId: userId,
      levelId: levelId,
      words: words,
    );
    if (featured.isEmpty) return null;

    // Generate story via Gemini.
    final story = await _generate(featured);
    if (story == null) return null;

    // Fetch images for each page (best-effort, non-blocking per page).
    final pagesWithImages = await _enrichWithImages(story);
    final enriched = SparkStory(
      title: story.title,
      titleHebrew: story.titleHebrew,
      pages: pagesWithImages,
      words: story.words,
      generatedAt: story.generatedAt,
    );

    // Persist to cache.
    await _saveToCache(userId, levelId, enriched);
    return enriched;
  }

  // ---------------------------------------------------------------------------
  // Word selection
  // ---------------------------------------------------------------------------

  Future<List<String>> _selectFeaturedWords({
    required String userId,
    required String levelId,
    required List<WordData> words,
    int maxWords = 5,
  }) async {
    // Load SRS cards for sorting by mastery.
    final cards = <SrsCard>[];
    for (final word in words) {
      try {
        final card = await _srsService.getCard(
          userId: userId,
          levelId: levelId,
          word: word.word,
        );
        cards.add(card);
      } catch (_) {}
    }

    // Sort by mastery ascending (weakest first), then pick top N.
    cards.sort((a, b) => a.masteryLevel.compareTo(b.masteryLevel));
    final selected = cards.take(maxWords).map((c) => c.wordId).toList();

    // Fall back to first N words if SRS data is empty.
    if (selected.isEmpty) {
      return words.take(maxWords).map((w) => w.word).toList();
    }
    return selected;
  }

  // ---------------------------------------------------------------------------
  // Gemini generation
  // ---------------------------------------------------------------------------

  Future<SparkStory?> _generate(List<String> words) async {
    final wordList = words.join(', ');
    final prompt = '''
You are Spark, a friendly AI for children learning English.
Generate a short, fun story (6 sentences) for a child aged 5-9.

Requirements:
- Use SIMPLE English words. Max 12 words per sentence.
- Include each of these vocabulary words in the story: $wordList
- Make it fun and imaginative. Include animals, adventure, or magic.
- BOLD the vocabulary word each time it appears (use **word** markdown).

Return ONLY valid JSON in this exact format (no markdown, no extra text):
{
  "title": "Spark and the Magic Adventure",
  "titleHebrew": "ספארק והרפתקה הקסומה",
  "pages": [
    {
      "english": "Spark found a tiny **apple** in the forest.",
      "hebrew": "ספארק מצא תפוח קטן ביער.",
      "highlightWord": "apple"
    },
    {
      "english": "The **apple** glowed with magic light!",
      "hebrew": "התפוח זרח באור קסם!",
      "highlightWord": "apple"
    }
  ],
  "words": ["apple"]
}

Rules:
- Exactly 6 pages.
- Each page must have: english, hebrew, highlightWord.
- highlightWord must be one of: $wordList
- Do NOT include imageUrl in the JSON.
- Respond ONLY with the JSON object. No markdown code fences.
''';

    try {
      final raw = await _proxy.generateStory(prompt);
      if (raw == null || raw.trim().isEmpty) return null;
      return _parseStoryJson(raw, words);
    } catch (e) {
      debugPrint('StoryService._generate: $e');
      return null;
    }
  }

  SparkStory? _parseStoryJson(String raw, List<String> words) {
    try {
      // Strip code fences if Gemini adds them despite instructions.
      var cleaned = raw.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceFirst(RegExp(r'^```[a-z]*\n?'), '')
            .replaceFirst(RegExp(r'```$'), '')
            .trim();
      }

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final story = SparkStory.fromJson(json);

      if (story.pages.isEmpty) {
        debugPrint('StoryService: parsed story has no pages');
        return null;
      }
      return story;
    } catch (e) {
      debugPrint('StoryService._parseStoryJson: $e\nRaw: $raw');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Image enrichment
  // ---------------------------------------------------------------------------

  Future<List<StoryPage>> _enrichWithImages(SparkStory story) async {
    final enriched = <StoryPage>[];
    // Track which words already have images to avoid duplicates.
    final fetched = <String, String?>{};

    for (final page in story.pages) {
      final word = page.highlightWord.toLowerCase().trim();
      if (!fetched.containsKey(word)) {
        fetched[word] = await _fetchImageUrl(word);
      }
      enriched.add(StoryPage(
        english: page.english,
        hebrew: page.hebrew,
        highlightWord: page.highlightWord,
        imageUrl: fetched[word],
      ));
    }
    return enriched;
  }

  Future<String?> _fetchImageUrl(String query) async {
    try {
      final hits = await _proxy.searchPixabay(query, perPage: 3);
      if (hits.isEmpty) return null;
      // Prefer hits[0].webformatURL for reasonable quality.
      final url = hits.first['webformatURL'];
      if (url is String && url.isNotEmpty) return url;
      return null;
    } catch (e) {
      debugPrint('StoryService._fetchImageUrl($query): $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Cache
  // ---------------------------------------------------------------------------

  String _cacheKey(String userId, String levelId) =>
      '${_cachePrefix}_${_sanitize(userId)}_${_sanitize(levelId)}';

  Future<SparkStory?> _loadFromCache(String userId, String levelId) async {
    try {
      final prefs = await _prefsFuture;
      final raw = prefs.getString(_cacheKey(userId, levelId));
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final story = SparkStory.fromJson(json);

      // Expire after 24 hours.
      if (DateTime.now().difference(story.generatedAt) > _cacheMaxAge) {
        return null;
      }
      return story;
    } catch (e) {
      debugPrint('StoryService._loadFromCache: $e');
      return null;
    }
  }

  Future<void> _saveToCache(
      String userId, String levelId, SparkStory story) async {
    try {
      final prefs = await _prefsFuture;
      await prefs.setString(
        _cacheKey(userId, levelId),
        jsonEncode(story.toJson()),
      );
    } catch (e) {
      debugPrint('StoryService._saveToCache: $e');
    }
  }

  String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
}
