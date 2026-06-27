// lib/screens/story_screen.dart
//
// StoryScreen — interactive story reader powered by Gemini + Pixabay.
//
// Features:
//   - Page-turn navigation (swipe or buttons).
//   - Highlighted vocabulary word (bold / colored).
//   - Toggle Hebrew translation per page.
//   - TTS reads the English sentence aloud on request.
//   - Progress bar at top.
//   - "New Story" button forces regeneration.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/spark_story.dart';
import '../models/word_data.dart';
import '../providers/daily_mission_provider.dart';
import '../providers/spark_overlay_controller.dart';
import '../providers/user_session_provider.dart';
import '../services/achievement_service.dart';
import '../services/gemini_proxy_service.dart';
import '../services/sound_service.dart';
import '../services/story_service.dart';
import '../widgets/ui/_barrel.dart';

class StoryScreen extends StatefulWidget {
  const StoryScreen({
    super.key,
    required this.words,
    required this.levelId,
    this.levelTitle,
    this.storyService,
  });

  final List<WordData> words;
  final String levelId;
  final String? levelTitle;

  /// Injectable for testing.
  final StoryService? storyService;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen>
    with SingleTickerProviderStateMixin {
  late final StoryService _storyService;
  late final PageController _pageController;
  late final AnimationController _fadeController;

  Future<SparkStory?>? _storyFuture;
  SparkStory? _story;
  int _currentPage = 0;
  bool _showHebrew = false;
  bool _isGenerating = false;
  bool _storyCompleted = false; // guard: fire completion only once per story

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initService();
      _loadStory();
      try {
        context.read<AchievementService>().markModeTried('story');
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _initService() {
    if (widget.storyService != null) {
      _storyService = widget.storyService!;
      return;
    }
    // Build StoryService from the proxy already in the widget tree.
    _storyService = StoryService(
      proxyService: context.read<GeminiProxyService>(),
    );
  }

  void _loadStory({bool forceRefresh = false}) {
    final session = context.read<UserSessionProvider>();
    final userId = session.currentUser?.id ?? 'local_guest';
    setState(() {
      _isGenerating = true;
      _storyCompleted = false; // reset for new story
      _storyFuture = _storyService
          .getStory(
            userId: userId,
            levelId: widget.levelId,
            words: widget.words,
            forceRefresh: forceRefresh,
          )
          .then((story) {
        if (!mounted) return story;
        setState(() {
          _story = story;
          _isGenerating = false;
          _currentPage = 0;
        });
        _pageController.jumpToPage(0);
        return story;
      }).catchError((e) {
        if (mounted) setState(() => _isGenerating = false);
        return null as SparkStory?;
      });
    });
  }

  void _goToPage(int page) {
    if (_story == null) return;
    if (page < 0 || page >= _story!.pages.length) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentPage = page;
      _showHebrew = false;
    });
    // Celebrate on last page and record story completion.
    if (page == _story!.pages.length - 1) {
      try {
        context.read<SparkOverlayController>().markCelebrating();
        unawaited(SoundService().playSuccessSound());
      } catch (_) {}
      if (!_storyCompleted) {
        _storyCompleted = true;
        _onStoryCompleted();
      }
    }
  }

