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
    'monthly_sub',
    'yearly_sub'
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
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
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
                      ..._products.map((product) => Card(
                            child: ListTile(
                              title: Text(product.title),
                              subtitle: Text(product.description),
                              trailing: ElevatedButton(
                                onPressed: () => _buy(product),
                                child: Text(product.price),
                              ),
                            ),
                          )),
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
