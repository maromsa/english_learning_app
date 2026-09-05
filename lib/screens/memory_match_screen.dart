// lib/screens/memory_match_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:english_learning_app/widgets/ui/_barrel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../app_config.dart';
import '../models/word_data.dart';
import '../providers/coin_provider.dart';
import '../services/sound_service.dart';
import '../utils/aurora_tokens.dart';

/// A simple "match the picture to the word" memory game for a level's words.
///
/// Deals 3-4 word pairs (an image card + a word card each), shuffles them,
/// and lets the child flip two cards at a time looking for matches.
class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({
    super.key,
    required this.levelId,
    required this.wordsForLevel,
    this.pairCount = 4,
    this.random,
  });

  final String levelId;
  final List<WordData> wordsForLevel;

  /// How many pairs to deal per round (clamped to the available words).
  final int pairCount;

  /// Overridable for deterministic shuffling in tests.
  final math.Random? random;

  static const int coinReward = 20;
  static const int minPairs = 2;

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

enum _CardKind { image, word }

class _MemoryCard {
  _MemoryCard({required this.word, required this.kind});

  final WordData word;
  final _CardKind kind;
  bool matched = false;

  Key get cardKey => ValueKey(
        '${kind == _CardKind.image ? 'image' : 'word'}_${word.word}',
      );
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  late math.Random _random;
  late List<_MemoryCard> _cards;
  final List<int> _flippedIndexes = [];
  bool _busy = false;
  bool _isComplete = false;
  int _moves = 0;
  Timer? _mismatchTimer;

  int get _pairCount => _cards.length ~/ 2;

  @override
  void initState() {
    super.initState();
    _random = widget.random ?? math.Random();
    _cards = _dealRound();
  }

  @override
  void dispose() {
    _mismatchTimer?.cancel();
    super.dispose();
  }

  bool _hasResolvableImage(WordData word) =>
      (word.imageUrl != null && word.imageUrl!.isNotEmpty) ||
      (word.publicId != null && word.publicId!.isNotEmpty);

  List<_MemoryCard> _dealRound() {
    final withImages =
        widget.wordsForLevel.where(_hasResolvableImage).toList();
    final pool = withImages.length >= MemoryMatchScreen.minPairs
        ? withImages
        : widget.wordsForLevel;

    final shuffledWords = List<WordData>.from(pool)..shuffle(_random);
    final targetPairs = math.min(widget.pairCount, shuffledWords.length);
    final roundWords = shuffledWords.take(targetPairs).toList();

    final cards = <_MemoryCard>[
      for (final word in roundWords) ...[
        _MemoryCard(word: word, kind: _CardKind.image),
        _MemoryCard(word: word, kind: _CardKind.word),
      ],
    ]..shuffle(_random);
    return cards;
  }

  void _playAgain() {
    _mismatchTimer?.cancel();
    setState(() {
      _cards = _dealRound();
      _flippedIndexes.clear();
      _busy = false;
      _isComplete = false;
      _moves = 0;
    });
  }

