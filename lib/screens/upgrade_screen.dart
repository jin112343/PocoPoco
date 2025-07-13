import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../services/subscription_provider.dart';
import 'home_screen.dart';

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

  static const List<String> _kProductIds = <String>[
    'monthly_sub', // 月額サブスクリプション
    'yearly_sub', // 年間サブスクリプション
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initStoreInfo();
    _listenToPurchaseUpdated();
    _restorePurchases();
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 購入情報の復元
  Future<void> _restorePurchases() async {
    setState(() {
      _restorePending = true;
      _error = null;
    });

    try {
      print('購入情報の復元を開始');
      await _iap.restorePurchases();
      print('購入情報の復元完了');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('購入情報の復元が完了しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('購入情報の復元エラー: $e');
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
    print('購入情報を受信: ${purchaseDetailsList.length}件');
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      print(
          '購入詳細: ${purchaseDetails.productID}, status: ${purchaseDetails.status}');
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
          print('購入成功: ${purchaseDetails.productID}');

          // 有効期限を計算
          DateTime? expiryDate;
          if (purchaseDetails.productID == 'monthly_sub') {
            expiryDate = DateTime.now().add(const Duration(days: 30));
          } else if (purchaseDetails.productID == 'yearly_sub') {
            expiryDate = DateTime.now().add(const Duration(days: 365));
          }

          // プレミアム状態を更新
          final subscriptionProvider = context.read<SubscriptionProvider>();
          subscriptionProvider.setPremium(
            true,
            subscriptionId: purchaseDetails.productID,
            expiryDate: expiryDate,
          );

          setState(() {
            _activePlan = purchaseDetails.productID;
            _purchasePending = false;
            _error = null;
          });

          // 購入完了を通知
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('プレミアムプランにアップグレードしました！'),
                backgroundColor: Colors.green,
              ),
            );

            // 少し待ってからホーム画面に戻り、UIを更新
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const HomeScreen(),
                ),
                (route) => false,
              );
            }
          }
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    });
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
    setState(() {
      _purchasePending = true;
      _error = null;
    });

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

    try {
      if (product.id == 'monthly_sub' || product.id == 'yearly_sub') {
        // サブスクリプション商品
        _iap.buyNonConsumable(purchaseParam: purchaseParam);
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

  Widget _buildFeatureItem(String icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEC407A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.check_circle,
              color: const Color(0xFFEC407A),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(ProductDetails product) {
    // プラン名を日本語で表示
    String planName = '';
    String planDescription = '';
    Color planColor = Colors.blue;
    List<String> features = [];

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
    } else if (product.id == 'monthly_sub') {
      planName = '月額プラン';
      planDescription = '月額300円でプレミアム機能を利用';
      planColor = const Color(0xFFEC407A);
      features = ['無制限の編み目カウント', 'カスタム編み目設定', '広告なし'];
    } else if (product.id == 'yearly_sub') {
      planName = '年間プラン';
      planDescription = '年間3000円でプレミアム機能を利用（月額250円相当）';
      planColor = const Color(0xFF9C27B0);
      features = ['無制限の編み目カウント', 'カスタム編み目設定', '広告なし'];
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: planColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: planColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
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
                    product.id == 'yearly_sub' ? Icons.star : Icons.favorite,
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
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        planDescription,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (product.id == 'yearly_sub' ||
                    product.id == 'android.test.purchased')
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
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
                    Text(
                      '価格',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
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
                ),
                ElevatedButton(
                  onPressed: _purchasePending ? null : () => _buy(product),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: planColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 4,
                  ),
                  child: _purchasePending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '購入',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEC407A),
              Color(0xFF9C27B0),
            ],
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
                              const SizedBox(height: 20),

                              // メインコンテンツ
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
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
                                    const Text(
                                      'プレミアム機能を体験',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '編み物をより楽しく、より効率的に',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // 機能一覧
                                    _buildFeatureItem(
                                      '0xe3c9', // Icons.favorite
                                      '無制限の編み目カウント',
                                      '編み目の数を制限なく記録できます',
                                    ),
                                    _buildFeatureItem(
                                      '0xe3b7', // Icons.settings
                                      'カスタム編み目設定',
                                      '自分だけの編み目パターンを作成',
                                    ),
                                    _buildFeatureItem(
                                      '0xe3b0', // Icons.block
                                      '広告なし',
                                      '快適な編み物体験を提供',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // プラン選択
                              ..._products
                                  .map((product) => _buildPlanCard(product)),

                              // 管理ボタン群
                              const SizedBox(height: 24),
                              Center(
                                child: Column(
                                  children: [
                                    // 支払い状況確認ボタン
                                    TextButton.icon(
                                      onPressed:
                                          _loading ? null : _checkPaymentStatus,
                                      icon: _loading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
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
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.restore),
                                      label: Text(
                                          _restorePending ? '復元中...' : '購入を復元'),
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
                                      '支払い状況の確認や購入の復元ができます',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                      textAlign: TextAlign.center,
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
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
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
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green.withOpacity(0.3),
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
}
