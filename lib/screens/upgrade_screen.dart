import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:easy_localization/easy_localization.dart';

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _loading = true;
  bool _purchasePending = false;
  String? _error;
  String? _activePlan;

  static const List<String> _kProductIds = <String>[
    'monthly_sub', // 月額300円
    'yearly_sub' // 年間3000円
  ];

  @override
  void initState() {
    super.initState();
    _initStoreInfo();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('upgrade')),
        backgroundColor: const Color(0xFFEC407A),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_isAvailable
              ? Center(child: Text(tr('premium_only_message')))
              : Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('premium_plan'),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Text(tr('premium_features'),
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 24),
                      ..._products.map((product) {
                        // プラン名を日本語で表示
                        String planName = '';
                        String planDescription = '';
                        Color planColor = Colors.blue;

                        if (product.id == 'monthly_sub') {
                          planName = '月額プラン';
                          planDescription = '月額300円でプレミアム機能を利用';
                          planColor = Colors.blue;
                        } else if (product.id == 'yearly_sub') {
                          planName = '年間プラン';
                          planDescription = '年間3000円でプレミアム機能を利用（月額250円相当）';
                          planColor = Colors.green;
                        }

                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      product.id == 'yearly_sub'
                                          ? Icons.star
                                          : Icons.favorite,
                                      color: planColor,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      planName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (product.id == 'yearly_sub')
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius:
                                              BorderRadius.circular(12),
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
                                const SizedBox(height: 8),
                                Text(
                                  planDescription,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      product.price,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.pink,
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: _purchasePending
                                          ? null
                                          : () => _buy(product),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: planColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                      ),
                                      child: _purchasePending
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white),
                                              ),
                                            )
                                          : const Text('購入'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      if (_activePlan != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text('ご利用中のプラン: $_activePlan',
                              style: const TextStyle(color: Colors.green)),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ),
    );
  }
}
