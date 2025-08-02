import 'package:flutter/material.dart';

class CoinProvider with ChangeNotifier {
  int _coins = 0;

  int get coins => _coins;

  void addCoins(int value) {
    _coins += value;
    notifyListeners();
  }

  void resetCoins() {
    _coins = 0;
    notifyListeners();
  }
}
