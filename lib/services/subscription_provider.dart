import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:logger/logger.dart';

class SubscriptionProvider extends ChangeNotifier {
  final Logger logger = Logger();
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

  bool get isPremium => _isPremium;

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
    } catch (e, stackTrace) {
      logger.e('SubscriptionProvider.setPremium: プレミアム状態の永続化エラー',
          error: e, stackTrace: stackTrace);
    }
  }

  // サブスクリプション状態の永続化・復元
  Future<void> loadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedPremium = prefs.getBool(_premiumKey);
      _isPremium = savedPremium ?? false;
      _activeSubscriptionId = prefs.getString(_subscriptionIdKey);
      final expiryString = prefs.getString(_expiryDateKey);

      // トライアル期間情報を読み込み
      await _loadTrialStatus(prefs);

      if (expiryString != null) {
        _subscriptionExpiryDate = DateTime.parse(expiryString);
      }

      // 有効期限をチェック
      await _checkSubscriptionValidity();

      notifyListeners();
    } catch (e, stackTrace) {
      logger.e('SubscriptionProvider.loadStatus: プレミアム状態の復元エラー',
          error: e, stackTrace: stackTrace);
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

      // トライアル期間もリセット(通常のサブスクリプション終了時)
      if (_isInTrialPeriod) {
        _isInTrialPeriod = false;
        _trialStartDate = null;
        _trialEndDate = null;
        await prefs.setBool(_isInTrialKey, false);
        await prefs.remove(_trialStartKey);
        await prefs.remove(_trialEndKey);
      }
    } catch (e, stackTrace) {
      logger.e(
          'SubscriptionProvider._cancelSubscription: サブスクリプションキャンセル時の永続化エラー',
          error: e,
          stackTrace: stackTrace);
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

  // 無料トライアルを開始（年間プランのみ）
  Future<void> startFreeTrial() async {
    final now = DateTime.now();
    _trialStartDate = now;
    _trialEndDate = now.add(const Duration(days: 3)); // 3日間の無料トライアル
    _isInTrialPeriod = true;
    _hasUsedTrial = true;
    _isPremium = true; // トライアル期間中はプレミアム機能を利用可能

    notifyListeners();

    // 永続化
    try {
      final prefs = await SharedPreferences.getInstance();
      await _saveTrialStatus(prefs);
      await prefs.setBool(_premiumKey, true);
    } catch (e, stackTrace) {
      logger.e('SubscriptionProvider.startFreeTrial: 無料トライアル情報の永続化エラー',
          error: e, stackTrace: stackTrace);
    }
  }

  // トライアル期間の有効性をチェック
  Future<void> checkTrialStatus() async {
    if (_isInTrialPeriod && _trialEndDate != null) {
      final now = DateTime.now();
      if (now.isAfter(_trialEndDate!)) {
        await _endFreeTrial();
      }
    }
  }

  // 無料トライアル終了処理
  Future<void> _endFreeTrial() async {
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
    } catch (e, stackTrace) {
      logger.e('SubscriptionProvider._endFreeTrial: トライアル終了処理エラー',
          error: e, stackTrace: stackTrace);
    }
  }

  // トライアル期間終了後の自動課金処理
  Future<void> handleTrialExpiration() async {
    if (!_isInTrialPeriod || _trialEndDate == null) {
      return;
    }

    final now = DateTime.now();
    if (now.isAfter(_trialEndDate!)) {
      try {
        // トライアル期間を終了
        await _endFreeTrial();

        // 年間サブスクリプションの自動課金を確認
        // 注意: 実際の課金処理はApp Store/Google Playの仕組みに依存します
        final paymentStatus = await checkPaymentStatus();

        if (paymentStatus['available'] != true ||
            paymentStatus['hasActiveSubscription'] != true) {
          // ユーザーに通知する必要がある場合は、ここでnotifyListeners()を呼び出します
          notifyListeners();
        }
      } catch (e, stackTrace) {
        logger.e(
            'SubscriptionProvider.handleTrialExpiration: トライアル終了処理中にエラーが発生しました',
            error: e,
            stackTrace: stackTrace);
        // エラーが発生した場合でも、トライアル期間は終了させる
        _isInTrialPeriod = false;
        _isPremium = false;
        notifyListeners();
      }
    }
  }

  // トライアル情報を永続化
  // 注意: 現在はSharedPreferences(デバイスローカル)に保存しています
  // 将来的な改善案:
  // - Firestore等のクラウドストレージに保存して複数デバイス対応
  // - ユーザーIDと紐付けてトライアル使用履歴を管理
  // - アプリ再インストール時のトライアル再利用を防ぐ
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

    // トライアル期間の有効性をチェック
    if (_isInTrialPeriod) {
      await checkTrialStatus();
    }
  }

  // デバッグ用：トライアル状態をリセット
  Future<void> resetTrialStatus() async {
    _hasUsedTrial = false;
    _isInTrialPeriod = false;
    _trialStartDate = null;
    _trialEndDate = null;

    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasUsedTrialKey, false);
      await prefs.setBool(_isInTrialKey, false);
      await prefs.remove(_trialStartKey);
      await prefs.remove(_trialEndKey);
    } catch (e, stackTrace) {
      logger.e('SubscriptionProvider.resetTrialStatus: トライアル状態のリセットエラー',
          error: e, stackTrace: stackTrace);
    }
  }
}
