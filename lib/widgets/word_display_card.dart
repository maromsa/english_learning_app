import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloudinary_url_gen/cloudinary.dart';
import '../models/word_data.dart';

class WordDisplayCard extends StatelessWidget {
  final WordData wordData;
  final Cloudinary cloudinary;

  const WordDisplayCard({
    super.key,
    required this.wordData,
    required this.cloudinary,
  });

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = wordData.imageUrl;
    final bool isLocalFile = imageUrl != null && !imageUrl.startsWith('http');

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
                  child: _buildImage(imageUrl, isLocalFile),
                ),
                Positioned(
                  left: 0,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 28),
                    onPressed: () {
                      // TODO: פעולה למעבר אחורה
                    },
                  ),
                ),
                Positioned(
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 28),
                    onPressed: () {
                      // TODO: פעולה למעבר קדימה
                    },
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

  Widget _buildImage(String? imageUrl, bool isLocalFile) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholder();
    }

    return SizedBox(
      width: 250,
      height: 250,
      child: isLocalFile
          ? Image.file(
        File(imageUrl),
        key: ValueKey(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: _errorBuilder,
      )
          : Image.network(
        imageUrl,
        key: ValueKey(imageUrl),
        fit: BoxFit.cover,
        loadingBuilder: _loadingBuilder,
        errorBuilder: _errorBuilder,
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
