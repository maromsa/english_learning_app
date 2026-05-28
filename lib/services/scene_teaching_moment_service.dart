import 'dart:async';

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/scene_teaching_moment.dart';
import 'package:english_learning_app/models/scavenger_hunt_challenge.dart';
import 'package:english_learning_app/services/gemini_proxy_service.dart';
import 'package:flutter/foundation.dart';

/// Loads a [SceneTeachingMoment] from `scene_description` with timeout + fallback.
class SceneTeachingMomentService {
  SceneTeachingMomentService(
    this._proxy, {
    this.sceneDescriptionTimeout = const Duration(seconds: 10),
  });

  final GeminiProxyService _proxy;
  final Duration sceneDescriptionTimeout;

  Future<SceneTeachingMoment> fetchForSuccessPhoto(
    Uint8List imageBytes,
    ScavengerHuntChallenge challenge, {
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final raw = await _proxy
          .describeSceneAndQuizChild(
            imageBytes,
            mimeType: mimeType,
          )
          .timeout(sceneDescriptionTimeout);

      if (raw == null) {
        return _fallback(challenge);
      }

      final moment = SceneTeachingMoment.fromMap(raw);
      if (moment.description.isEmpty && !moment.hasRichContent) {
        return _fallback(challenge);
      }

      return moment;
    } on TimeoutException catch (error, stackTrace) {
      debugPrint(
        '[SceneTeachingMomentService] scene_description timed out: $error',
      );
      debugPrint('$stackTrace');
      return _fallback(challenge);
    } catch (error, stackTrace) {
      debugPrint(
        '[SceneTeachingMomentService] scene_description failed: $error',
      );
      debugPrint('$stackTrace');
      return _fallback(challenge);
    }
  }

  SceneTeachingMoment _fallback(ScavengerHuntChallenge challenge) {
    final objects = challenge.englishHint != null
        ? <String>[challenge.validationWord]
        : <String>[challenge.validationWord];

    return SceneTeachingMoment.fallback(
      description: SparkStrings.scavengerTeachingFallback(
        challenge.emoji,
        challenge.promptHebrew,
      ),
      targetObjects: objects,
    );
  }
}
