import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_data.dart';
import '../models/shop_item.dart';
import '../services/local_user_data_service.dart';
import '../services/user_data_service.dart';

class CoinProvider with ChangeNotifier {
  CoinProvider({
    UserDataService? userDataService,
    LocalUserDataService? localUserDataService,
  })  : _userDataService = userDataService ?? UserDataService(),
        _localUserDataService = localUserDataService ?? LocalUserDataService();

  final UserDataService _userDataService;
  final LocalUserDataService _localUserDataService;
  SharedPreferences? _prefs;
  int _coins = 0;
  int _coinsAtLevelStart = 0;
  String? _currentUserId;
  bool _isLocalUser = false;
  bool _pendingCloudSync = false;
  bool _pendingItemsCloudSync = false;
  final List<String> _ownedShopItemIds = [];

  Future<SharedPreferences> get _sharedPrefs async =>
      _prefs ??= await SharedPreferences.getInstance();

  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  int get coins => _coins;

  /// Number of shop items owned (for Map Builder achievement).
  int get ownedShopItemsCount => _ownedShopItemIds.length;

  /// Whether the user owns the shop item with [shopItemId].
  bool isOwned(String shopItemId) => _ownedShopItemIds.contains(shopItemId);
  int get levelCoins => _coins - _coinsAtLevelStart;

  /// Set the current user ID for cloud sync
  /// [isLocalUser] indicates if this is a local user (not Firebase Auth)
  void setUserId(String? userId, {bool isLocalUser = false}) {
    _currentUserId = userId;
    _isLocalUser = isLocalUser;
  }

  /// Retries deferred Firestore writes (coins and/or owned shop items)
  /// after a prior cloud failure.
  Future<void> flushPendingCloudSync() async {
    if (_currentUserId == null || _isLocalUser) {
      return;
    }

    if (_pendingCloudSync) {
      // updateCoins reports failures via its return value (it never throws).
      final synced =
          await _userDataService.updateCoins(_currentUserId!, _coins);
      if (!synced) {
        debugPrint('Cloud coin sync retry failed, will retry later');
      }
      _pendingCloudSync = !synced;
    }

    if (_pendingItemsCloudSync) {
      // addPurchasedItems is an idempotent arrayUnion, so retrying with the
      // full current list is safe even if some ids already reached the cloud.
      final synced = await _userDataService.addPurchasedItems(
        _currentUserId!,
        _ownedShopItemIds,
      );
      if (!synced) {
        debugPrint('Cloud shop-item sync retry failed, will retry later');
      }
      _pendingItemsCloudSync = !synced;
    }
  }

  Future<void> loadCoins() async {
    try {
      if (_currentUserId == null) {
        // Fallback to global coins if no user is set
        final prefs = await _sharedPrefs;
        _coins = prefs.getInt('totalCoins') ?? 0;
        _ownedShopItemIds.clear();
        _ownedShopItemIds.addAll(
          prefs.getStringList('owned_shop_items') ?? [],
        );
        _notify();
        return;
      }

      if (_isLocalUser) {
        _coins = await _localUserDataService.getCoins(_currentUserId!);
        _ownedShopItemIds.clear();
        _ownedShopItemIds.addAll(
          await _localUserDataService.getPurchasedItems(_currentUserId!),
        );
      } else {
        // Firebase users: cloud is the source of truth so coins roam across
        // devices — unless a local write is still waiting to be synced.
        final prefs = await _sharedPrefs;
        final localCoins = prefs.getInt('user_${_currentUserId}_coins') ??
            prefs.getInt('totalCoins') ??
            0;
        final localItems =
            prefs.getStringList('user_${_currentUserId}_owned_shop_items') ??
                [];

        // One load covers both coins and owned items; only fetch it if at
        // least one of the two isn't sitting on an unsynced local write.
        PlayerData? playerData;
        if (!_pendingCloudSync || !_pendingItemsCloudSync) {
          playerData = await _userDataService.loadPlayerData(_currentUserId!);
        }

        if (_pendingCloudSync) {
          _coins = localCoins;
        } else if (playerData != null) {
          _coins = playerData.coins;
          await prefs.setInt('user_${_currentUserId}_coins', _coins);
        } else {
          _coins = localCoins;
        }

        _ownedShopItemIds.clear();
        if (_pendingItemsCloudSync) {
          _ownedShopItemIds.addAll(localItems);
        } else {
          // Items are a set, not a scalar: merge rather than let either side
          // clobber the other, so a purchase made on device A while device B
          // was offline survives on both once B comes back online.
          final cloudItems = playerData?.purchasedItems ?? const <String>[];
          final merged = <String>{...localItems, ...cloudItems}.toList();
          _ownedShopItemIds.addAll(merged);
          await prefs.setStringList(
            'user_${_currentUserId}_owned_shop_items',
            merged,
          );

          final localOnly =
              localItems.where((id) => !cloudItems.contains(id)).toList();
          if (localOnly.isNotEmpty) {
            final synced = await _userDataService.addPurchasedItems(
              _currentUserId!,
              localOnly,
            );
            if (!synced) {
              debugPrint(
                'Cloud shop-item sync deferred on load, will retry later',
              );
              _pendingItemsCloudSync = true;
            }
          }
        }

        await flushPendingCloudSync();
      }
      _notify();
    } catch (e) {
      debugPrint('Error loading coins: $e');
    }
  }

