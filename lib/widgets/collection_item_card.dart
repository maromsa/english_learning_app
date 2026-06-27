import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:english_learning_app/models/collection_word_item.dart';
import 'package:english_learning_app/utils/aurora_tokens.dart';
import 'package:english_learning_app/utils/word_image_url.dart';
import 'package:english_learning_app/widgets/ui/glass_card.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sticker-book tile for a single word in [CollectionScreen].
class CollectionItemCard extends StatelessWidget {
  const CollectionItemCard({
    super.key,
    required this.item,
  });

  final CollectionWordItem item;

  static const ColorFilter _lockedGrayscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 0.55, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mastered = item.isMastered;

    return GlassCard(
      borderRadius: AuroraTokens.rLg,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AuroraTokens.rMd),
                  child: mastered
                      ? _buildImage(context)
                      : ColorFiltered(
                          colorFilter: _lockedGrayscale,
                          child: _buildImage(context, dimmed: true),
                        ),
                ),
                if (!mastered)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 18,
                        color: theme.colorScheme.onPrimary.withValues(
                          alpha: 0.95,
                        ),
                      ),
                    ),
                  ),
                if (mastered)
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: _GlowingThreeStarBadge(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.word.word,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.quicksand(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: mastered
                  ? AuroraTokens.ink
                  : AuroraTokens.inkMute,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context, {bool dimmed = false}) {
    final url = item.word.imageUrl;
    if (url == null || url.isEmpty) {
      return _placeholder(dimmed: dimmed);
    }

    Widget image;
    if (url.startsWith('assets/')) {
      image = Image.asset(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(dimmed: dimmed),
      );
    } else if (!kIsWeb &&
        !url.startsWith('http') &&
        !isInlineDataImageUrl(url) &&
        !url.startsWith('blob:')) {
      image = Image.file(
        File(url),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(dimmed: dimmed),
      );
    } else if (isInlineDataImageUrl(url) || url.startsWith('blob:')) {
      image = buildInlineOrNetworkWordImage(
        url,
        fit: BoxFit.cover,
        errorWidget: _placeholder(dimmed: dimmed),
      );
    } else {
      image = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: 280,
        memCacheHeight: 280,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (_, __, ___) => _placeholder(dimmed: dimmed),
      );
    }

    if (dimmed) {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.black.withValues(alpha: 0.25),
          BlendMode.darken,
        ),
        child: image,
      );
    }
    return image;
  }

  Widget _placeholder({required bool dimmed}) {
    return Container(
      color: dimmed
          ? AuroraTokens.hair.withValues(alpha: 0.6)
          : AuroraTokens.hair,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 40,
        color: AuroraTokens.inkMute.withValues(alpha: dimmed ? 0.5 : 0.7),
      ),
    );
  }
}

class _GlowingThreeStarBadge extends StatelessWidget {
  const _GlowingThreeStarBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            AuroraTokens.butter.withValues(alpha: 0.95),
            AuroraTokens.coral.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AuroraTokens.butter.withValues(alpha: 0.75),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(
            3,
            (_) => const Icon(
              Icons.star_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
