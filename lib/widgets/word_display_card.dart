import 'dart:io';
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
    final bool isAssetImage = imageUrl != null && imageUrl.startsWith('assets/');
    final bool isLocalFile =
        imageUrl != null && !imageUrl.startsWith('http') && !isAssetImage;

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
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 28),
                    onPressed: onPrevious,
                  ),
                ),
                Positioned(
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 28),
                    onPressed: onNext,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              wordData.word,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w600,
                color: Colors.indigo,
                letterSpacing: 1.2,
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
          ? Image.asset(
              imageUrl,
              key: ValueKey(imageUrl),
              fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Failed to load asset image "$imageUrl": $error');
                  return _errorBuilder(context, error, stackTrace);
                },
            )
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
              : Image.network(
                  imageUrl,
                  key: ValueKey(imageUrl),
                  fit: BoxFit.cover,
                  loadingBuilder: _loadingBuilder,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Failed to load network image "$imageUrl": $error');
                      return _errorBuilder(context, error, stackTrace);
                    },
                ),
    );
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
      ) =>
      Container(
        width: 250,
        height: 250,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
        ),
      );
}
