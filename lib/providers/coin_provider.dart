import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CoinProvider with ChangeNotifier {
  int _coins = 0;
  int _coinsAtLevelStart = 0;

  int get coins => _coins;
  int get levelCoins => _coins - _coinsAtLevelStart;

  Future<void> loadCoins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _coins = prefs.getInt('totalCoins') ?? 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading coins: $e');
    }
  }

  Future<void> _saveCoins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('totalCoins', _coins);
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

  void startLevel() {
    _coinsAtLevelStart = _coins;
  }
}
