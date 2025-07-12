import 'package:flutter/material.dart';

class SubscriptionProvider extends ChangeNotifier {
  bool _isPremium = false;

  bool get isPremium => _isPremium;

  // サブスク状態をセット
  void setPremium(bool value) {
    _isPremium = value;
    notifyListeners();
  }

  // サブスク状態の永続化・復元（仮実装）
  Future<void> loadStatus() async {
    // TODO: 実際はストア/SharedPreferences等から復元
    _isPremium = false;
    notifyListeners();
  }
}