  void _onCardTap(int index) {
    if (_busy || _isComplete) return;
    final card = _cards[index];
    if (card.matched || _flippedIndexes.contains(index)) return;

    setState(() => _flippedIndexes.add(index));

    if (_flippedIndexes.length < 2) return;

    _moves++;
    final first = _cards[_flippedIndexes[0]];
    final second = _cards[_flippedIndexes[1]];

    if (first.word.word == second.word.word && first.kind != second.kind) {
      setState(() {
        first.matched = true;
        second.matched = true;
        _flippedIndexes.clear();
      });
      SoundService().playPopSound();
      if (_cards.every((c) => c.matched)) {
        unawaited(_onRoundComplete());
      }
      return;
    }

    _busy = true;
    _mismatchTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _flippedIndexes.clear();
        _busy = false;
      });
    });
  }

  Future<void> _onRoundComplete() async {
    setState(() => _isComplete = true);
    await context.read<CoinProvider>().addCoins(MemoryMatchScreen.coinReward);
    if (!mounted) return;
    SoundService().playSuccessSound();
    await Celebration.fire(
      context,
      tier: CelebrationTier.big,
      compliment: 'זיכרון מעולה!',
      coinsEarned: MemoryMatchScreen.coinReward,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuroraTokens.paper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'משחק זיכרון',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.w800,
            color: AuroraTokens.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: _pairCount < MemoryMatchScreen.minPairs
            ? _buildEmptyState()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuroraTokens.s8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'מצאו את כל הזוגות!',
                          style: GoogleFonts.heebo(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AuroraTokens.inkSoft,
                          ),
                        ),
                        Text(
                          'ניסיונות: $_moves',
                          style: GoogleFonts.heebo(
                            fontSize: 14,
                            color: AuroraTokens.inkMute,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AuroraTokens.s8),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: _cards.length,
                        itemBuilder: (context, index) {
                          final card = _cards[index];
                          final isFlipped =
                              card.matched || _flippedIndexes.contains(index);
                          return _FlipCard(
                            key: card.cardKey,
                            isFlipped: isFlipped,
                            matched: card.matched,
                            onTap: () => _onCardTap(index),
                            front: _CardFront(card: card),
                          );
                        },
                      ),
                    ),
                  ),
                  if (_isComplete) _buildVictoryPanel(),
                  const SizedBox(height: AuroraTokens.s4),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuroraTokens.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.extension_off_rounded,
              size: 64,
              color: AuroraTokens.inkMute,
            ),
            const SizedBox(height: AuroraTokens.s8),
            Text(
              'אין מספיק מילים במשחק הזה',
              textAlign: TextAlign.center,
              style: GoogleFonts.heebo(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AuroraTokens.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVictoryPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuroraTokens.s8,
        AuroraTokens.s4,
        AuroraTokens.s8,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: KidButton.success(
              label: 'שחקו שוב',
              leadingIcon: Icons.replay_rounded,
              onPressed: _playAgain,
            ),
          ),
          const SizedBox(width: AuroraTokens.s4),
          Expanded(
            child: KidButton.primary(
              label: 'חזרה לתפריט',
              leadingIcon: Icons.home_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.card});

  final _MemoryCard card;

  String? _resolveImageUrl(WordData word) {
    if (word.imageUrl != null && word.imageUrl!.isNotEmpty) {
      return word.imageUrl;
    }
    if (word.publicId != null && word.publicId!.isNotEmpty) {
      final cloudName = AppConfig.cloudinaryCloudName;
      if (cloudName.isNotEmpty) {
        return 'https://res.cloudinary.com/$cloudName/image/upload/${word.publicId}';
      }
    }
    return null;
  }

  Widget _buildImage(String? url) {
    if (url == null || url.isEmpty) {
      return const Center(
        child: Icon(Icons.image_not_supported, size: 32, color: Colors.grey),
      );
    }
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image, size: 32)),
      );
    }
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image, size: 32)),
      );
    }
    if (!kIsWeb) {
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return const Center(
      child: Icon(Icons.image_not_supported, size: 32, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = card.kind == _CardKind.image
        ? ClipRRect(
            borderRadius: BorderRadius.circular(AuroraTokens.rMd),
            child: SizedBox.expand(
              child: _buildImage(_resolveImageUrl(card.word)),
            ),
          )
        : Center(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                card.word.word,
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AuroraTokens.ink,
                ),
              ),
            ),
          );

    return Container(
      decoration: BoxDecoration(
        color: card.matched
            ? AuroraTokens.mint.withValues(alpha: 0.18)
            : AuroraTokens.paper2,
        borderRadius: BorderRadius.circular(AuroraTokens.rMd),
        border: Border.all(
          color: card.matched ? AuroraTokens.mint : AuroraTokens.sky,
          width: 2,
        ),
      ),
      child: content,
    );
  }
}

/// Flips between a face-down "?" back and [front] via a Y-axis rotation.
class _FlipCard extends StatefulWidget {
  const _FlipCard({
    super.key,
    required this.isFlipped,
    required this.matched,
    required this.onTap,
    required this.front,
  });

  final bool isFlipped;
  final bool matched;
  final VoidCallback onTap;
  final Widget front;

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.isFlipped ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.matched ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final angle = _controller.value * math.pi;
          final showFront = _controller.value > 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(angle),
            child: showFront
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: widget.front,
                  )
                : const _CardBack(),
          );
        },
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AuroraTokens.plum, AuroraTokens.blueberry],
        ),
        borderRadius: BorderRadius.circular(AuroraTokens.rMd),
      ),
      child: const Center(
        child: Icon(
          Icons.question_mark_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
