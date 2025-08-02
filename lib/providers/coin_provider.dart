import 'package:flutter/foundation.dart';


class CoinProvider with ChangeNotifier {
  int _coins = 0;
  int _coinsAtLevelStart = 0;

  int get coins => _coins;
  int get levelCoins => _coins - _coinsAtLevelStart;

  void addCoins(int amount) {
    _coins += amount;
    notifyListeners();
  }

  void setCoins(int amount) {
    _coins = amount;
    notifyListeners();
  }

  void resetCoins() {
    _coins = 0;
    _coinsAtLevelStart = 0;
    notifyListeners();
  }

  void startLevel() {
    _coinsAtLevelStart = _coins;
  }
}
