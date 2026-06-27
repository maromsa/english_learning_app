// lib/services/sync_engine.dart
//
// Uploads dirty (locally-modified) SRS cards to Firestore.
// Called:
//   • At the end of each Lightning/quiz session.
//   • Optionally on app resume (if connectivity is available).
//
// Design:
//   • Reads dirty rows from AppDatabase.
//   • Batch-writes to Firestore (max 500 per batch, Firestore limit).
//   • On success, marks rows as clean (dirty=0).
//   • On failure, leaves rows dirty — they will be retried next session.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'app_database.dart';

class SyncEngine {
  SyncEngine({
    AppDatabase? db,
    FirebaseFirestore? firestore,
  })  : _db = db ?? AppDatabase.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AppDatabase _db;
  final FirebaseFirestore _firestore;

  static const int _batchLimit = 400; // stay safely under 500

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Pushes all dirty SRS cards for [userId] to Firestore.
  /// Returns the number of cards synced.
  Future<int> syncDirtyCards(String userId) async {
    try {
      final dirty = await _db.getDirtyCards(userId);
      if (dirty.isEmpty) return 0;

      var synced = 0;
      // Process in chunks to respect Firestore batch limit.
      for (var i = 0; i < dirty.length; i += _batchLimit) {
        final chunk = dirty.sublist(
            i, (i + _batchLimit).clamp(0, dirty.length));
        await _uploadChunk(userId, chunk);
        synced += chunk.length;
      }
      return synced;
    } catch (e, st) {
      debugPrint('SyncEngine.syncDirtyCards: $e\n$st');
      return 0;
    }
  }

  /// Downloads SRS cards from Firestore for a given level and merges into
  /// the local DB. Only updates rows where Firestore data is NEWER
  /// (last_review_ms comparison).
  Future<void> pullLevelFromFirestore({
    required String userId,
    required String levelId,
  }) async {
    try {
      final col = _firestore
          .collection('users')
          .doc(userId)
          .collection('srs_cards');

      final snapshot = await col
          .where('levelId', isEqualTo: levelId)
          .get(const GetOptions(source: Source.server));

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final remoteLastMs = (data['lastReviewMs'] as int?) ?? 0;

        // Check if local is newer; if so, skip.
        final local = await _db.getSrsCard(
          userId: userId,
          levelId: levelId,
          wordId: data['wordId'] as String? ?? doc.id,
        );
        final localLastMs = (local?['last_review_ms'] as int?) ?? 0;
        if (localLastMs >= remoteLastMs) continue;

        await _db.upsertSrsCard(
          userId: userId,
          levelId: levelId,
          wordId: data['wordId'] as String? ?? doc.id,
          repetitions: (data['repetitions'] as int?) ?? 0,
          easeFactor: (data['easeFactor'] as num?)?.toDouble() ?? 2.5,
          intervalDays: (data['intervalDays'] as int?) ?? 1,
          masteryLevel: (data['masteryLevel'] as num?)?.toDouble() ?? 0.0,
          bestStars: (data['bestStars'] as int?) ?? 0,
          nextReviewDate: data['nextReviewMs'] != null
              ? DateTime.fromMillisecondsSinceEpoch(data['nextReviewMs'] as int)
              : null,
          lastReviewDate: remoteLastMs > 0
              ? DateTime.fromMillisecondsSinceEpoch(remoteLastMs)
              : null,
          dirty: false, // just downloaded → clean
        );
      }
    } catch (e) {
      debugPrint('SyncEngine.pullLevelFromFirestore: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _uploadChunk(
      String userId, List<Map<String, dynamic>> rows) async {
    final batch = _firestore.batch();

    // Group by (levelId, wordId) for the doc path.
    final levelWordPairs = <({String levelId, String wordId})>[];

    for (final row in rows) {
      final levelId = row['level_id'] as String;
      final wordId = row['word_id'] as String;
      final docId = '${levelId}_$wordId';

      final ref = _firestore
          .collection('users')
          .doc(userId)
          .collection('srs_cards')
          .doc(docId);

      batch.set(ref, {
        'wordId': wordId,
        'levelId': levelId,
        'repetitions': row['repetitions'],
        'easeFactor': row['ease_factor'],
        'intervalDays': row['interval_days'],
        'masteryLevel': row['mastery_level'],
        'bestStars': row['best_stars'],
        'nextReviewMs': row['next_review_ms'],
        'lastReviewMs': row['last_review_ms'],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      levelWordPairs.add((levelId: levelId, wordId: wordId));
    }

    await batch.commit();

    // Mark as clean — group by levelId for efficiency.
    final byLevel = <String, List<String>>{};
    for (final pair in levelWordPairs) {
      byLevel.putIfAbsent(pair.levelId, () => []).add(pair.wordId);
    }
    for (final entry in byLevel.entries) {
      await _db.markCardsSynced(
        userId: userId,
        levelId: entry.key,
        wordIds: entry.value,
      );
    }
  }
}
