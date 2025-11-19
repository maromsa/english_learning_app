import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/word_data.dart';

class WordDisplayCard extends StatelessWidget {
  final WordData wordData;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const WordDisplayCard({
    super.key,
    required this.wordData,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = wordData.imageUrl;
    final String normalizedUrl = imageUrl ?? '';
    final bool hasImageUrl = normalizedUrl.isNotEmpty;
    final bool isAssetImage = hasImageUrl && normalizedUrl.startsWith('assets/');
    final bool isLocalFile = !kIsWeb &&
        hasImageUrl &&
        !normalizedUrl.startsWith('http') &&
        !normalizedUrl.startsWith('blob:') &&
        !normalizedUrl.startsWith('data:') &&
        !isAssetImage;

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
                ClipRRect(
                  borderRadius: BorderRadius.circular(20.0),
                  child: _buildImage(
                    imageUrl,
                    isLocalFile: isLocalFile,
                    isAssetImage: isAssetImage,
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
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    )),
                    child: child,
                  ),
                );
              },
              child: Text(
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
          ],
        ),
      ),
    );
  }

  Widget _buildImage(
    String? imageUrl, {
    required bool isLocalFile,
    required bool isAssetImage,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholder();
    }

    return SizedBox(
      width: 250,
      height: 250,
      child: isAssetImage
          ? _buildAssetImage(imageUrl)
          : isLocalFile
          ? Image.file(
              File(imageUrl),
              key: ValueKey(imageUrl),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Failed to load local image "$imageUrl": $error');
                return _errorBuilder(context, error, stackTrace);
              },
            )
          : CachedNetworkImage(
              imageUrl: imageUrl,
              key: ValueKey(imageUrl),
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (context, url, error) {
                debugPrint('Failed to load network image "$imageUrl": $error');
                return _errorBuilder(context, error, null);
              },
              memCacheWidth: 500, // Optimize memory usage
              memCacheHeight: 500,
              maxWidthDiskCache: 1000,
              maxHeightDiskCache: 1000,
            ),
    );
  }

  Widget _buildAssetImage(String imageUrl) {
    return Image.asset(
      imageUrl,
      key: ValueKey(imageUrl),
      fit: BoxFit.cover,
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
            loadingBuilder: _loadingBuilder,
            errorBuilder: (context, fallbackError, fallbackStackTrace) {
              debugPrint(
                'Failed to load web asset fallback "$imageUrl" '
                '(resolved $resolvedUrl): $fallbackError',
              );
              return _errorBuilder(context, fallbackError, fallbackStackTrace);
            },
          );
        }

        return _errorBuilder(context, error, stackTrace);
      },
    );
  }

  String _resolveWebAssetUrl(String assetPath) {
    final normalized = assetPath.startsWith('/')
        ? assetPath.substring(1)
        : assetPath;
    return Uri.base.resolve('assets/$normalized').toString();
  }

  Widget _buildPlaceholder() => Container(
    width: 250,
    height: 250,
    color: Colors.grey.shade200,
    child: const Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 80,
        color: Colors.grey,
      ),
    ),
  );

  Widget _loadingBuilder(
    BuildContext context,
    Widget child,
    ImageChunkEvent? loadingProgress,
  ) {
    if (loadingProgress == null) return child;

    return Container(
      width: 250,
      height: 250,
      color: Colors.grey.shade100,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _errorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) => Container(
    width: 250,
    height: 250,
    color: Colors.grey.shade200,
    child: const Center(
      child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
    ),
  );
}
