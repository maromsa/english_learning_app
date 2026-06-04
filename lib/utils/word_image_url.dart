import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Web [XFile.path] values are often ephemeral `blob:` URLs revoked after pick.
bool isEphemeralWebBlobUrl(String? url) =>
    url != null && url.startsWith('blob:');

bool isInlineDataImageUrl(String url) => url.startsWith('data:image');

/// Stable data URL for persisting picked camera images on Flutter Web.
String dataImageUrlFromBytes(
  Uint8List bytes, {
  String mimeType = 'image/jpeg',
}) =>
    Uri.dataFromBytes(bytes, mimeType: mimeType).toString();

/// Reads picker bytes immediately; avoids relying on a later-revoked blob URL.
Future<Uint8List?> readPickedImageBytes(XFile file) async {
  try {
    final bytes = await file.readAsBytes();
    if (bytes.isNotEmpty) {
      return Uint8List.fromList(bytes);
    }
  } catch (error, stackTrace) {
    debugPrint('readPickedImageBytes failed: $error');
    debugPrint('$stackTrace');
  }
  return null;
}

Uint8List? decodeDataImageUrl(String dataUrl) {
  final commaIndex = dataUrl.indexOf(',');
  if (commaIndex < 0) {
    return null;
  }
  final header = dataUrl.substring(0, commaIndex);
  if (!header.startsWith('data:image/') || !header.contains('base64')) {
    return null;
  }
  try {
    return base64Decode(dataUrl.substring(commaIndex + 1));
  } catch (error) {
    debugPrint('decodeDataImageUrl failed: $error');
    return null;
  }
}

/// Renders http(s), data:, or blob: word images without [CachedNetworkImage].
Widget buildInlineOrNetworkWordImage(
  String imageUrl, {
  BoxFit fit = BoxFit.cover,
  Alignment alignment = Alignment.center,
  Widget? placeholder,
  Widget? errorWidget,
}) {
  if (isInlineDataImageUrl(imageUrl)) {
    final bytes = decodeDataImageUrl(imageUrl);
    if (bytes == null) {
      return errorWidget ?? const SizedBox.shrink();
    }
    return Image.memory(
      bytes,
      fit: fit,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) =>
          errorWidget ?? const Icon(Icons.broken_image),
    );
  }

  if (imageUrl.startsWith('blob:')) {
    return Image.network(
      imageUrl,
      fit: fit,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) =>
          errorWidget ?? const Icon(Icons.broken_image),
    );
  }

  return Image.network(
    imageUrl,
    fit: fit,
    alignment: alignment,
    width: double.infinity,
    height: double.infinity,
    loadingBuilder: (context, child, progress) {
      if (progress == null) {
        return child;
      }
      return placeholder ??
          const Center(child: CircularProgressIndicator(strokeWidth: 2));
    },
    errorBuilder: (_, __, ___) =>
        errorWidget ?? const Icon(Icons.broken_image),
  );
}
