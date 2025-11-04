import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

/// Contract for validating whether an image matches a requested word.
abstract class AiImageValidator {
  Future<bool> validate(Uint8List imageBytes, String word, {String? mimeType});
}

/// Validator that always approves the provided image.
class PassthroughAiImageValidator implements AiImageValidator {
  const PassthroughAiImageValidator();

  @override
  Future<bool> validate(Uint8List imageBytes, String word, {String? mimeType}) async => true;
}

/// Uses Gemini to confirm that the supplied image depicts the requested word.
class GeminiAiImageValidator implements AiImageValidator {
  GeminiAiImageValidator(this._model);

  final GenerativeModel _model;

  static const String _promptTemplate =
      'You are helping a child learn English words. '
      'Does this picture clearly show the object "{word}" as the main focus? '
      'Answer strictly with "yes" or "no".';

  @override
  Future<bool> validate(Uint8List imageBytes, String word, {String? mimeType}) async {
    final prompt = _promptTemplate.replaceFirst('{word}', word);

    try {
      final response = await _model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType ?? 'image/jpeg', imageBytes),
        ]),
      ]);

      final answer = response.text?.trim().toLowerCase();
      if (answer == null || answer.isEmpty) {
        return false;
      }

      if (answer.startsWith('yes')) {
        return true;
      }

      if (answer.startsWith('no')) {
        return false;
      }

      return answer.contains('yes');
    } catch (_) {
      return false;
    }
  }
}