  /// Called once when the learner reaches the last page of a story.
  void _onStoryCompleted() {
    if (!mounted) return;
    // 1. Advance storyRead daily mission.
    try {
      context
          .read<DailyMissionProvider>()
          .incrementByType(DailyMissionType.storyRead);
    } catch (_) {}

    // 2. Fire achievement check with cumulative story count.
    try {
      final achievement = context.read<AchievementService>();
      unawaited(achievement.recordStoryRead());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F3FF),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade400,
        foregroundColor: Colors.white,
        title: Text(
          widget.levelTitle != null
              ? 'סיפור — ${widget.levelTitle}'
              : 'הסיפור של ספארק',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'סיפור חדש',
            icon: const Icon(Icons.auto_stories),
            onPressed: _isGenerating ? null : () => _loadStory(forceRefresh: true),
          ),
        ],
      ),
      body: FutureBuilder<SparkStory?>(
        future: _storyFuture,
        builder: (context, snapshot) {
          if (_isGenerating ||
              snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoading();
          }
          if (snapshot.hasError || _story == null || _story!.isEmpty) {
            return _buildError();
          }
          return _buildStoryReader(_story!);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Loading / error states
  // ---------------------------------------------------------------------------

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.deepPurple),
          const SizedBox(height: 24),
          Text(
            'ספארק כותב סיפור במיוחד בשבילכם…',
            style: TextStyle(
              fontSize: 18,
              color: Colors.deepPurple.shade700,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories,
                size: 72, color: Colors.deepPurple.shade200),
            const SizedBox(height: 16),
            const Text(
              'לא הצלחנו לייצר סיפור עכשיו.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'בדקו חיבור לאינטרנט ונסו שוב.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _loadStory(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('נסה שוב'),
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade400),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Story reader
  // ---------------------------------------------------------------------------

  Widget _buildStoryReader(SparkStory story) {
    final totalPages = story.pages.length;

    return Column(
      children: [
        // Progress bar.
        _StoryProgressBar(
          current: _currentPage,
          total: totalPages,
        ),

        // Title row.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                story.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                ),
              ),
              Text(
                story.titleHebrew,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.deepPurple.shade400,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Page view.
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: totalPages,
            onPageChanged: (page) => setState(() {
              _currentPage = page;
              _showHebrew = false;
            }),
            itemBuilder: (context, index) {
              return _StoryPageCard(
                page: story.pages[index],
                pageNumber: index + 1,
                totalPages: totalPages,
                showHebrew: _showHebrew && index == _currentPage,
                onToggleHebrew: () =>
                    setState(() => _showHebrew = !_showHebrew),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
            },
          ),
        ),

        // Navigation buttons.
        _StoryNavBar(
          currentPage: _currentPage,
          totalPages: totalPages,
          onPrev: _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
          onNext: _currentPage < totalPages - 1
              ? () => _goToPage(_currentPage + 1)
              : null,
          onFinish: _currentPage == totalPages - 1
              ? () => Navigator.pop(context)
              : null,
        ),
      ],
    );
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

class _StoryProgressBar extends StatelessWidget {
  const _StoryProgressBar({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (current + 1) / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          minHeight: 8,
          backgroundColor: Colors.deepPurple.shade100,
          color: Colors.deepPurple.shade400,
        ),
      ),
    );
  }
}

class _StoryPageCard extends StatelessWidget {
  const _StoryPageCard({
    required this.page,
    required this.pageNumber,
    required this.totalPages,
    required this.showHebrew,
    required this.onToggleHebrew,
  });

  final StoryPage page;
  final int pageNumber;
  final int totalPages;
  final bool showHebrew;
  final VoidCallback onToggleHebrew;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 4,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image.
            if (page.imageUrl != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                child: CachedNetworkImage(
                  imageUrl: page.imageUrl!,
                  height: 180,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 180,
                    color: Colors.deepPurple.shade50,
                    child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 120,
                    color: Colors.deepPurple.shade50,
                    child: Icon(Icons.image_not_supported,
                        color: Colors.deepPurple.shade200, size: 40),
                  ),
                ),
              )
            else
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Center(
                  child: Icon(Icons.auto_stories,
                      color: Colors.deepPurple.shade200, size: 48),
                ),
              ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page number.
                    Text(
                      'עמוד $pageNumber / $totalPages',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 12),

                    // English text — highlight the vocabulary word.
                    _HighlightedText(
                      text: page.english,
                      highlight: page.highlightWord,
                    ),

                    const SizedBox(height: 16),

                    // Hebrew toggle.
                    if (showHebrew) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          page.hebrew,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.deepPurple.shade700,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Hebrew toggle button.
                    OutlinedButton.icon(
                      onPressed: onToggleHebrew,
                      icon: Icon(
                        showHebrew ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                      ),
                      label: Text(
                          showHebrew ? 'הסתר עברית' : 'הצג בעברית'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepPurple.shade600,
                        side: BorderSide(
                            color: Colors.deepPurple.shade200),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders [text] with [highlight] bolded and coloured in deep-purple.
class _HighlightedText extends StatelessWidget {
  const _HighlightedText({required this.text, required this.highlight});
  final String text;
  final String highlight;

  @override
  Widget build(BuildContext context) {
    // Replace **word** markdown bold markers.
    final cleaned = text.replaceAll('**', '');
    final pattern = RegExp(
      RegExp.escape(highlight.trim()),
      caseSensitive: false,
    );

    final spans = <InlineSpan>[];
    int start = 0;
    for (final match in pattern.allMatches(cleaned)) {
      if (match.start > start) {
        spans.add(TextSpan(text: cleaned.substring(start, match.start)));
      }
      spans.add(TextSpan(
        text: cleaned.substring(match.start, match.end),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple.shade600,
          fontSize: 22,
        ),
      ));
      start = match.end;
    }
    if (start < cleaned.length) {
      spans.add(TextSpan(text: cleaned.substring(start)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 22,
          color: Colors.black87,
          height: 1.6,
          fontFamily: 'Roboto',
        ),
        children: spans,
      ),
    );
  }
}

class _StoryNavBar extends StatelessWidget {
  const _StoryNavBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
    required this.onFinish,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button.
          IconButton.filled(
            onPressed: onPrev,
            icon: const Icon(Icons.arrow_back),
            style: IconButton.styleFrom(
              backgroundColor: onPrev != null
                  ? Colors.deepPurple.shade400
                  : Colors.grey.shade300,
              foregroundColor: Colors.white,
            ),
          ),

          // Page dots.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(totalPages, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == currentPage ? 20 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == currentPage
                      ? Colors.deepPurple.shade400
                      : Colors.deepPurple.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          // Next / Finish button.
          if (onFinish != null)
            FilledButton.icon(
              onPressed: onFinish,
              icon: const Icon(Icons.check_circle),
              label: const Text('סיום'),
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600),
            )
          else
            IconButton.filled(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward),
              style: IconButton.styleFrom(
                backgroundColor: onNext != null
                    ? Colors.deepPurple.shade400
                    : Colors.grey.shade300,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}
