import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/child_profile.dart';
import '../models/local_user.dart';
import 'local_user_service.dart';

/// Offline-first storage for child profiles on device.
class ChildProfileService {
  ChildProfileService({
    SharedPreferences? prefs,
    LocalUserService? localUserService,
  })  : _prefsFuture = prefs != null
            ? Future.value(prefs)
            : SharedPreferences.getInstance(),
        _localUserService = localUserService ?? LocalUserService();

  static const String _profilesKey = 'child_profiles_v1';
  static const String _activeProfileIdKey = 'active_child_profile_id';
  static const String _migrationKey =
      'child_profiles_migrated_from_local_users';

  final Future<SharedPreferences> _prefsFuture;
  final LocalUserService _localUserService;

  Future<List<ChildProfile>> getAllProfiles() async {
    await migrateFromLocalUsersIfNeeded();
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_profilesKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final result = <ChildProfile>[];
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        try {
          result.add(ChildProfile.fromMap(item));
        } catch (e) {
          debugPrint('ChildProfileService: skipping malformed profile: $e');
        }
      }
      return result;
    } catch (e) {
      debugPrint('ChildProfileService: failed to decode profiles: $e');
      return [];
    }
  }

  Future<ChildProfile?> getProfileById(String profileId) async {
    final profiles = await getAllProfiles();
    try {
      return profiles.firstWhere((profile) => profile.id == profileId);
    } catch (_) {
      return null;
    }
  }

  Future<ChildProfile?> getActiveProfile() async {
    final prefs = await _prefsFuture;
    final activeId = prefs.getString(_activeProfileIdKey);
    if (activeId == null) {
      return null;
    }
    return getProfileById(activeId);
  }

  Future<ChildProfile> createProfile({
    required String displayName,
    required int avatarColor,
    String? avatarUrl,
  }) async {
    final profile = ChildProfile.create(
      displayName: displayName,
      avatarColor: avatarColor,
      avatarUrl: avatarUrl,
    );
    await saveProfile(profile);
    return profile;
  }

  Future<void> saveProfile(ChildProfile profile) async {
    final profiles = await getAllProfiles();
    profiles.removeWhere((existing) => existing.id == profile.id);
    profiles.add(profile);
    await _writeProfiles(profiles);
  }

  Future<void> saveProfiles(List<ChildProfile> profiles) async {
    await _writeProfiles(profiles);
  }

  Future<void> setActiveProfile(String profileId) async {
    final prefs = await _prefsFuture;
    await prefs.setString(_activeProfileIdKey, profileId);
  }

  Future<void> clearActiveProfile() async {
    final prefs = await _prefsFuture;
    await prefs.remove(_activeProfileIdKey);
  }

  Future<void> updateLastPlayed(String profileId) async {
    final profile = await getProfileById(profileId);
    if (profile == null) {
      return;
    }
    await saveProfile(
      profile.copyWith(
        lastPlayedAt: DateTime.now(),
        pendingSync: true,
      ),
    );
  }

  Future<void> updateProgressSnapshot({
    required String profileId,
    int? totalStars,
    int? dailyStreak,
    int? completedWordsCount,
    Map<String, bool>? achievements,
    int? coins,
  }) async {
    final profile = await getProfileById(profileId);
    if (profile == null) {
      return;
    }

    await saveProfile(
      profile.copyWith(
        totalStars: totalStars ?? profile.totalStars,
        dailyStreak: dailyStreak ?? profile.dailyStreak,
        completedWordsCount: completedWordsCount ?? profile.completedWordsCount,
        achievements: achievements ?? profile.achievements,
        coins: coins ?? profile.coins,
        updatedAt: DateTime.now(),
        pendingSync: true,
      ),
    );
  }

  Future<bool> deleteProfile(String profileId) async {
    final profiles = await getAllProfiles();
    final before = profiles.length;
    profiles.removeWhere((profile) => profile.id == profileId);
    if (profiles.length == before) {
      return false;
    }

    await _writeProfiles(profiles);

    final prefs = await _prefsFuture;
    if (prefs.getString(_activeProfileIdKey) == profileId) {
      await prefs.remove(_activeProfileIdKey);
    }
    return true;
  }

  Future<List<ChildProfile>> profilesPendingSync() async {
    final profiles = await getAllProfiles();
    return profiles.where((profile) => profile.pendingSync).toList();
  }

  Future<void> markSynced(String profileId) async {
    final profile = await getProfileById(profileId);
    if (profile == null) {
      return;
    }
    await saveProfile(
      profile.copyWith(
        pendingSync: false,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> migrateFromLocalUsersIfNeeded() async {
    final prefs = await _prefsFuture;
    if (prefs.getBool(_migrationKey) ?? false) {
      return;
    }

    final localUsers = await _localUserService.getAllUsers();
    if (localUsers.isEmpty) {
      await prefs.setBool(_migrationKey, true);
      return;
    }

    final existing = await _loadProfilesWithoutMigration();
    final migrated = <ChildProfile>[
      ...existing,
      ...localUsers.map(ChildProfile.fromLocalUser),
    ];

    final deduped = <String, ChildProfile>{};
    for (final profile in migrated) {
      deduped[profile.id] = profile;
    }

    await _writeProfiles(deduped.values.toList());

    final activeLocalId = prefs.getString('active_local_user_id');
    if (activeLocalId != null && deduped.containsKey(activeLocalId)) {
      await prefs.setString(_activeProfileIdKey, activeLocalId);
    }

    await prefs.setBool(_migrationKey, true);
  }

  Future<List<ChildProfile>> _loadProfilesWithoutMigration() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_profilesKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final result = <ChildProfile>[];
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        try {
          result.add(ChildProfile.fromMap(item));
        } catch (_) {
          // skip malformed entries — don't discard entire profile list
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeProfiles(List<ChildProfile> profiles) async {
    final prefs = await _prefsFuture;
    final encoded =
        jsonEncode(profiles.map((profile) => profile.toMap()).toList());
    await prefs.setString(_profilesKey, encoded);
  }

  /// One-time import helper for tests.
  Future<void> importLocalUsers(List<LocalUser> users) async {
    final profiles = await getAllProfiles();
    for (final user in users) {
      profiles.removeWhere((profile) => profile.id == user.id);
      profiles.add(ChildProfile.fromLocalUser(user));
    }
    await _writeProfiles(profiles);
  }
}
