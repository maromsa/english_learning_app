import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_data_service.dart';
import '../services/local_user_data_service.dart';

class CoinProvider with ChangeNotifier {
  CoinProvider({
    UserDataService? userDataService,
    LocalUserDataService? localUserDataService,
  })  : _userDataService = userDataService ?? UserDataService(),
        _localUserDataService = localUserDataService ?? LocalUserDataService();

  final UserDataService _userDataService;
  final LocalUserDataService _localUserDataService;
  int _coins = 0;
  int _coinsAtLevelStart = 0;
  String? _currentUserId;
  bool _isLocalUser = false;

  int get coins => _coins;
  int get levelCoins {
    final earned = _coins - _coinsAtLevelStart;
    debugPrint(
        'Level coins calculation: $_coins - $_coinsAtLevelStart = $earned');
    return earned;
  }

  /// Set the current user ID for cloud sync
  /// [isLocalUser] indicates if this is a local user (not Firebase Auth)
  void setUserId(String? userId, {bool isLocalUser = false}) {
    _currentUserId = userId;
    _isLocalUser = isLocalUser;
  }

  Future<void> loadCoins() async {
    try {
      if (_currentUserId == null) {
        // Fallback to global coins if no user is set
        final prefs = await SharedPreferences.getInstance();
        _coins = prefs.getInt('totalCoins') ?? 0;
        notifyListeners();
        return;
      }

      if (_isLocalUser) {
        _coins = await _localUserDataService.getCoins(_currentUserId!);
      } else {
        // For Firebase users, try cloud first, then fallback to local
        final prefs = await SharedPreferences.getInstance();
        _coins = prefs.getInt('user_${_currentUserId}_coins') ??
            prefs.getInt('totalCoins') ??
            0;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading coins: $e');
    }
  }

  /// Load coins at level start for a specific level
  Future<void> loadLevelStartCoins(String levelId) async {
    try {
      if (_currentUserId == null) {
        final prefs = await SharedPreferences.getInstance();
        _coinsAtLevelStart =
            prefs.getInt('level_${levelId}_start_coins') ?? _coins;
        return;
      }

      if (_isLocalUser) {
        final prefs = await SharedPreferences.getInstance();
        _coinsAtLevelStart = prefs.getInt(
                'user_${_currentUserId}_level_${levelId}_start_coins') ??
            _coins;
      } else {
        final prefs = await SharedPreferences.getInstance();
        _coinsAtLevelStart = prefs.getInt(
                'user_${_currentUserId}_level_${levelId}_start_coins') ??
            _coins;
      }
    } catch (e) {
      debugPrint('Error loading level start coins: $e');
      _coinsAtLevelStart = _coins;
    }
  }

  Future<void> _saveCoins() async {
    try {
      if (_currentUserId == null) {
        // Fallback to global coins if no user is set
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('totalCoins', _coins);
        return;
      }

      if (_isLocalUser) {
        // Save for local user
        await _localUserDataService.saveCoins(_currentUserId!, _coins);
      } else {
        // Save locally for Firebase user
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_${_currentUserId}_coins', _coins);
        // Also save to cloud
        await _userDataService.updateCoins(_currentUserId!, _coins);
      }
    } catch (e) {
      debugPrint('Error saving coins: $e');
    }
  }

  Future<void> addCoins(int amount) async {
    if (amount <= 0) {
      debugPrint('Ignored attempt to add a non-positive coin amount: $amount');
      return;
    }

    _coins += amount;
    notifyListeners();
    await _saveCoins();
  }

  Future<void> setCoins(int amount) async {
    if (amount < 0) {
      debugPrint('Attempted to set a negative coin balance: $amount');
    }

    _coins = amount < 0 ? 0 : amount;
    notifyListeners();
    await _saveCoins();
  }

  Future<bool> spendCoins(int amount) async {
    if (amount <= 0) {
      debugPrint(
        'Ignored attempt to spend a non-positive coin amount: $amount',
      );
      return false;
    }

    if (_coins >= amount) {
      _coins -= amount;
      notifyListeners();
      await _saveCoins();
      return true;
    } else {
      return false;
    }
  }

  Future<void> startLevel(String levelId) async {
    _coinsAtLevelStart = _coins;
    debugPrint('=== Starting Level: $levelId ===');
    debugPrint('Coins at start: $_coinsAtLevelStart');
    await _saveLevelStartCoins(levelId);
  }

  Future<void> _saveLevelStartCoins(String levelId) async {
    try {
      if (_currentUserId == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('level_${levelId}_start_coins', _coinsAtLevelStart);
        return;
      }

      if (_isLocalUser) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
            'user_${_currentUserId}_level_${levelId}_start_coins',
            _coinsAtLevelStart);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
            'user_${_currentUserId}_level_${levelId}_start_coins',
            _coinsAtLevelStart);
      }
    } catch (e) {
      debugPrint('Error saving level start coins: $e');
    }
  }

  /// Reset level start coins (when level is completed)
  Future<void> resetLevelStartCoins(String levelId) async {
    _coinsAtLevelStart = _coins;
    await _saveLevelStartCoins(levelId);
  }
}
