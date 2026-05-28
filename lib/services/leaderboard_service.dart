import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/child_profile.dart';
import '../models/leaderboard_entry.dart';
import 'child_profile_service.dart';

/// Loads and ranks child profiles for the global leaderboard.
///
/// Primary source: Firestore `users/{uid}/childProfiles/{profileId}` via
/// [collectionGroup]. Local device profiles are merged so offline learners
/// still appear when cloud data is sparse.
class LeaderboardService {
  LeaderboardService({
    FirebaseFirestore? firestore,
    ChildProfileService? profileService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _profileService = profileService ?? ChildProfileService();

  final FirebaseFirestore _firestore;
  final ChildProfileService _profileService;

  static const int defaultLimit = 50;

  /// Fetches profiles, sorts by [totalCoins] then [currentStreak], assigns ranks.
  Future<LeaderboardResult> fetchLeaderboard({
    String? currentProfileId,
    int limit = defaultLimit,
  }) async {
    final merged = <String, _LeaderboardDraft>{};

    try {
      final snapshot = await _firestore
          .collectionGroup('childProfiles')
          .limit(limit * 3)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final profile = ChildProfile.fromMap(data);
        _upsertDraft(merged, profile);
      }
    } catch (e, stackTrace) {
      debugPrint('LeaderboardService: Firestore query failed: $e');
      debugPrint('$stackTrace');
    }

    try {
      final localProfiles = await _profileService.getAllProfiles();
      for (final profile in localProfiles) {
        _upsertDraft(merged, profile);
      }
    } catch (e) {
      debugPrint('LeaderboardService: local profiles failed: $e');
    }

    final sorted = merged.values.toList()
      ..sort((a, b) {
        final coinCmp = b.totalCoins.compareTo(a.totalCoins);
        if (coinCmp != 0) {
          return coinCmp;
        }
        return b.currentStreak.compareTo(a.currentStreak);
      });

    final capped = sorted.take(limit).toList();
    final entries = <LeaderboardEntry>[];
    LeaderboardEntry? currentUserEntry;

    for (var i = 0; i < capped.length; i++) {
      final draft = capped[i];
      final isCurrent =
          currentProfileId != null && draft.profileId == currentProfileId;
      final entry = LeaderboardEntry(
        profileId: draft.profileId,
        displayName: draft.displayName,
        totalCoins: draft.totalCoins,
        currentStreak: draft.currentStreak,
        avatarColor: draft.avatarColor,
        avatarUrl: draft.avatarUrl,
        rank: i + 1,
        isCurrentUser: isCurrent,
      );
      entries.add(entry);
      if (isCurrent) {
        currentUserEntry = entry;
      }
    }

    if (currentProfileId != null && currentUserEntry == null) {
      final index = sorted.indexWhere((d) => d.profileId == currentProfileId);
      if (index >= 0) {
        final draft = sorted[index];
        currentUserEntry = LeaderboardEntry(
          profileId: draft.profileId,
          displayName: draft.displayName,
          totalCoins: draft.totalCoins,
          currentStreak: draft.currentStreak,
          avatarColor: draft.avatarColor,
          avatarUrl: draft.avatarUrl,
          rank: index + 1,
          isCurrentUser: true,
        );
      }
    }

    return LeaderboardResult(
      entries: entries,
      currentUserEntry: currentUserEntry,
    );
  }

  void _upsertDraft(
      Map<String, _LeaderboardDraft> merged, ChildProfile profile) {
    final existing = merged[profile.id];
    if (existing == null) {
      merged[profile.id] = _LeaderboardDraft.fromProfile(profile);
      return;
    }

    merged[profile.id] = existing.copyWith(
      displayName: profile.displayName,
      totalCoins: profile.coins > existing.totalCoins
          ? profile.coins
          : existing.totalCoins,
      currentStreak: profile.dailyStreak > existing.currentStreak
          ? profile.dailyStreak
          : existing.currentStreak,
      avatarColor: profile.avatarColor,
      avatarUrl: profile.avatarUrl ?? existing.avatarUrl,
    );
  }
}

class _LeaderboardDraft {
  _LeaderboardDraft({
    required this.profileId,
    required this.displayName,
    required this.totalCoins,
    required this.currentStreak,
    required this.avatarColor,
    this.avatarUrl,
  });

  factory _LeaderboardDraft.fromProfile(ChildProfile profile) {
    return _LeaderboardDraft(
      profileId: profile.id,
      displayName: profile.displayName,
      totalCoins: profile.coins,
      currentStreak: profile.dailyStreak,
      avatarColor: profile.avatarColor,
      avatarUrl: profile.avatarUrl,
    );
  }

  final String profileId;
  final String displayName;
  final int totalCoins;
  final int currentStreak;
  final int avatarColor;
  final String? avatarUrl;

  _LeaderboardDraft copyWith({
    String? displayName,
    int? totalCoins,
    int? currentStreak,
    int? avatarColor,
    String? avatarUrl,
  }) {
    return _LeaderboardDraft(
      profileId: profileId,
      displayName: displayName ?? this.displayName,
      totalCoins: totalCoins ?? this.totalCoins,
      currentStreak: currentStreak ?? this.currentStreak,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
