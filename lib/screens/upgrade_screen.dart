import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
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
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _loading = true;
  bool _purchasePending = false;
  bool _restorePending = false;
  String? _error;
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
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // 購入情報の復元
  Future<void> _restorePurchases() async {
    setState(() {
      _restorePending = true;
      _error = null;
    });

    try {
      await _iap.restorePurchases();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('購入情報の復元が完了しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '購入情報の復元に失敗しました: $e';
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
      setState(() {
        _purchasePending = true;
      });
    } else {
      if (purchaseDetails.status == PurchaseStatus.error) {
        // エラー
        setState(() {
          _error = purchaseDetails.error?.message ?? '購入エラーが発生しました';
          _purchasePending = false;
        });
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // 購入成功または復元成功
        // プレミアム状態を更新
        final subscriptionProvider = context.read<SubscriptionProvider>();

        if (purchaseDetails.productID == 'yearly_sub') {
          // 年間プランの場合、トライアルを開始
          if (!subscriptionProvider.hasUsedTrial) {
            await subscriptionProvider.startFreeTrial();
          } else {
            // トライアル使用済みの場合は通常のサブスクリプションとして処理
            final expiryDate = DateTime.now().add(const Duration(days: 365));
            subscriptionProvider.setPremium(
              true,
              subscriptionId: purchaseDetails.productID,
              expiryDate: expiryDate,
            );
          }
        } else if (purchaseDetails.productID == 'monthly_sub' ||
            purchaseDetails.productID == 'monthly-sub') {
          // 月額プランの場合は通常のサブスクリプションとして処理
          final expiryDate = DateTime.now().add(const Duration(days: 30));
          subscriptionProvider.setPremium(
            true,
            subscriptionId: purchaseDetails.productID,
            expiryDate: expiryDate,
          );
        }

        setState(() {
          _activePlan = purchaseDetails.productID;
          _purchasePending = false;
          _error = null;
        });

        // 購入完了を通知
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('プレミアムプランにアップグレードしました！'),
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
        await _iap.completePurchase(purchaseDetails);
      }
    }
  }

  Future<void> _initStoreInfo() async {
    final bool isAvailable = await _iap.isAvailable();
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
        _error = '商品情報が取得できません。IAPの設定を確認してください。';
      });
      return;
    }
    setState(() {
      _purchasePending = true;
      _error = null;
    });

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

    try {
      if (product.id == 'monthly_sub' ||
          product.id == 'monthly-sub' ||
          product.id == 'yearly_sub') {
        // サブスクリプション商品 - buyConsumableを使用
        _iap.buyConsumable(purchaseParam: purchaseParam);
      } else {
        setState(() {
          _error = '無効なプランです';
          _purchasePending = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '購入処理中にエラーが発生しました: $e';
        _purchasePending = false;
      });
    }
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
      planName = 'テスト用 - 購入成功';
      planDescription = '開発環境用のテスト商品（購入成功）';
      planColor = Colors.green;
      features = ['テスト機能1', 'テスト機能2'];
    } else if (product.id == 'android.test.canceled') {
      planName = 'テスト用 - 購入キャンセル';
      planDescription = '開発環境用のテスト商品（購入キャンセル）';
      planColor = Colors.orange;
      features = ['テスト機能1', 'テスト機能2'];
    } else if (product.id == 'monthly_sub' || product.id == 'monthly-sub') {
      planName = '月額プラン';
      planDescription = '月額300円でプレミアム機能を利用';
      planColor = const Color(0xFFEC407A);
      features = ['無制限の編み目カウント', 'カスタム編み目設定', '広告なし'];
    } else if (product.id == 'yearly_sub') {
      isYearlyPlan = true;
      final subscriptionProvider = context.watch<SubscriptionProvider>();
      final canUseTrial = !subscriptionProvider.hasUsedTrial;

      planName = '年間プラン';
      if (canUseTrial) {
        planDescription = '年間3000円（月額250円相当）';
      } else {
        planDescription = '年間3000円でプレミアム機能を利用（月額250円相当）';
      }
      planColor = const Color(0xFF9C27B0);
      features = ['無制限の編み目カウント', 'カスタム編み目設定', '広告なし', 'オフライン利用可能'];
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
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.celebration,
                            color: Colors.white,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              '今だけ！\n3日間無料トライアル',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(
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
                        child: const Text(
                          'すべての機能を3日間無料でお試し！',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'いつでもキャンセル可能 • 自動更新前に通知',
                        style: TextStyle(
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
                            child: const Text(
                              'お得',
                              style: TextStyle(
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
                            const Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: Color(0xFF00C853),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'トライアル期間終了まで',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF00C853),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '3日間無料でお試し後、自動的に年間プラン（¥3,000/年）に移行します',
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
                              child: const Text(
                                '💡 トライアル期間中にキャンセルすれば課金されません',
                                style: TextStyle(
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
                              const Text(
                                '今だけ',
                                style: TextStyle(
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
                              const Text(
                                '最初の3日間',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ] else ...[
                              Text(
                                '価格',
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
                                  canUseTrial ? '無料で始める' : '購入',
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
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
                                  const Text(
                                    'プレミアムプラン',
                                    style: TextStyle(
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
                                                const Text(
                                                  '期間限定！',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 2,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                const Text(
                                                  '3日間\n無料トライアル',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
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
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.verified,
                                                        color:
                                                            Color(0xFF00C853),
                                                        size: 20,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'すべての機能が使い放題',
                                                        style: TextStyle(
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
                                                        'いつでも\nキャンセル可能'),
                                                    Container(
                                                      width: 1,
                                                      height: 40,
                                                      color: Colors.white
                                                          .withValues(alpha: 0.3),
                                                    ),
                                                    _buildBenefitItem(
                                                        Icons.notifications_off,
                                                        '自動更新前に\n通知'),
                                                    Container(
                                                      width: 1,
                                                      height: 40,
                                                      color: Colors.white
                                                          .withValues(alpha: 0.3),
                                                    ),
                                                    _buildBenefitItem(
                                                        Icons.credit_card_off,
                                                        '期間中は\n無料'),
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
                                      const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.android, color: Colors.white, size: 22),
                                          SizedBox(width: 8),
                                          Text(
                                            'Android限定キャンペーン',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'クーポンコード入力で今だけ無料！',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
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
                                        child: const Text(
                                          'クーポンコード：amimono',
                                          style: TextStyle(
                                            color: Color(0xFF1976D2),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '「プロモーションコード」画面で amimono を入力してお支払いください（無料になります）',
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
                                      'プレミアム機能を体験',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '編み物をより楽しく、より効率的に',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // 機能一覧
                                    _buildFeatureItem(
                                      '0xe3c9', // Icons.favorite
                                      '無制限の編み目カウント',
                                      '編み目の数を制限なく記録できます',
                                      isDarkMode: isDarkMode,
                                    ),
                                    _buildFeatureItem(
                                      '0xe3b7', // Icons.settings
                                      'カスタム編み目設定',
                                      '自分だけの編み目パターンを作成',
                                      isDarkMode: isDarkMode,
                                    ),
                                    _buildFeatureItem(
                                      '0xe3b0', // Icons.block
                                      '広告なし',
                                      '快適な編み物体験を提供',
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
                                            'サブスクリプション情報',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isDarkMode ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '• 月額プラン：300円/月（自動更新）\n'
                                            '• 年間プラン：3日間無料トライアル、その後3000円/年（自動更新、月額250円相当）\n'
                                            '• 無料トライアルは1回のみ利用可能です\n'
                                            '• トライアル期間終了24時間前までにキャンセルすれば課金されません\n'
                                            '• サブスクリプションはApp Storeの設定からキャンセルできます\n'
                                            '• キャンセルしない限り、自動的に更新されます\n'
                                            '• 購入履歴の復元が可能です\n'
                                            '• 利用規約とプライバシーポリシーへの機能的なリンクが提供されています',
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
                                        label: Text(
                                            _loading ? '確認中...' : '支払い状況を確認'),
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
                                            ? '復元中...'
                                            : '購入履歴を復元'),
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
                                          label: const Text('サブスクリプションをキャンセル'),
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
                                        '支払い状況の確認や購入履歴の復元ができます',
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
                                    const Text(
                                      '法的情報',
                                      style: TextStyle(
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
                                          child: const Text(
                                            '利用規約',
                                            style: TextStyle(
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
                                          child: const Text(
                                            'プライバシーポリシー',
                                            style: TextStyle(
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
                                          'ご利用中のプラン: $_activePlan',
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
              const SnackBar(
                content: Text('アクティブなサブスクリプションが見つかりました'),
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
            _error = status['error'] ?? '支払い状況の確認に失敗しました';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '支払い状況の確認中にエラーが発生しました: $e';
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
        title: const Text('サブスクリプションのキャンセル'),
        content: const Text('サブスクリプションをキャンセルすると、プレミアム機能が利用できなくなります。\n\n'
            '本当にキャンセルしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('キャンセルする'),
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
            const SnackBar(
              content: Text('サブスクリプションをキャンセルしました'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('キャンセル処理中にエラーが発生しました: $e'),
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
            _activePlan =
                '無料トライアル（残り${subscriptionProvider.trialDaysRemaining}日）';
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
