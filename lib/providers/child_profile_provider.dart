import 'package:flutter/material.dart';

import '../models/child_profile.dart';
import '../services/child_profile_service.dart';
import '../services/child_profile_sync_service.dart';
import '../utils/active_profile_scope.dart';

class ChildProfileProvider with ChangeNotifier {
  ChildProfileProvider({
    ChildProfileService? profileService,
    ChildProfileSyncService? syncService,
  })  : _profileService = profileService ?? ChildProfileService(),
        _syncService = syncService ?? ChildProfileSyncService();

  final ChildProfileService _profileService;
  final ChildProfileSyncService _syncService;

  List<ChildProfile> _profiles = [];
  ChildProfile? _activeProfile;
  String? _parentUid;
  bool _loading = false;
  bool _initialized = false;

  List<ChildProfile> get profiles => List.unmodifiable(_profiles);
  ChildProfile? get activeProfile => _activeProfile;
  String? get activeProfileId => _activeProfile?.id;
  String? get parentUid => _parentUid;
  bool get loading => _loading;
  bool get initialized => _initialized;
  bool get hasActiveProfile => _activeProfile != null;

  Future<void> initialize({String? parentUid}) async {
    if (_loading) {
      return;
    }

    _loading = true;
    _parentUid = parentUid;
    notifyListeners();

    try {
      await _profileService.migrateFromLocalUsersIfNeeded();
      if (parentUid != null) {
        await _syncService.syncFromCloud(parentUid);
      }

      _profiles = await _profileService.getAllProfiles();
      _activeProfile = await _profileService.getActiveProfile();
    } finally {
      _loading = false;
      _initialized = true;
      notifyListeners();
    }
  }

  Future<ChildProfile> createProfile({
    required String displayName,
    required int avatarColor,
    String? avatarUrl,
  }) async {
    final profile = await _profileService.createProfile(
      displayName: displayName,
      avatarColor: avatarColor,
      avatarUrl: avatarUrl,
    );
    _profiles = await _profileService.getAllProfiles();

    if (_parentUid != null) {
      await _syncService.syncProfileToCloud(_parentUid!, profile);
    }

    notifyListeners();
    return profile;
  }

  Future<void> selectProfile(
    BuildContext context,
    ChildProfile profile,
  ) async {
    await _profileService.setActiveProfile(profile.id);
    await _profileService.updateLastPlayed(profile.id);
    _activeProfile = profile;

    if (!context.mounted) {
      return;
    }

    await ActiveProfileScope.apply(
      context,
      profile,
      parentUid: _parentUid,
      syncService: _syncService,
      profileService: _profileService,
    );

    _profiles = await _profileService.getAllProfiles();
    _activeProfile = await _profileService.getActiveProfile();
    notifyListeners();
  }

  Future<bool> deleteProfile(String profileId) async {
    final deleted = await _profileService.deleteProfile(profileId);
    if (!deleted) {
      return false;
    }

    if (_parentUid != null) {
      await _syncService.deleteFromCloud(_parentUid!, profileId);
    }

    _profiles = await _profileService.getAllProfiles();
    if (_activeProfile?.id == profileId) {
      _activeProfile = null;
    }
    notifyListeners();
    return true;
  }

  Future<void> refreshProfiles() async {
    if (_parentUid != null) {
      await _syncService.syncFromCloud(_parentUid!);
    }
    _profiles = await _profileService.getAllProfiles();
    _activeProfile = await _profileService.getActiveProfile();
    notifyListeners();
  }

  Future<void> syncPendingProfiles() async {
    if (_parentUid == null) {
      return;
    }
    await _syncService.syncPendingToCloud(_parentUid!);
    _profiles = await _profileService.getAllProfiles();
    notifyListeners();
  }

  Future<void> clearActiveProfile() async {
    await _profileService.clearActiveProfile();
    _activeProfile = null;
    notifyListeners();
  }
}
