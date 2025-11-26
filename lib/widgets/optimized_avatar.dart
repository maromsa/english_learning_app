import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Optimized avatar widget that uses CachedNetworkImage with memory optimization
/// for better performance and reduced memory usage.
class OptimizedAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? backgroundColor;
  final String? fallbackText;

  const OptimizedAvatar({
    super.key,
    this.imageUrl,
    required this.radius,
    this.placeholder,
    this.errorWidget,
    this.backgroundColor,
    this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate memCache size based on radius (3x for high DPI screens)
    final memCacheSize = (radius * 2 * 3).round();

    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey.shade300,
        child: errorWidget ??
            (fallbackText != null && fallbackText!.isNotEmpty
                ? Text(
                    fallbackText![0].toUpperCase(),
                    style: TextStyle(
                      fontSize: radius * 0.7,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.person, color: Colors.white)),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey.shade300,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          // Critical: Resize to display size to save RAM
          memCacheWidth: memCacheSize,
          memCacheHeight: memCacheSize,
          placeholder: (context, url) => placeholder ??
              Container(
                width: radius * 2,
                height: radius * 2,
                color: Colors.grey.shade200,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          errorWidget: (context, url, error) =>
              errorWidget ??
              CircleAvatar(
                radius: radius,
                backgroundColor: Colors.grey.shade300,
                child: fallbackText != null && fallbackText!.isNotEmpty
                    ? Text(
                        fallbackText![0].toUpperCase(),
                        style: TextStyle(
                          fontSize: radius * 0.7,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.white),
              ),
          fadeInDuration: const Duration(milliseconds: 200),
        ),
      ),
    );
  }
}


