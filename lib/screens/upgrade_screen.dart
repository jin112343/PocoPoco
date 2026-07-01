import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../services/subscription_provider.dart';
import 'home_screen.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen>
    with TickerProviderStateMixin {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _loading = true;
  bool _purchasePending = false;
  bool _restorePending = false;
  String? _error;
  // 購入処理のタイムアウト用タイマー
  static const _purchaseTimeoutDuration = Duration(seconds: 60);
  String? _activePlan;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  /// ダイアログ表示のヘルパー
  void _showDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('ok')),
            ),
          ],
        ),
      );
    }
  }
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late ConfettiController _confettiController;

  static List<String> get _kProductIds {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return [
        'yearly_sub', // 年間サブスクリプション（iOS）
        'monthly_sub', // 月額サブスクリプション（iOS）
      ];
    }
    // Android 用のID
    return [
      'yearly_sub', // 年間サブスクリプション（Android）
      'monthly_sub', // 月額サブスクリプション（Android）
    ];
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initStoreInfo();
    _listenToPurchaseUpdated();
    _checkExistingSubscription();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();

    // パルスアニメーション（無料トライアルバナー用）
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);

    // Confettiコントローラー
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _cancelPurchaseTimeout();
    // 画面破棄後に購入イベントが届いてsetStateが呼ばれるのを防ぐ
    _purchaseSubscription?.cancel();
    _animationController.dispose();
    _pulseController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // 購入情報の復元
  Future<void> _restorePurchases() async {
    setState(() {
      _restorePending = true;
      _error = null;
    });

    _startPurchaseTimeout();

    try {
      // 復元結果は purchaseStream に PurchaseStatus.restored として届く
      // （restorePurchases()の完了は「リクエスト送信完了」にすぎない）
      await _iap.restorePurchases();
    } catch (e) {
      _cancelPurchaseTimeout();
      if (mounted) {
        setState(() {
          _error = tr('restore_failed', namedArgs: {'error': '$e'});
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _restorePending = false;
        });
      }
    }
  }

  void _listenToPurchaseUpdated() {
    _purchaseSubscription =
        _iap.purchaseStream.listen((List<PurchaseDetails> purchaseDetailsList) {
      _handlePurchaseUpdates(purchaseDetailsList);
    });
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      _processPurchaseDetails(purchaseDetails);
    }
  }

  Future<void> _processPurchaseDetails(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.status == PurchaseStatus.pending) {
      // 購入処理中
      if (mounted) {
        setState(() {
          _purchasePending = true;
        });
      }
    } else {
      // 購入処理完了（成功・エラー問わず）タイムアウトタイマーを解除
      _cancelPurchaseTimeout();

      if (purchaseDetails.status == PurchaseStatus.canceled) {
        // キャンセル
        if (mounted) {
          setState(() {
            _purchasePending = false;
            _restorePending = false;
            _error = null;
          });
        }
        return;
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // エラー
        if (mounted) {
          setState(() {
            _error = purchaseDetails.error?.message ?? tr('purchase_error');
            _purchasePending = false;
          });
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // 購入成功または復元成功
        // プレミアム状態を更新
        if (!mounted) return;
        final subscriptionProvider = context.read<SubscriptionProvider>();

        if (purchaseDetails.productID == 'yearly_sub') {
          // 年間プランの場合、トライアルを開始（使用済みならfalseが返る）
          bool trialStarted = false;
          if (!subscriptionProvider.hasUsedTrial) {
            trialStarted = await subscriptionProvider.startFreeTrial();
          }
          if (!trialStarted) {
            // トライアル使用済みの場合は通常のサブスクリプションとして処理
            final expiryDate = DateTime.now().add(const Duration(days: 365));
            await subscriptionProvider.setPremium(
              true,
              subscriptionId: purchaseDetails.productID,
              expiryDate: expiryDate,
            );
            // 課金が発生するのでconfettiを発射
            if (mounted) {
              _confettiController.play();
            }
          }
        } else if (purchaseDetails.productID == 'monthly_sub' ||
            purchaseDetails.productID == 'monthly-sub') {
          // 月額プランの場合は通常のサブスクリプションとして処理
          final expiryDate = DateTime.now().add(const Duration(days: 30));
          await subscriptionProvider.setPremium(
            true,
            subscriptionId: purchaseDetails.productID,
            expiryDate: expiryDate,
          );
          // 月額プランは課金が発生するのでconfettiを発射
          if (mounted) {
            _confettiController.play();
          }
        }

        if (!mounted) {
          // 画面が閉じられていても購入トランザクションは完了させる
          if (purchaseDetails.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchaseDetails);
            } catch (e) {
              debugPrint('completePurchase failed: $e');
            }
          }
          return;
        }

        setState(() {
          _activePlan = purchaseDetails.productID;
          _purchasePending = false;
          _restorePending = false;
          _error = null;
        });

        // 購入完了を通知
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('upgraded_to_premium')),
              backgroundColor: Colors.green,
            ),
          );

          // 新規購入の場合のみ画面を戻す（復元の場合は戻さない）
          if (purchaseDetails.status == PurchaseStatus.purchased) {
            // 少し待ってから前の画面に戻る
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              // 設定画面から来た場合は設定画面に戻る、それ以外はホーム画面に戻る
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const HomeScreen(),
                  ),
                  (route) => false,
                );
              }
            }
          }
        }
      }

      if (purchaseDetails.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchaseDetails);
        } catch (e) {
          // SubscriptionProvider側のリスナーが先に完了させた場合など
          debugPrint('completePurchase failed: $e');
        }
      }
    }
  }

  Future<void> _initStoreInfo() async {
    final bool isAvailable = await _iap.isAvailable();
    if (!mounted) return;
    if (!isAvailable) {
      setState(() {
        _isAvailable = false;
        _products = [];
        _loading = false;
      });
      return;
    }
    final ProductDetailsResponse response =
        await _iap.queryProductDetails(_kProductIds.toSet());
    if (!mounted) return;
    setState(() {
      _isAvailable = true;
      _products = response.productDetails;
      _loading = false;
    });
  }

  void _buy(ProductDetails product) {
    if (_purchasePending) return; // 二重購入防止
    if (product.id.isEmpty) {
      setState(() {
        _error = tr('product_info_unavailable');
      });
      return;
    }
    setState(() {
      _purchasePending = true;
      _error = null;
    });

    // タイムアウト処理：一定時間応答がなければ自動解除
    _startPurchaseTimeout();

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

    try {
      if (product.id == 'monthly_sub' ||
          product.id == 'monthly-sub' ||
          product.id == 'yearly_sub') {
        // サブスクリプション商品 - buyNonConsumableを使用
        // （buyConsumableだとAndroidで購入が消費されサブスクとして扱われない）
        _iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        _cancelPurchaseTimeout();
        setState(() {
          _error = tr('invalid_plan');
          _purchasePending = false;
        });
      }
    } catch (e) {
      _cancelPurchaseTimeout();
      setState(() {
        _error = tr('purchase_process_error', namedArgs: {'error': '$e'});
        _purchasePending = false;
      });
    }
  }

  Timer? _purchaseTimeoutTimer;

  void _startPurchaseTimeout() {
    _cancelPurchaseTimeout();
    _purchaseTimeoutTimer = Timer(_purchaseTimeoutDuration, () {
      if (mounted && (_purchasePending || _restorePending)) {
        setState(() {
          _purchasePending = false;
          _restorePending = false;
          _error = tr('purchase_timeout');
        });
      }
    });
  }

  void _cancelPurchaseTimeout() {
    _purchaseTimeoutTimer?.cancel();
    _purchaseTimeoutTimer = null;
  }

  Widget _buildFeatureItem(String icon, String title, String description, {bool isDarkMode = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEC407A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Color(0xFFEC407A),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(ProductDetails product, {bool isDarkMode = false}) {
    // プラン名を日本語で表示
    String planName = '';
    String planDescription = '';
    Color planColor = Colors.blue;
    List<String> features = [];
    bool isYearlyPlan = false;

    if (product.id == 'android.test.purchased') {
      planName = tr('test_purchase_success');
      planDescription = tr('test_purchase_success_desc');
      planColor = Colors.green;
      features = [tr('test_feature_1'), tr('test_feature_2')];
    } else if (product.id == 'android.test.canceled') {
      planName = tr('test_purchase_canceled');
      planDescription = tr('test_purchase_canceled_desc');
      planColor = Colors.orange;
      features = [tr('test_feature_1'), tr('test_feature_2')];
    } else if (product.id == 'monthly_sub' || product.id == 'monthly-sub') {
      planName = tr('monthly_plan');
      planDescription = tr('monthly_plan_desc');
      planColor = const Color(0xFFEC407A);
      features = [
        tr('feature_unlimited_count'),
        tr('feature_custom_stitches'),
        tr('feature_no_ads'),
      ];
    } else if (product.id == 'yearly_sub') {
      isYearlyPlan = true;
      final subscriptionProvider = context.watch<SubscriptionProvider>();
      final canUseTrial = !subscriptionProvider.hasUsedTrial;

      planName = tr('yearly_plan');
      if (canUseTrial) {
        planDescription = tr('yearly_plan_desc_trial');
      } else {
        planDescription = tr('yearly_plan_desc');
      }
      planColor = const Color(0xFF9C27B0);
      features = [
        tr('feature_unlimited_count'),
        tr('feature_custom_stitches'),
        tr('feature_no_ads'),
        tr('feature_offline'),
      ];
    }

    return Consumer<SubscriptionProvider>(
      builder: (context, provider, child) {
        final canUseTrial = !provider.hasUsedTrial && isYearlyPlan;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: canUseTrial
                  ? Colors.green.withValues(alpha: 0.5)
                  : planColor.withValues(alpha: 0.3),
              width: canUseTrial ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (canUseTrial ? Colors.green : planColor).withValues(alpha: 0.2),
                blurRadius: canUseTrial ? 20 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // 無料トライアル大バナー（年間プランでトライアル可能な場合のみ）
              if (canUseTrial)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF00E676), Color(0xFF00C853)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.celebration,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              tr('trial_banner_title'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.celebration,
                            color: Colors.white,
                            size: 28,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tr('trial_banner_subtitle'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('trial_banner_note'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: planColor,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Icon(
                            product.id == 'yearly_sub'
                                ? Icons.star
                                : Icons.favorite,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                planName,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                planDescription,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isYearlyPlan && !canUseTrial)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.orange, Colors.deepOrange],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tr('best_value'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),

                    // 無料トライアル期間の詳細（年間プランでトライアル可能な場合）
                    if (canUseTrial) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Color(0xFF00C853),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  tr('trial_period_info_title'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF00C853),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr('trial_period_info'),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tr('trial_cancel_note'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF00C853),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ...features.map((feature) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: planColor,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                feature,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (canUseTrial) ...[
                              Text(
                                tr('limited_time'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF00C853),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                '¥0',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00C853),
                                ),
                              ),
                              Text(
                                tr('first_3_days'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ] else ...[
                              Text(
                                tr('price'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              Text(
                                product.price,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: planColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (!_purchasePending && product.id.isNotEmpty)
                          ElevatedButton(
                            onPressed: () => _buy(product),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canUseTrial
                                  ? const Color(0xFF00C853)
                                  : planColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: canUseTrial ? 8 : 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (canUseTrial)
                                  const Icon(Icons.play_arrow, size: 20),
                                if (canUseTrial) const SizedBox(width: 4),
                                Text(
                                  canUseTrial ? tr('start_free') : tr('buy'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_purchasePending)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool get _isProcessing => _purchasePending || _restorePending;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_isProcessing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isProcessing) {
          _showDialog(tr('processing_wait'));
        }
      },
      child: Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDarkMode
                    ? [const Color(0xFF880E4F), const Color(0xFF4A148C)]
                    : [const Color(0xFFEC407A), const Color(0xFF9C27B0)],
              ),
            ),
            child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : !_isAvailable
                  ? Center(
                      child: Text(
                        tr('premium_only_message'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ヘッダー部分
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(
                                      Icons.arrow_back_ios,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    tr('premium_plan'),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 無料トライアルの大きな宣伝バナー（年間プラン未使用の場合）
                              Consumer<SubscriptionProvider>(
                                builder: (context, provider, child) {
                                  if (!provider.hasUsedTrial) {
                                    return Column(
                                      children: [
                                        ScaleTransition(
                                          scale: _pulseAnimation,
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF00E676),
                                                  Color(0xFF00C853),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.green
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              children: [
                                                // キラキラアイコン行
                                                const Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.star,
                                                        color: Colors.white,
                                                        size: 24),
                                                    SizedBox(width: 8),
                                                    Icon(Icons.celebration,
                                                        color: Colors.white,
                                                        size: 32),
                                                    SizedBox(width: 8),
                                                    Icon(Icons.star,
                                                        color: Colors.white,
                                                        size: 24),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                // メインメッセージ
                                                Text(
                                                  tr('limited_time_offer'),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 2,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  tr('free_trial_3days'),
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                    height: 1.2,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 20,
                                                    vertical: 10,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            25),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(alpha: 0.1),
                                                        blurRadius: 8,
                                                        offset:
                                                            const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.verified,
                                                        color:
                                                            Color(0xFF00C853),
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        tr('all_features_unlimited'),
                                                        style: const TextStyle(
                                                          color:
                                                              Color(0xFF00C853),
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                // 特典リスト
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  children: [
                                                    _buildBenefitItem(
                                                        Icons.check_circle,
                                                        tr('benefit_cancel_anytime')),
                                                    Container(
                                                      width: 1,
                                                      height: 40,
                                                      color: Colors.white
                                                          .withValues(alpha: 0.3),
                                                    ),
                                                    _buildBenefitItem(
                                                        Icons.notifications_off,
                                                        tr('benefit_notify_before_renewal')),
                                                    Container(
                                                      width: 1,
                                                      height: 40,
                                                      color: Colors.white
                                                          .withValues(alpha: 0.3),
                                                    ),
                                                    _buildBenefitItem(
                                                        Icons.credit_card_off,
                                                        tr('benefit_free_during_trial')),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                      ],
                                    );
                                  }
                                  return const SizedBox(height: 4);
                                },
                              ),

                              // Android限定クーポン告知バナー
                              if (defaultTargetPlatform == TargetPlatform.android)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 20),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1976D2).withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.android, color: Colors.white, size: 22),
                                          const SizedBox(width: 8),
                                          Text(
                                            tr('android_campaign_title'),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        tr('android_campaign_subtitle'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          tr('coupon_code_label'),
                                          style: const TextStyle(
                                            color: Color(0xFF1976D2),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        tr('coupon_instructions'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // メインコンテンツ
                              Container(
                                decoration: BoxDecoration(
                                  color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // タイトル
                                    Text(
                                      tr('experience_premium'),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      tr('premium_tagline'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // 機能一覧
                                    _buildFeatureItem(
                                      '0xe3c9', // Icons.favorite
                                      tr('feature_unlimited_count'),
                                      tr('feature_unlimited_count_desc'),
                                      isDarkMode: isDarkMode,
                                    ),
                                    _buildFeatureItem(
                                      '0xe3b7', // Icons.settings
                                      tr('feature_custom_stitches'),
                                      tr('feature_custom_stitches_desc'),
                                      isDarkMode: isDarkMode,
                                    ),
                                    _buildFeatureItem(
                                      '0xe3b0', // Icons.block
                                      tr('feature_no_ads'),
                                      tr('feature_no_ads_desc'),
                                      isDarkMode: isDarkMode,
                                    ),

                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isDarkMode ? const Color(0xFF3D3D3D) : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tr('subscription_info_title'),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isDarkMode ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            tr('subscription_info_body'),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // プラン選択（iOS/Android 共通）
                              ..._products
                                  .map((product) => _buildPlanCard(product, isDarkMode: isDarkMode)),

                              // 管理ボタン群（iOSのみ）
                              if (defaultTargetPlatform ==
                                  TargetPlatform.iOS) ...[
                                const SizedBox(height: 24),
                                Center(
                                  child: Column(
                                    children: [
                                      // 支払い状況確認ボタン
                                      TextButton.icon(
                                        onPressed: _loading
                                            ? null
                                            : _checkPaymentStatus,
                                        icon: _loading
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(Icons.payment),
                                        label: Text(_loading
                                            ? tr('checking')
                                            : tr('check_payment_status')),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // 購入復元ボタン
                                      TextButton.icon(
                                        onPressed: _restorePending
                                            ? null
                                            : _restorePurchases,
                                        icon: _restorePending
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(Icons.restore),
                                        label: Text(_restorePending
                                            ? tr('restoring')
                                            : tr('restore_purchases')),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // サブスクリプションキャンセルボタン（アクティブな場合のみ表示）
                                      if (_activePlan != null)
                                        TextButton.icon(
                                          onPressed: _cancelSubscription,
                                          icon: const Icon(Icons.cancel),
                                          label: Text(tr('cancel_subscription')),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red[300],
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 12,
                                            ),
                                          ),
                                        ),

                                      const SizedBox(height: 8),
                                      Text(
                                        tr('payment_management_note'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withValues(alpha: 0.8),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),
                              ],

                              // 利用規約とプライバシーポリシーのリンク
                              Container(
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      tr('legal_info'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const TermsScreen(),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            tr('terms'),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const PrivacyPolicyScreen(),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            tr('privacy'),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // エラーメッセージ
                              if (_error != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // アクティブプラン表示
                              if (_activePlan != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          tr('active_plan', namedArgs: {'plan': '$_activePlan'}),
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          // Confettiウィジェット（課金成功時に表示）
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.pink,
                Colors.purple,
                Colors.orange,
                Colors.yellow,
                Colors.green,
                Colors.blue,
              ],
              numberOfParticles: 30,
              maxBlastForce: 20,
              minBlastForce: 8,
              emissionFrequency: 0.05,
              gravity: 0.2,
            ),
          ),
          // 課金・復元処理中の全画面ローディングオーバーレイ
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC407A)),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _restorePending
                            ? tr('restoring_purchase_info')
                            : tr('purchase_processing'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('do_not_close_screen'),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  // 支払い状況を確認
  Future<void> _checkPaymentStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final subscriptionProvider = context.read<SubscriptionProvider>();
      final status = await subscriptionProvider.checkPaymentStatus();

      if (mounted) {
        if (status['available'] == true) {
          if (status['hasActiveSubscription'] == true) {
            setState(() {
              _activePlan = status['subscriptionId'];
              _loading = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(tr('active_subscription_found')),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            setState(() {
              _loading = false;
            });
          }
        } else {
          setState(() {
            _error = status['error'] ?? tr('payment_status_check_failed');
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = tr('payment_status_check_error', namedArgs: {'error': '$e'});
          _loading = false;
        });
      }
    }
  }

  // サブスクリプションをキャンセル
  Future<void> _cancelSubscription() async {
    final subscriptionProvider = context.read<SubscriptionProvider>();

    // 確認ダイアログを表示
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('cancel_subscription_title')),
        content: Text(tr('cancel_subscription_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(tr('do_cancel')),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      try {
        await subscriptionProvider.cancelSubscription();

        if (mounted) {
          setState(() {
            _activePlan = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('subscription_canceled')),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('cancel_process_error', namedArgs: {'error': '$e'})),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // 既存のサブスクリプションを確認
  Future<void> _checkExistingSubscription() async {
    try {
      final subscriptionProvider = context.read<SubscriptionProvider>();

      // トライアル期間の状態をチェック
      await subscriptionProvider.checkTrialStatus();

      // 現在のプレミアム状態を確認
      if (subscriptionProvider.isPremium) {
        if (subscriptionProvider.isInTrialPeriod) {
          setState(() {
            _activePlan = tr('free_trial_remaining', namedArgs: {
              'days': '${subscriptionProvider.trialDaysRemaining}'
            });
            _loading = false;
          });
        } else {
          setState(() {
            _activePlan =
                subscriptionProvider.activeSubscriptionId ?? 'unknown';
            _loading = false;
          });
        }
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }
}
