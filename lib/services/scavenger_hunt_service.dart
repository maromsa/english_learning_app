import 'package:english_learning_app/data/scavenger_hunt_catalog.dart';
import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/scavenger_hunt_challenge.dart';
import 'package:english_learning_app/services/gemini_proxy_service.dart';
import 'package:flutter/foundation.dart';

/// Orchestrates scavenger-hunt rounds and photo validation via [GeminiProxyService].
class ScavengerHuntService {
  ScavengerHuntService(this._proxy, {double minimumConfidence = 0.45})
      : _minimumConfidence = minimumConfidence;

  final GeminiProxyService _proxy;
  final double _minimumConfidence;

  List<ScavengerHuntChallenge> startSession({int rounds = 5}) =>
      ScavengerHuntCatalog.pickSession(count: rounds);

  Future<ScavengerValidationResult> validateFind(
    Uint8List imageBytes,
    ScavengerHuntChallenge challenge, {
    String mimeType = 'image/jpeg',
  }) async {
    final word = challenge.validationWord;
    final result = await _proxy.validateImageMatch(
      imageBytes,
      word,
      mimeType: mimeType,
    );

    if (result == null) {
      return const ScavengerValidationResult(
        approved: false,
        feedbackHebrew: SparkStrings.scavengerNetworkFail,
      );
    }

    final confidence = result.confidence;
    final meetsConfidence =
        confidence == null || confidence >= _minimumConfidence;

    if (result.approved && meetsConfidence) {
      return ScavengerValidationResult(
        approved: true,
        confidence: confidence,
        feedbackHebrew: SparkStrings.scavengerSuccess(challenge.emoji),
      );
    }

    return ScavengerValidationResult(
      approved: false,
      confidence: confidence,
      feedbackHebrew: SparkStrings.scavengerTryAgain(challenge.promptHebrew),
    );
  }
}
