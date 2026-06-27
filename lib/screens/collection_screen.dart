import 'package:english_learning_app/app_config.dart';
import 'package:english_learning_app/models/collection_word_item.dart';
import 'package:english_learning_app/models/srs_card.dart';
import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/services/level_progress_service.dart';
import 'package:english_learning_app/services/level_repository.dart';
import 'package:english_learning_app/services/spark_voice_service.dart';
import 'package:english_learning_app/services/srs_service.dart';
import 'package:english_learning_app/services/word_mastery_service.dart';
import 'package:english_learning_app/utils/aurora_tokens.dart';
import 'package:english_learning_app/utils/offline_word_loader.dart';
import 'package:english_learning_app/widgets/ui/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------------------
// Local enriched model
// ---------------------------------------------------------------------------

class _DictionaryEntry {
  const _DictionaryEntry({required this.item, this.srsCard});
  final CollectionWordItem item;
  final SrsCard? srsCard;

  bool get isDue => srsCard?.isDue ?? true;
  bool get isNew => srsCard == null || srsCard!.repetitions == 0;
  bool get isMastered => srsCard != null && srsCard!.masteryLevel >= 0.8;
  double get masteryPct => srsCard?.masteryLevel ?? 0.0;
  int get daysUntilDue => srsCard?.daysUntilDue ?? -1;
  DateTime? get nextReview => srsCard?.nextReviewDate;
  int get pronunciationStars => srsCard?.bestPronunciationStars ?? 0;
}