  /// Load coins at level start for a specific level
  Future<void> loadLevelStartCoins(String levelId) async {
    try {
      final prefs = await _sharedPrefs;
      if (_currentUserId == null) {
        _coinsAtLevelStart =
            prefs.getInt('level_${levelId}_start_coins') ?? _coins;
      } else {
        _coinsAtLevelStart = prefs.getInt(
              'user_${_currentUserId}_level_${levelId}_start_coins',
            ) ??
            _coins;
      }
    } catch (e) {
      debugPrint('Error loading level start coins: $e');
      _coinsAtLevelStart = _coins;
    }
  }

  /// Persists [_coins]. On a hard local-save failure the balance is rolled
  /// back to [previousCoins] (the value before the in-memory mutation).
  Future<void> _saveCoins({required int previousCoins}) async {
    try {
      if (_currentUserId == null) {
        // Fallback to global coins if no user is set
        final prefs = await _sharedPrefs;
        await prefs.setInt('totalCoins', _coins);
        return;
      }

      if (_isLocalUser) {
        // Save for local user
        await _localUserDataService.saveCoins(_currentUserId!, _coins);
        return;
      }

      // Firebase user: persist locally first, then cloud (defer on cloud failure).
      final prefs = await _sharedPrefs;
      await prefs.setInt('user_${_currentUserId}_coins', _coins);

      // updateCoins reports failures via its return value (it never throws).
      final synced =
          await _userDataService.updateCoins(_currentUserId!, _coins);
      if (!synced) {
        debugPrint('Cloud coin sync deferred, will retry later');
      }
      _pendingCloudSync = !synced;
    } catch (e) {
      debugPrint('Critical: coin save failed, rolling back: $e');
      _coins = previousCoins;
      _notify();
    }
  }

  Future<void> addCoins(int amount) async {
    if (amount <= 0) {
      debugPrint('Ignored attempt to add a non-positive coin amount: $amount');
      return;
    }

    final previous = _coins;
    _coins += amount;
    _notify();
    await _saveCoins(previousCoins: previous);
  }

  Future<void> setCoins(int amount) async {
    if (amount < 0) {
      debugPrint('Attempted to set a negative coin balance: $amount');
    }

    final previous = _coins;
    _coins = amount < 0 ? 0 : amount;
    _notify();
    await _saveCoins(previousCoins: previous);
  }

  Future<bool> spendCoins(int amount) async {
    if (amount <= 0) {
      debugPrint(
        'Ignored attempt to spend a non-positive coin amount: $amount',
      );
      return false;
    }

    if (_coins >= amount) {
      final previous = _coins;
      _coins -= amount;
      _notify();
      await _saveCoins(previousCoins: previous);
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
      _notify();
    }
    return success;
  }

  Future<void> _saveOwnedItems() async {
    try {
      if (_currentUserId == null) {
        final prefs = await _sharedPrefs;
        await prefs.setStringList('owned_shop_items', _ownedShopItemIds);
        return;
      }
      if (_isLocalUser) {
        await _localUserDataService.savePurchasedItems(
          _currentUserId!,
          _ownedShopItemIds,
        );
        return;
      }

      // Firebase user: persist locally first, then cloud (defer on cloud
      // failure) — matches _saveCoins's offline-first pattern.
      final prefs = await _sharedPrefs;
      await prefs.setStringList(
        'user_${_currentUserId}_owned_shop_items',
        _ownedShopItemIds,
      );

      // addPurchasedItems is an idempotent arrayUnion, so pushing the whole
      // current list (not just the newly-purchased id) is safe and also
      // doubles as a retry for anything a previous attempt missed.
      final synced = await _userDataService.addPurchasedItems(
        _currentUserId!,
        _ownedShopItemIds,
      );
      if (!synced) {
        debugPrint('Cloud shop-item sync deferred, will retry later');
      }
      _pendingItemsCloudSync = !synced;
    } catch (e) {
      debugPrint('Error saving owned shop items: $e');
    }
  }

  Future<void> startLevel(String levelId) async {
    _coinsAtLevelStart = _coins;
    await _saveLevelStartCoins(levelId);
  }

  Future<void> _saveLevelStartCoins(String levelId) async {
    try {
      final prefs = await _sharedPrefs;
      if (_currentUserId == null) {
        await prefs.setInt('level_${levelId}_start_coins', _coinsAtLevelStart);
      } else {
        await prefs.setInt(
          'user_${_currentUserId}_level_${levelId}_start_coins',
          _coinsAtLevelStart,
        );
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

}