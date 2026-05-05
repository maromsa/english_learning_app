import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shop_item.dart';
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
  final List<String> _ownedShopItemIds = [];

  int get coins => _coins;

  /// Number of shop items owned (for Map Builder achievement).
  int get ownedShopItemsCount => _ownedShopItemIds.length;

  /// Whether the user owns the shop item with [shopItemId].
  bool isOwned(String shopItemId) => _ownedShopItemIds.contains(shopItemId);
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
        _ownedShopItemIds.clear();
        _ownedShopItemIds.addAll(
          prefs.getStringList('owned_shop_items') ?? [],
        );
        notifyListeners();
        return;
      }

      if (_isLocalUser) {
        _coins = await _localUserDataService.getCoins(_currentUserId!);
        _ownedShopItemIds.clear();
        _ownedShopItemIds.addAll(
          await _localUserDataService.getPurchasedItems(_currentUserId!),
        );
      } else {
        // For Firebase users, try cloud first, then fallback to local
        final prefs = await SharedPreferences.getInstance();
        _coins = prefs.getInt('user_${_currentUserId}_coins') ??
            prefs.getInt('totalCoins') ??
            0;
        _ownedShopItemIds.clear();
        _ownedShopItemIds.addAll(
          prefs.getStringList('user_${_currentUserId}_owned_shop_items') ?? [],
        );
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

  /// Purchase a shop item: deducts coins and marks the item as owned.
  /// Returns true if the purchase succeeded (or item was already owned).
  Future<bool> purchaseItem(ShopItem item) async {
    if (_ownedShopItemIds.contains(item.id)) {
      return true;
    }
    if (_coins < item.cost) {
      return false;
    }
    final success = await spendCoins(item.cost);
    if (success) {
      _ownedShopItemIds.add(item.id);
      await _saveOwnedItems();
      notifyListeners();
    }
    return success;
  }

  Future<void> _saveOwnedItems() async {
    try {
      if (_currentUserId == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('owned_shop_items', _ownedShopItemIds);
        return;
      }
      if (_isLocalUser) {
        await _localUserDataService.savePurchasedItems(
          _currentUserId!,
          _ownedShopItemIds,
        );
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          'user_${_currentUserId}_owned_shop_items',
          _ownedShopItemIds,
        );
      }
    } catch (e) {
      debugPrint('Error saving owned shop items: $e');
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