enum _SortMode { dueFirst, alphabetical, masteryDesc }

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Personal dictionary — every word with SRS status, audio, and search.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({
    super.key,
    LevelRepository? levelRepository,
    LevelProgressService? levelProgressService,
    WordMasteryService? wordMasteryService,
    OfflineWordLoader? offlineWordLoader,
    SrsService? srsService,
  })  : _levelRepository = levelRepository,
        _levelProgressService = levelProgressService,
        _wordMasteryService = wordMasteryService,
        _offlineWordLoader = offlineWordLoader,
        _srsService = srsService;

  final LevelRepository? _levelRepository;
  final LevelProgressService? _levelProgressService;
  final WordMasteryService? _wordMasteryService;
  final OfflineWordLoader? _offlineWordLoader;
  final SrsService? _srsService;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late final LevelRepository _levelRepository;
  late final LevelProgressService _levelProgressService;
  late final WordMasteryService _wordMasteryService;
  late final OfflineWordLoader _offlineWordLoader;
  late final SrsService _srsService;
  final SparkVoiceService _voice = SparkVoiceService();

  bool _loading = true;
  String? _errorMessage;
  List<_DictionaryEntry> _allEntries = const [];

  // Search + sort state
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  _SortMode _sortMode = _SortMode.dueFirst;

  // Audio state — which word is playing
  String? _playingWord;

  @override
  void initState() {
    super.initState();
    _levelRepository = widget._levelRepository ?? LevelRepository();
    _levelProgressService =
        widget._levelProgressService ?? LevelProgressService();
    _wordMasteryService = widget._wordMasteryService ?? WordMasteryService();
    _offlineWordLoader = widget._offlineWordLoader ?? OfflineWordLoader();
    _srsService = widget._srsService ?? SrsService();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
    _loadCollection();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadCollection() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final session = context.read<UserSessionProvider>();
      final userId = session.currentUserId ?? 'local_guest';
      final isLocalUser = session.isLocalUser;

      final levels = await _levelRepository.loadLevels();
      if (levels.isEmpty) throw StateError('No levels found in catalog');

      if (!isLocalUser && session.currentUserId != null) {
        await Future.wait(
          levels.map(
            (level) => _levelProgressService.syncLevelProgressFromCloud(
              userId: userId,
              levelId: level.id,
              isLocalUser: false,
            ),
          ),
        );
      }

      final List<_DictionaryEntry> entries = [];

      for (final level in levels) {
        final baseWords = level.words.isNotEmpty
            ? level.words
            : await _levelRepository.loadWordsForLevel(level.id);

        final enriched = await _offlineWordLoader.loadWords(
          remoteCapable: AppConfig.hasCloudinary,
          fallbackWords: baseWords,
          cloudName: AppConfig.cloudinaryCloudName,
          tagName: 'english_kids_app',
          maxResults: 80,
          cacheNamespace: level.id,
        );

        final completed = await _levelProgressService.getCompletedWords(
          userId,
          level.id,
          isLocalUser: isLocalUser,
        );

        for (final word in enriched) {
          final mastery = await _wordMasteryService.getMastery(
            userId: userId,
            levelId: level.id,
            word: word.word,
          );
          final merged = _wordMasteryService.applyToWord(word, mastery);

          SrsCard? card;
          try {
            card = await _srsService.getCard(
              userId: userId,
              levelId: level.id,
              word: word.word,
            );
          } catch (_) {
            card = null;
          }

          entries.add(
            _DictionaryEntry(
              item: CollectionWordItem(
                word: merged,
                levelId: level.id,
                mastery: mastery,
                isCompleted: completed.contains(word.word),
              ),
              srsCard: card,
            ),
          );
        }
      }

      _sortEntries(entries);

      if (!mounted) return;
      setState(() {
        _allEntries = entries;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('CollectionScreen: failed to load: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'לא הצלחנו לטעון את המילון. נסו שוב.';
        _loading = false;
      });
    }
  }

  void _sortEntries(List<_DictionaryEntry> list) {
    switch (_sortMode) {
      case _SortMode.dueFirst:
        list.sort((a, b) {
          // due/new first, then mastered, then upcoming
          final aScore = a.isNew ? 0 : (a.isDue ? 1 : (a.isMastered ? 3 : 2));
          final bScore = b.isNew ? 0 : (b.isDue ? 1 : (b.isMastered ? 3 : 2));
          if (aScore != bScore) return aScore - bScore;
          return a.item.word.word.compareTo(b.item.word.word);
        });
      case _SortMode.alphabetical:
        list.sort((a, b) =>
            a.item.word.word.toLowerCase().compareTo(b.item.word.word.toLowerCase()));
      case _SortMode.masteryDesc:
        list.sort((a, b) {
          final cmp = b.masteryPct.compareTo(a.masteryPct);
          if (cmp != 0) return cmp;
          return a.item.word.word.compareTo(b.item.word.word);
        });
    }
  }

  List<_DictionaryEntry> get _filtered {
    final sorted = List<_DictionaryEntry>.from(_allEntries);
    _sortEntries(sorted);
    if (_query.isEmpty) return sorted;
    return sorted
        .where((e) =>
            e.item.word.word.toLowerCase().contains(_query) ||
            (e.item.word.translation ?? '').toLowerCase().contains(_query))
        .toList();
  }

  int get _dueCount => _allEntries.where((e) => e.isDue && !e.isNew).length;
  int get _newCount => _allEntries.where((e) => e.isNew).length;
  int get _masteredCount => _allEntries.where((e) => e.isMastered).length;

  // ---------------------------------------------------------------------------
  // Audio
  // ---------------------------------------------------------------------------

  Future<void> _playWord(String word) async {
    if (_playingWord == word) return;
    setState(() => _playingWord = word);
    try {
      await _voice.speak(text: word, isEnglish: true);
    } finally {
      if (mounted) setState(() => _playingWord = null);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'מילון אישי',
          style: GoogleFonts.baloo2(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AuroraTokens.ink,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF8E1), Color(0xFFF3E5F5), Color(0xFFE8F5E9)],
          ),
        ),
        child: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('טוען מילים...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.book_outlined,
                  size: 56, color: AuroraTokens.inkMute.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.heebo(
                      fontSize: 16, color: AuroraTokens.inkSoft)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loadCollection,
                icon: const Icon(Icons.refresh),
                label: const Text('נסו שוב'),
              ),
            ],
          ),
        ),
      );
    }

    final visible = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stats header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _StatsHeader(
            total: _allEntries.length,
            dueCount: _dueCount,
            newCount: _newCount,
            masteredCount: _masteredCount,
          ),
        ),

        // Search + sort bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: 'חיפוש מילה...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SortButton(
                current: _sortMode,
                onChange: (mode) {
                  setState(() => _sortMode = mode);
                },
              ),
            ],
          ),
        ),

        // Word list
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    _query.isEmpty ? 'עדיין אין מילים' : 'לא נמצאו תוצאות',
                    style: GoogleFonts.heebo(
                        fontSize: 16, color: AuroraTokens.inkMute),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final entry = visible[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _WordCard(
                        entry: entry,
                        isPlaying: _playingWord == entry.item.word.word,
                        onPlay: () => _playWord(entry.item.word.word),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stat header
// ---------------------------------------------------------------------------

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({
    required this.total,
    required this.dueCount,
    required this.newCount,
    required this.masteredCount,
  });
  final int total, dueCount, newCount, masteredCount;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AuroraTokens.rXl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(
              icon: Icons.fiber_new_rounded,
              label: 'חדשות',
              count: newCount,
              color: Colors.blue),
          _StatChip(
              icon: Icons.schedule_rounded,
              label: 'לחזרה',
              count: dueCount,
              color: Colors.orange),
          _StatChip(
              icon: Icons.star_rounded,
              label: 'שולטות',
              count: masteredCount,
              color: Colors.green),
          _StatChip(
              icon: Icons.library_books_rounded,
              label: 'סה"כ',
              count: total,
              color: Colors.purple),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 2),
        Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sort button
// ---------------------------------------------------------------------------

class _SortButton extends StatelessWidget {
  const _SortButton({required this.current, required this.onChange});
  final _SortMode current;
  final ValueChanged<_SortMode> onChange;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortMode>(
      initialValue: current,
      onSelected: onChange,
      tooltip: 'מיון',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _SortMode.dueFirst,
          child: Row(children: [
            Icon(Icons.schedule_rounded, size: 18),
            SizedBox(width: 8),
            Text('לחזרה ראשונות'),
          ]),
        ),
        PopupMenuItem(
          value: _SortMode.alphabetical,
          child: Row(children: [
            Icon(Icons.sort_by_alpha_rounded, size: 18),
            SizedBox(width: 8),
            Text('א׳ עד ת׳'),
          ]),
        ),
        PopupMenuItem(
          value: _SortMode.masteryDesc,
          child: Row(children: [
            Icon(Icons.star_rounded, size: 18),
            SizedBox(width: 8),
            Text('שליטה גבוהה ראשונה'),
          ]),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.sort_rounded,
            size: 22, color: Colors.grey.shade700),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Word card
// ---------------------------------------------------------------------------

class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.entry,
    required this.isPlaying,
    required this.onPlay,
  });
  final _DictionaryEntry entry;
  final bool isPlaying;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final word = entry.item.word;
    final srs = entry.srsCard;

    final (statusColor, statusLabel, statusIcon) = _srsStatus(entry);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border(
          right: BorderSide(color: statusColor, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            // Word image thumbnail (if available)
            if (word.imageUrl != null && word.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  word.imageUrl!,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _wordIcon(),
                ),
              )
            else
              _wordIcon(),

            const SizedBox(width: 12),

            // Word info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // English word + stars
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          word.word,
                          style: GoogleFonts.baloo2(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AuroraTokens.ink,
                          ),
                        ),
                      ),
                      if (entry.pronunciationStars > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            entry.pronunciationStars,
                            (_) => const Icon(Icons.star,
                                size: 12, color: Colors.amber),
                          ),
                        ),
                    ],
                  ),

                  // Hebrew translation
                  if (word.translation != null && word.translation!.isNotEmpty)
                    Text(
                      word.translation!,
                      style: GoogleFonts.heebo(
                        fontSize: 13,
                        color: AuroraTokens.inkSoft,
                      ),
                    ),

                  const SizedBox(height: 6),

                  // Mastery bar
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: entry.masteryPct,
                            minHeight: 4,
                            backgroundColor: Colors.grey.shade100,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${(entry.masteryPct * 100).round()}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // SRS status label
                  Row(
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (srs?.nextReviewDate != null && !entry.isDue) ...[
                        const SizedBox(width: 4),
                        Text(
                          '· ${_nextReviewText(srs!.nextReviewDate!)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Play button
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isPlaying
                  ? const SizedBox(
                      key: ValueKey('playing'),
                      width: 36,
                      height: 36,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : IconButton(
                      key: const ValueKey('idle'),
                      icon: const Icon(Icons.volume_up_rounded),
                      color: Colors.indigo.shade400,
                      iconSize: 22,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            Colors.indigo.withValues(alpha: 0.08),
                        shape: const CircleBorder(),
                      ),
                      onPressed: onPlay,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wordIcon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.abc_rounded, size: 28, color: Colors.grey),
    );
  }

  (Color, String, IconData) _srsStatus(_DictionaryEntry e) {
    if (e.isNew) {
      return (Colors.blue, 'חדשה', Icons.fiber_new_rounded);
    }
    if (e.isMastered) {
      return (Colors.green, 'שולטת', Icons.verified_rounded);
    }
    if (e.isDue) {
      return (Colors.orange, 'לחזרה עכשיו', Icons.schedule_rounded);
    }
    return (Colors.teal, 'בלמידה', Icons.trending_up_rounded);
  }

  String _nextReviewText(DateTime dt) {
    final days = dt.difference(DateTime.now()).inDays;
    if (days == 0) return 'היום';
    if (days == 1) return 'מחר';
    if (days < 7) return 'בעוד $days ימים';
    if (days < 30) return 'בעוד ${(days / 7).round()} שבועות';
    return 'בעוד ${(days / 30).round()} חודשים';
  }
}
