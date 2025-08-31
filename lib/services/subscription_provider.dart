import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionProvider extends ChangeNotifier {
  bool _isPremium = false;
  String? _activeSubscriptionId;
  DateTime? _subscriptionExpiryDate;
  DateTime? _trialStartDate;
  DateTime? _trialEndDate;
  bool _isInTrialPeriod = false;
  bool _hasUsedTrial = false;
  static const String _premiumKey = 'is_premium';
  static const String _subscriptionIdKey = 'subscription_id';
  static const String _expiryDateKey = 'subscription_expiry';
  static const String _trialStartKey = 'trial_start_date';
  static const String _trialEndKey = 'trial_end_date';
  static const String _isInTrialKey = 'is_in_trial';
  static const String _hasUsedTrialKey = 'has_used_trial';

  bool get isPremium {
    print('=== SubscriptionProvider.isPremium called ===');
    print('_isPremium: $_isPremium');
    print('_activeSubscriptionId: $_activeSubscriptionId');
    print('_subscriptionExpiryDate: $_subscriptionExpiryDate');
    return _isPremium;
  }

  String? get activeSubscriptionId => _activeSubscriptionId;
  DateTime? get subscriptionExpiryDate => _subscriptionExpiryDate;
  DateTime? get trialStartDate => _trialStartDate;
  DateTime? get trialEndDate => _trialEndDate;
  bool get isInTrialPeriod => _isInTrialPeriod;
  bool get hasUsedTrial => _hasUsedTrial;
  
  // トライアル期間が有効かどうかをチェック
  bool get isTrialActive {
    if (!_isInTrialPeriod || _trialEndDate == null) {
      return false;
    }
    return DateTime.now().isBefore(_trialEndDate!);
  }
  
  // トライアル期間の残り日数を取得
  int get trialDaysRemaining {
    if (!_isInTrialPeriod || _trialEndDate == null) {
      return 0;
    }
    final remaining = _trialEndDate!.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

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
      
      // トライアル期間情報も永続化
      await _saveTrialStatus(prefs);
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
      
      // トライアル期間情報を読み込み
      await _loadTrialStatus(prefs);

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
      
      // トライアル期間もリセット（通常のサブスクリプション終了時）
      if (_isInTrialPeriod) {
        _isInTrialPeriod = false;
        _trialStartDate = null;
        _trialEndDate = null;
        await prefs.setBool(_isInTrialKey, false);
        await prefs.remove(_trialStartKey);
        await prefs.remove(_trialEndKey);
      }
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
        'isValid': isSubscriptionValid(),
        'isInTrialPeriod': _isInTrialPeriod,
        'isTrialActive': isTrialActive,
        'trialDaysRemaining': trialDaysRemaining,
        'hasUsedTrial': _hasUsedTrial
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
    // トライアル期間中の場合
    if (_isInTrialPeriod && isTrialActive) {
      return true;
    }
    
    // 通常のサブスクリプション判定
    if (!_isPremium || _subscriptionExpiryDate == null) {
      return false;
    }
    return DateTime.now().isBefore(_subscriptionExpiryDate!);
  }
  
  // 無料トライアルを開始
  Future<void> startFreeTrial() async {
    print('無料トライアルを開始します');
    final now = DateTime.now();
    _trialStartDate = now;
    _trialEndDate = now.add(const Duration(days: 7)); // 7日間の無料トライアル
    _isInTrialPeriod = true;
    _hasUsedTrial = true;
    _isPremium = true; // トライアル期間中はプレミアム機能を利用可能
    
    print('トライアル開始日: $_trialStartDate');
    print('トライアル終了日: $_trialEndDate');
    
    notifyListeners();
    
    // 永続化
    try {
      final prefs = await SharedPreferences.getInstance();
      await _saveTrialStatus(prefs);
      await prefs.setBool(_premiumKey, true);
      print('無料トライアル情報を永続化しました');
    } catch (e) {
      print('無料トライアル情報の永続化エラー: $e');
    }
  }
  
  // トライアル期間の有効性をチェック
  Future<void> checkTrialStatus() async {
    print('トライアル期間の有効性をチェック中');
    if (_isInTrialPeriod && _trialEndDate != null) {
      final now = DateTime.now();
      if (now.isAfter(_trialEndDate!)) {
        print('トライアル期間が終了しました');
        await _endFreeTrial();
      } else {
        print('トライアル期間中です。残り${trialDaysRemaining}日');
      }
    }
  }
  
  // 無料トライアル終了処理
  Future<void> _endFreeTrial() async {
    print('無料トライアル期間を終了します');
    _isInTrialPeriod = false;
    
    // 有効なサブスクリプションがない場合はプレミアムステータスを無効化
    if (_activeSubscriptionId == null || !isSubscriptionValid()) {
      _isPremium = false;
    }
    
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isInTrialKey, false);
      if (!_isPremium) {
        await prefs.setBool(_premiumKey, false);
      }
      print('トライアル終了処理を完了しました');
    } catch (e) {
      print('トライアル終了処理エラー: $e');
    }
  }
  
  // トライアル情報を永続化
  Future<void> _saveTrialStatus(SharedPreferences prefs) async {
    if (_trialStartDate != null) {
      await prefs.setString(_trialStartKey, _trialStartDate!.toIso8601String());
    }
    if (_trialEndDate != null) {
      await prefs.setString(_trialEndKey, _trialEndDate!.toIso8601String());
    }
    await prefs.setBool(_isInTrialKey, _isInTrialPeriod);
    await prefs.setBool(_hasUsedTrialKey, _hasUsedTrial);
  }
  
  // トライアル情報を読み込み
  Future<void> _loadTrialStatus(SharedPreferences prefs) async {
    final trialStartString = prefs.getString(_trialStartKey);
    final trialEndString = prefs.getString(_trialEndKey);
    
    if (trialStartString != null) {
      _trialStartDate = DateTime.parse(trialStartString);
    }
    if (trialEndString != null) {
      _trialEndDate = DateTime.parse(trialEndString);
    }
    
    _isInTrialPeriod = prefs.getBool(_isInTrialKey) ?? false;
    _hasUsedTrial = prefs.getBool(_hasUsedTrialKey) ?? false;
    
    print('トライアル情報読み込み完了:');
    print('  _trialStartDate: $_trialStartDate');
    print('  _trialEndDate: $_trialEndDate');
    print('  _isInTrialPeriod: $_isInTrialPeriod');
    print('  _hasUsedTrial: $_hasUsedTrial');
    
    // トライアル期間の有効性をチェック
    if (_isInTrialPeriod) {
      await checkTrialStatus();
    }
  }
}
