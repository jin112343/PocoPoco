import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionProvider extends ChangeNotifier {
  bool _isPremium = false;
  String? _activeSubscriptionId;
  DateTime? _subscriptionExpiryDate;
  static const String _premiumKey = 'is_premium';
  static const String _subscriptionIdKey = 'subscription_id';
  static const String _expiryDateKey = 'subscription_expiry';

  bool get isPremium {
    print('=== SubscriptionProvider.isPremium called ===');
    print('_isPremium: $_isPremium');
    print('_activeSubscriptionId: $_activeSubscriptionId');
    print('_subscriptionExpiryDate: $_subscriptionExpiryDate');
    return _isPremium;
  }

  String? get activeSubscriptionId => _activeSubscriptionId;
  DateTime? get subscriptionExpiryDate => _subscriptionExpiryDate;

  // サブスクリプション状態をセット
  void setPremium(bool value,
      {String? subscriptionId, DateTime? expiryDate}) async {
    print('プレミアム状態を設定: $value, サブスクID: $subscriptionId, 有効期限: $expiryDate');
    _isPremium = value;
    _activeSubscriptionId = subscriptionId;
    _subscriptionExpiryDate = expiryDate;
    notifyListeners();

    // 永続化
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_premiumKey, value);
      if (subscriptionId != null) {
        await prefs.setString(_subscriptionIdKey, subscriptionId);
      } else {
        await prefs.remove(_subscriptionIdKey);
      }
      if (expiryDate != null) {
        await prefs.setString(_expiryDateKey, expiryDate.toIso8601String());
      } else {
        await prefs.remove(_expiryDateKey);
      }
      print('プレミアム状態を永続化: $value, サブスクID: $subscriptionId, 有効期限: $expiryDate');
    } catch (e) {
      print('プレミアム状態の永続化エラー: $e');
    }
  }

  // サブスクリプション状態の永続化・復元
  Future<void> loadStatus() async {
    try {
      print('=== SubscriptionProvider.loadStatus 開始 ===');
      final prefs = await SharedPreferences.getInstance();

      final savedPremium = prefs.getBool(_premiumKey);
      print('SharedPreferencesから読み込んだプレミアム状態: $savedPremium');

      _isPremium = savedPremium ?? false;
      _activeSubscriptionId = prefs.getString(_subscriptionIdKey);
      final expiryString = prefs.getString(_expiryDateKey);

      print('読み込まれた値:');
      print('  _isPremium: $_isPremium');
      print('  _activeSubscriptionId: $_activeSubscriptionId');
      print('  expiryString: $expiryString');

      if (expiryString != null) {
        _subscriptionExpiryDate = DateTime.parse(expiryString);
        print('  _subscriptionExpiryDate: $_subscriptionExpiryDate');
      }

      // 有効期限をチェック
      print('有効期限チェック開始');
      await _checkSubscriptionValidity();

      print('=== プレミアム状態復元完了 ===');
      print('最終的なプレミアム状態: $_isPremium');
      print('サブスクID: $_activeSubscriptionId');
      print('有効期限: $_subscriptionExpiryDate');
      notifyListeners();
    } catch (e) {
      print('プレミアム状態の復元エラー: $e');
      _isPremium = false;
      _activeSubscriptionId = null;
      _subscriptionExpiryDate = null;
      notifyListeners();
    }
  }

  // サブスクリプションの有効性をチェック
  Future<void> _checkSubscriptionValidity() async {
    if (_subscriptionExpiryDate != null &&
        DateTime.now().isAfter(_subscriptionExpiryDate!)) {
      // 有効期限が切れている場合
      print('サブスクリプションの有効期限が切れています');
      await _cancelSubscription();
    }
  }

  // サブスクリプションをキャンセル
  Future<void> _cancelSubscription() async {
    _isPremium = false;
    _activeSubscriptionId = null;
    _subscriptionExpiryDate = null;
    notifyListeners();

    // 永続化
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_premiumKey, false);
      await prefs.remove(_subscriptionIdKey);
      await prefs.remove(_expiryDateKey);
      print('サブスクリプションをキャンセルしました');
    } catch (e) {
      print('サブスクリプションキャンセル時の永続化エラー: $e');
    }
  }

  // 現在の支払い状況を確認
  Future<Map<String, dynamic>> checkPaymentStatus() async {
    try {
      final InAppPurchase iap = InAppPurchase.instance;
      final bool isAvailable = await iap.isAvailable();

      if (!isAvailable) {
        return {'available': false, 'error': 'ストアが利用できません'};
      }

      // 現在のサブスクリプション状態を返す
      return {
        'available': true,
        'hasActiveSubscription': _isPremium,
        'subscriptionId': _activeSubscriptionId,
        'expiryDate': _subscriptionExpiryDate?.toIso8601String(),
        'isValid': isSubscriptionValid()
      };
    } catch (e) {
      return {'available': false, 'error': '支払い状況の確認中にエラーが発生しました: $e'};
    }
  }

  // サブスクリプションを手動でキャンセル（ユーザー操作）
  Future<void> cancelSubscription() async {
    await _cancelSubscription();
  }

  // サブスクリプションの有効期限を更新
  void updateSubscriptionExpiry(DateTime expiryDate) {
    _subscriptionExpiryDate = expiryDate;
    notifyListeners();

    // 永続化
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_expiryDateKey, expiryDate.toIso8601String());
    });
  }

  // サブスクリプションが有効かどうかをチェック
  bool isSubscriptionValid() {
    if (!_isPremium || _subscriptionExpiryDate == null) {
      return false;
    }
    return DateTime.now().isBefore(_subscriptionExpiryDate!);
  }
}
