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

    // אם אין תמונה בכלל (null או ריק), מציגים אייקון של placeholder
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholder(wordData.word);
    }

    final bool isLocalFile = !imageUrl.startsWith('http');

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: isLocalFile
              ? Image.file(
            File(imageUrl),
            key: ValueKey(imageUrl),
            width: 250,
            height: 250,
            fit: BoxFit.cover,
            errorBuilder: _errorBuilder,
          )
              : Image.network(
            imageUrl,
            key: ValueKey(imageUrl),
            width: 250,
            height: 250,
            fit: BoxFit.cover,
            loadingBuilder: _loadingBuilder,
            errorBuilder: _errorBuilder,
          ),
        ),
        const SizedBox(height: 30),
        Text(
          wordData.word,
          style: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(String word) => Column(
    children: [
      const Icon(Icons.image_not_supported, size: 150, color: Colors.grey),
      const SizedBox(height: 30),
      Text(
        word,
        style: const TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
      ),
    ],
  );

  Widget _loadingBuilder(BuildContext context, Widget child,
      ImageChunkEvent? loadingProgress) =>
      loadingProgress == null
          ? child
          : const Center(child: CircularProgressIndicator());

  Widget _errorBuilder(BuildContext context, Object error, StackTrace? stackTrace) =>
      const Icon(Icons.error_outline, size: 150, color: Colors.grey);
}
