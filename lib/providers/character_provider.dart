import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_character.dart';
import '../services/user_data_service.dart';

class CharacterProvider with ChangeNotifier {
  CharacterProvider({UserDataService? userDataService})
      : _userDataService = userDataService ?? UserDataService();

  final UserDataService _userDataService;
  PlayerCharacter? _character;
  String? _currentUserId;

  PlayerCharacter? get character => _character;
  bool get hasCharacter => _character != null;

  /// Set the current user ID for cloud sync
  void setUserId(String? userId) {
    _currentUserId = userId;
  }

  /// Load character from local storage
  Future<void> loadCharacter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final characterId = prefs.getString('character_id');
      final characterName = prefs.getString('character_name');
      final color = prefs.getInt('character_color');

      if (characterId != null && characterName != null) {
        _character = PlayerCharacter(
          characterId: characterId,
          characterName: characterName,
          color: color,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading character: $e');
    }
  }

  /// Save character locally
  Future<void> _saveCharacterLocally() async {
    if (_character == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('character_id', _character!.characterId);
      await prefs.setString('character_name', _character!.characterName);
      if (_character!.color != null) {
        await prefs.setInt('character_color', _character!.color!);
      }
    } catch (e) {
      debugPrint('Error saving character locally: $e');
    }
  }

  /// Set character (saves locally and to cloud)
  Future<void> setCharacter(PlayerCharacter character) async {
    _character = character;
    notifyListeners();

    // Save locally
    await _saveCharacterLocally();

    // Save to cloud if user is authenticated
    if (_currentUserId != null) {
      try {
        await _userDataService.updateCharacter(_currentUserId!, character.toMap());
      } catch (e) {
        debugPrint('Error saving character to cloud: $e');
      }
    }
  }

  /// Load character from cloud
  Future<void> loadCharacterFromCloud(String userId) async {
    try {
      final playerData = await _userDataService.loadPlayerData(userId);
      if (playerData?.character != null) {
        _character = playerData!.character;
        await _saveCharacterLocally();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading character from cloud: $e');
    }
  }
}

