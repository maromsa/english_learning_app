import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/word_data.dart';
import '../utils/word_image_url.dart';

/// Visual layout for [WordDisplayCard].
enum WordDisplayCardLayout {
  /// Elevated card with square image (default).
  standard,

  /// Full-width hero card used on the level (home) screen.
  levelHero,
}

class WordDisplayCard extends StatelessWidget {
  static const double _imageBorderRadius = 20;
  static const double _imageMinSide = 250;
  static const double _levelHeroImageRadius = 24;

  final WordData wordData;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onPlayAudio;
  final String? heroImageTag;
  final String? heroTitleTag;
  final WordDisplayCardLayout layout;
  final bool canShowPrevious;
  final bool canShowNext;

  const WordDisplayCard({
    super.key,
    required this.wordData,
    this.onPrevious,
    this.onNext,
    this.onPlayAudio,
    this.heroImageTag,
    this.heroTitleTag,
    this.layout = WordDisplayCardLayout.standard,
    this.canShowPrevious = true,
    this.canShowNext = true,
  });

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      WordDisplayCardLayout.standard => _buildStandard(context),
      WordDisplayCardLayout.levelHero => _buildLevelHero(context),
    };
  }

  Widget _buildLevelHero(BuildContext context) {
    final imageKinds = _resolveImageKinds();

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.1),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Container(
            key: ValueKey<String>(wordData.word),
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              border: wordData.isCompleted
                  ? Border.all(color: Colors.green.shade300, width: 3)
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 2,
                    ),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withValues(alpha: 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(_levelHeroImageRadius),
                      color: Colors.grey.shade100,
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(_levelHeroImageRadius),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _wrapHero(
                            heroImageTag,
                            _buildLevelHeroImage(context, imageKinds),
                          ),
                          if (wordData.isCompleted)
                            Container(
                              color: Colors.green.withValues(alpha: 0.2),
                              child: const Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 64,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _wrapHero(
                      heroTitleTag,
                      Text(
                        wordData.word,
                        style: GoogleFonts.quicksand(
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3D3D5C),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (onPlayAudio != null) ...[
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        onPressed: onPlayAudio,
                        icon: const Icon(Icons.volume_up_rounded, size: 28),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.indigo.shade50,
                          foregroundColor: Colors.indigo,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        if (canShowPrevious && onPrevious != null)
          Positioned(
            left: 0,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: onPrevious,
              ),
            ),
          ),
        if (canShowNext && onNext != null)
          Positioned(
            right: 0,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_forward, color: Colors.black87),
                onPressed: onNext,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLevelHeroImage(
    BuildContext context,
    _ImageKinds kinds,
  ) {
    final imageUrl = wordData.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const Center(
        child: Icon(Icons.image, size: 64, color: Colors.grey),
      );
    }

    return Material(
      color: Colors.transparent,
      child: _buildWordImage(
        context,
        imageUrl,
        kinds: kinds,
        compactError: true,
      ),
    );
  }

  Widget _buildStandard(BuildContext context) {
    final kinds = _resolveImageKinds();
    final imageUrl = wordData.imageUrl;

    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                _wrapHero(
                  heroImageTag,
                  _buildImage(
                    context,
                    imageUrl,
                    kinds: kinds,
                  ),
                ),
                Positioned(
                  left: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onPrevious,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_ios, size: 28),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onNext,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_ios, size: 28),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              child: _wrapHero(
                heroTitleTag,
                Text(
                  wordData.word,
                  key: ValueKey(wordData.word),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ImageKinds _resolveImageKinds() {
    final String? imageUrl = wordData.imageUrl;
    final String normalizedUrl = imageUrl ?? '';
    final bool hasImageUrl = normalizedUrl.isNotEmpty;
    final bool isAssetImage =
        hasImageUrl && normalizedUrl.startsWith('assets/');
    final bool isInlineImage = hasImageUrl &&
        (isInlineDataImageUrl(normalizedUrl) ||
            normalizedUrl.startsWith('blob:'));
    final bool isLocalFile = !kIsWeb &&
        hasImageUrl &&
        !normalizedUrl.startsWith('http') &&
        !isInlineImage &&
        !isAssetImage;

    return _ImageKinds(
      isAssetImage: isAssetImage,
      isInlineImage: isInlineImage,
      isLocalFile: isLocalFile,
    );
  }

  Widget _wrapHero(String? tag, Widget child) {
    if (tag == null) {
      return child;
    }
    return Hero(
      tag: tag,
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
    );
  }

  /// Square, width-aware frame with clipped corners and tight cover constraints.
  Widget _imageFrame(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : _imageMinSide;
        return SizedBox(
          width: side,
          height: side,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_imageBorderRadius),
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [child],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImage(
    BuildContext context,
    String? imageUrl, {
    required _ImageKinds kinds,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholder();
    }

    return _imageFrame(
      _buildWordImage(
        context,
        imageUrl,
        kinds: kinds,
        compactError: false,
      ),
    );
  }

  Widget _buildWordImage(
    BuildContext context,
    String imageUrl, {
    required _ImageKinds kinds,
    required bool compactError,
  }) {
    if (kinds.isAssetImage) {
      return _buildAssetImage(imageUrl, compactError: compactError);
    }
    if (kinds.isLocalFile) {
      return Image.file(
        File(imageUrl),
        key: ValueKey(imageUrl),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _levelHeroErrorIcon(compactError),
      );
    }
    if (kinds.isInlineImage) {
      return buildInlineOrNetworkWordImage(
        imageUrl,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        placeholder: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: _levelHeroErrorIcon(compactError),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      key: ValueKey(imageUrl),
      fit: BoxFit.cover,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      errorWidget: (context, url, error) =>
          _levelHeroErrorIcon(compactError),
      memCacheWidth: 500,
      memCacheHeight: 500,
      maxWidthDiskCache: 1000,
      maxHeightDiskCache: 1000,
    );
  }

  Widget _levelHeroErrorIcon(bool compact) {
    if (compact) {
      return const Icon(Icons.image, size: 64, color: Colors.grey);
    }
    return _errorBuilder(null, null);
  }

  Widget _buildAssetImage(String imageUrl, {required bool compactError}) {
    return Image.asset(
      imageUrl,
      key: ValueKey(imageUrl),
      fit: BoxFit.cover,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Failed to load asset image "$imageUrl": $error');

        if (kIsWeb) {
          final resolvedUrl = _resolveWebAssetUrl(imageUrl);
          debugPrint(
            'Attempting web asset fallback for "$imageUrl" (resolved $resolvedUrl)',
          );
          return Image.network(
            resolvedUrl,
            key: ValueKey('web_$imageUrl'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: _loadingBuilder,
            errorBuilder: (context, fallbackError, fallbackStackTrace) {
              debugPrint(
                'Failed to load web asset fallback "$imageUrl" '
                '(resolved $resolvedUrl): $fallbackError',
              );
              return compactError
                  ? _levelHeroErrorIcon(true)
                  : _errorBuilder(fallbackError, fallbackStackTrace);
            },
          );
        }

        return compactError
            ? _levelHeroErrorIcon(true)
            : _errorBuilder(error, stackTrace);
      },
    );
  }

  String _resolveWebAssetUrl(String assetPath) {
    final normalized =
        assetPath.startsWith('/') ? assetPath.substring(1) : assetPath;
    return Uri.base.resolve('assets/$normalized').toString();
  }

  Widget _buildPlaceholder() => _imageFrame(
        ColoredBox(
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              size: 80,
              color: Colors.grey,
            ),
          ),
        ),
      );

  Widget _loadingBuilder(
    BuildContext context,
    Widget child,
    ImageChunkEvent? loadingProgress,
  ) {
    if (loadingProgress == null) return child;

    return ColoredBox(
      color: Colors.grey.shade100,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _errorBuilder(Object? error, StackTrace? stackTrace) => ColoredBox(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
        ),
      );
}

class _ImageKinds {
  const _ImageKinds({
    required this.isAssetImage,
    required this.isInlineImage,
    required this.isLocalFile,
  });

  final bool isAssetImage;
  final bool isInlineImage;
  final bool isLocalFile;
}
