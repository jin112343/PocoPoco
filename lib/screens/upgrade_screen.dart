import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../services/subscription_provider.dart';
import '../widgets/cat_loading.dart';
import '../widgets/paywall_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _loading = true;
  bool _queryingStore = false;
  bool _purchasePending = false;
  bool _restorePending = false;
  // 復元リクエストのあと、実際に購入が見つかったか
  bool _restoredAnyPurchase = false;
  // 復元結果がストアから届くのを待つ時間
  static const _restoreResultWait = Duration(seconds: 3);
  String? _error;
  // 購入処理のタイムアウト用タイマー
  static const _purchaseTimeoutDuration = Duration(seconds: 60);
  int _operation = 0;
  bool _checkingStatus = false;
  // 「処理中」の表示を、利用者が自分で閉じられるようになるまでの時間。
  // ストアが応答しない時でも、この画面から出られなくなることがないようにする
  static const _processingEscapeDelay = Duration(seconds: 6);
  Timer? _processingEscapeTimer;
  bool _processingEscapable = false;
  // 購入完了の案内を、通知と購入シート後の確認の両方で二重に出さないための印
  bool _purchaseSuccessAnnounced = false;
  // 完了処理が済んでいない取引が残っている時にStoreKitプラグインが返すエラー
  static const _unfinishedTransactionErrorCode =
      'storekit_duplicate_product_object';

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
  }

  void _initAnimations() {
    // 表示時のアニメーションは各部品（paywall_widgets.dart）が自分で再生する。
    // Confettiコントローラー
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _operation++;
    _cancelPurchaseTimeout();
    // 画面破棄後に購入イベントが届いてsetStateが呼ばれるのを防ぐ
    _purchaseSubscription?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  void _showFailure(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restorePurchases() async {
    if (_isProcessing) return;
    final operation = ++_operation;
    final provider = context.read<SubscriptionProvider>();
    setState(() {
      _restorePending = true;
      _restoredAnyPurchase = false;
      _error = null;
    });
    _startPurchaseTimeout();
    try {
      if (provider.usesAppleEntitlements) {
        _restoredAnyPurchase =
            await provider.refreshAppleEntitlement(restore: true);
      } else {
        await _iap.restorePurchases().timeout(_purchaseTimeoutDuration);
        await Future<void>.delayed(_restoreResultWait);
      }
      if (!mounted || operation != _operation) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(_restoredAnyPurchase
              ? 'paywall_restore_complete'
              : 'restore_nothing_found'))));
    } catch (_) {
      if (mounted && operation == _operation) {
        _showFailure(tr('paywall_restore_error'));
      }
    } finally {
      if (mounted && operation == _operation) {
        _cancelPurchaseTimeout();
        setState(() => _restorePending = false);
      }
    }
  }

  void _listenToPurchaseUpdated() {
    _purchaseSubscription = _iap.purchaseStream.listen(
      (purchases) {
        for (final purchase in purchases) {
          unawaited(_processPurchaseDetails(purchase));
        }
      },
      onError: (Object error) {
        _operation++;
        _cancelPurchaseTimeout();
        if (!mounted) return;
        setState(() {
          _purchasePending = false;
          _restorePending = false;
        });
        _showFailure(tr('paywall_purchase_error'));
      },
    );
  }

  Future<void> _processPurchaseDetails(PurchaseDetails purchase) async {
    if (purchase.productID != SubscriptionProvider.yearlyProductId &&
        !SubscriptionProvider.monthlyProductIds.contains(purchase.productID)) {
      return;
    }
    if (!mounted) return;
    if (purchase.status == PurchaseStatus.pending) {
      // 承認待ち（保護者の承認・支払い方法の確認など）。結果は後から届いて
      // 自動で反映されるので、この画面は待たせない
      _operation++;
      _cancelPurchaseTimeout();
      setState(() => _purchasePending = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('paywall_purchase_waiting'))));
      return;
    }
    if (purchase.status == PurchaseStatus.canceled ||
        purchase.status == PurchaseStatus.error) {
      _operation++;
      _cancelPurchaseTimeout();
      setState(() {
        _purchasePending = false;
        _restorePending = false;
      });
      if (purchase.status == PurchaseStatus.error) {
        _showFailure(tr('paywall_purchase_error'));
      }
      return;
    }
    if (purchase.status != PurchaseStatus.purchased &&
        purchase.status != PurchaseStatus.restored) {
      return;
    }
    try {
      final active = await context
          .read<SubscriptionProvider>()
          .handleStorePurchase(purchase);
      if (!mounted) return;
      _restoredAnyPurchase = active;
      // 明示復元はリクエスト全体が終わるまで再操作を許可しない。
      if (!_restorePending) _cancelPurchaseTimeout();
      setState(() {
        _purchasePending = false;
        _error = null;
      });
      if (!active) {
        _showFailure(tr('paywall_verification_pending'));
      } else if (purchase.status == PurchaseStatus.purchased) {
        _announcePurchaseSuccess();
      }
    } catch (_) {
      if (!mounted) return;
      if (!_restorePending) _cancelPurchaseTimeout();
      setState(() => _purchasePending = false);
      _showFailure(tr('paywall_verification_pending'));
    }
  }

  Future<void> _initStoreInfo() async {
    if (!mounted || _queryingStore) return;
    _queryingStore = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await (() async {
        if (!await _iap.isAvailable()) return null;
        return await _iap.queryProductDetails(_kProductIds.toSet());
      })()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _isAvailable = response != null && response.error == null;
        // StoreKit returns List<AppStoreProduct2Details>. Keep each native
        // product, but normalize the list type so firstWhere(orElse:) accepts
        // a ProductDetails callback when the plans are rendered.
        _products = _isAvailable
            ? List<ProductDetails>.of(response!.productDetails)
            : <ProductDetails>[];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAvailable = false;
        _products = [];
      });
    } finally {
      _queryingStore = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  void _announcePurchaseSuccess() {
    if (!mounted || _purchaseSuccessAnnounced) return;
    _purchaseSuccessAnnounced = true;
    if (!MediaQuery.disableAnimationsOf(context)) {
      _confettiController.play();
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('upgraded_to_premium'))));
  }

  /// 購入に失敗した時の案内。原因を調べられるよう、ストアのエラーコードを添える
  String _purchaseErrorMessage(Object error) {
    final message = tr('paywall_purchase_error');
    return error is PlatformException ? '$message (${error.code})' : message;
  }

  Future<bool> _requestPurchase(ProductDetails product) => _iap
      .buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product))
      .timeout(_purchaseTimeoutDuration);

  Future<void> _buy(ProductDetails product) async {
    final provider = context.read<SubscriptionProvider>();
    if (_isProcessing || _loading || !_isAvailable || provider.isPremium) {
      return;
    }
    if (!_kProductIds.contains(product.id)) return;
    final operation = ++_operation;
    _purchaseSuccessAnnounced = false;
    setState(() {
      _purchasePending = true;
      _error = null;
    });
    _startPurchaseTimeout();
    try {
      bool started;
      try {
        started = await _requestPurchase(product);
      } on PlatformException catch (error) {
        if (error.code != _unfinishedTransactionErrorCode ||
            !provider.usesAppleEntitlements) {
          rethrow;
        }
        // 完了処理が済んでいない取引が残っていると、同じ商品を購入できない。
        // ストアの利用権を反映して取引を完了させてから、もう一度だけ購入を試みる
        final active = await provider.refreshAppleEntitlement();
        await provider.finishUnfinishedAppleTransactions();
        if (!mounted || operation != _operation) return;
        if (active) {
          // 残っていた取引が有効な契約だった（すでに購入できている）
          _cancelPurchaseTimeout();
          setState(() => _purchasePending = false);
          _announcePurchaseSuccess();
          return;
        }
        started = await _requestPurchase(product);
      }
      if (!mounted || operation != _operation) return;
      if (!started) {
        _cancelPurchaseTimeout();
        setState(() => _purchasePending = false);
        _showFailure(tr('paywall_purchase_error'));
        return;
      }
      if (provider.usesAppleEntitlements) {
        await _settleApplePurchase(operation);
      }
    } catch (error) {
      provider.logger.w('購入を開始できませんでした: $error');
      if (!mounted || operation != _operation) return;
      _cancelPurchaseTimeout();
      setState(() => _purchasePending = false);
      _showFailure(_purchaseErrorMessage(error));
    }
  }

  /// iOS: 購入シートが閉じたあとの後始末。
  ///
  /// StoreKit 2 では、購入の呼び出しは購入シートが閉じてから戻る。購入できていれば
  /// 通知（purchaseStream）でも反映されるが、キャンセルや承認待ちでは通知が
  /// 届かないことがある。ストアが検証した利用権を確認して、待機を必ず終える。
  Future<void> _settleApplePurchase(int operation) async {
    final provider = context.read<SubscriptionProvider>();
    var active = false;
    try {
      active = await provider.refreshAppleEntitlement();
    } catch (error) {
      provider.logger.w('購入後の利用権の確認に失敗しました: $error');
    }
    if (!mounted || operation != _operation || !_purchasePending) return;
    _cancelPurchaseTimeout();
    setState(() => _purchasePending = false);
    if (active) _announcePurchaseSuccess();
  }

  /// 「処理中」の表示を利用者が閉じる。
  ///
  /// 進行中の購入や復元を取り消すものではない。あとから結果が届いた場合は、
  /// 通知（purchaseStream）や次回起動時の確認で反映される。
  void _dismissProcessing() {
    _operation++;
    _cancelPurchaseTimeout();
    if (!mounted) return;
    setState(() {
      _purchasePending = false;
      _restorePending = false;
      _checkingStatus = false;
    });
  }

  Timer? _purchaseTimeoutTimer;
  void _startPurchaseTimeout() {
    _cancelPurchaseTimeout();
    _purchaseTimeoutTimer = Timer(_purchaseTimeoutDuration, () {
      if (!mounted || !_isProcessing) return;
      _operation++;
      _cancelPurchaseTimeout();
      setState(() {
        _purchasePending = false;
        _restorePending = false;
        _checkingStatus = false;
      });
      _showFailure(tr('purchase_timeout'));
    });
    // 少し待っても終わらなければ、利用者が自分で閉じられるようにする
    _processingEscapeTimer = Timer(_processingEscapeDelay, () {
      if (!mounted || !_isProcessing) return;
      setState(() => _processingEscapable = true);
    });
  }

  void _cancelPurchaseTimeout() {
    _purchaseTimeoutTimer?.cancel();
    _purchaseTimeoutTimer = null;
    _processingEscapeTimer?.cancel();
    _processingEscapeTimer = null;
    _processingEscapable = false;
  }

  bool get _isProcessing =>
      _purchasePending || _restorePending || _checkingStatus;
  String? _selectedPlanId;

  PaywallPalette get _palette => PaywallPalette.of(context);

  List<ProductDetails> get _plans {
    final plans = _products
        .where((p) =>
            p.id == 'yearly_sub' ||
            p.id == 'monthly_sub' ||
            p.id == 'monthly-sub')
        .toList();
    plans.sort((a, b) =>
        (a.id == 'yearly_sub' ? 0 : 1).compareTo(b.id == 'yearly_sub' ? 0 : 1));
    return plans;
  }

  ProductDetails? get _selectedProduct {
    final plans = _plans;
    if (plans.isEmpty) return null;
    final provider = context.read<SubscriptionProvider>();
    final selectedId =
        provider.isPremium ? provider.activeSubscriptionId : _selectedPlanId;
    return plans.firstWhere(
        (p) =>
            p.id == selectedId ||
            selectedId == 'monthly-sub' && p.id == 'monthly_sub',
        orElse: () => plans.first);
  }

  String _planName(String id) =>
      tr(id == 'yearly_sub' ? 'yearly_plan' : 'monthly_plan');

  String _monthlyEquivalent(ProductDetails product) {
    final formatter = NumberFormat.simpleCurrency(
        locale: context.locale.toString(), name: product.currencyCode);
    return formatter.format(product.rawPrice / 12);
  }

  int? _yearlySaving(ProductDetails yearly) {
    final monthly = _plans.where((p) => p.id != 'yearly_sub');
    if (monthly.isEmpty ||
        yearly.currencyCode != monthly.first.currencyCode ||
        monthly.first.rawPrice <= 0 ||
        yearly.rawPrice <= 0) {
      return null;
    }
    final saving =
        ((1 - yearly.rawPrice / (monthly.first.rawPrice * 12)) * 100).floor();
    return saving > 0 ? saving : null;
  }

  Widget _note(IconData icon, String message, {bool error = false}) {
    final p = _palette;
    final color = error ? p.danger : p.accent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: error ? color.withValues(alpha: 0.1) : p.tint,
          borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style: TextStyle(
                    color: error ? color : p.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.6))),
      ]),
    );
  }

  /// 画面に入った時に、下からふわっと現れるようにする
  Widget _reveal(String id, Widget child, {int delayMs = 0}) => PaywallReveal(
        key: ValueKey('paywall_reveal_$id'),
        delay: Duration(milliseconds: delayMs),
        builder: (context, progress) =>
            PaywallEntrance(animation: progress, child: child),
      );

  // 大きな文字（見出し・価格）に適用する、文字サイズ設定の上限
  static const double _headlineMaxScale = 1.35;
  static const double _priceMaxScale = 1.6;

  Widget _buildHeadline() {
    final p = _palette;
    return Column(
      children: [
        Text(tr('paywall_title'),
            textAlign: TextAlign.center,
            // 元から大きい文字なので、拡大は控えめにして途中で折り返さないようにする
            textScaler: MediaQuery.textScalerOf(context)
                .clamp(maxScaleFactor: _headlineMaxScale),
            style: TextStyle(
                color: p.ink,
                fontSize: 25,
                fontWeight: FontWeight.w800,
                height: 1.35)),
        const SizedBox(height: 8),
        Text(tr('paywall_subtitle'),
            textAlign: TextAlign.center,
            style: TextStyle(color: p.muted, fontSize: 13.5, height: 1.6)),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    final p = _palette;
    return Row(
      children: [
        Container(
          width: 5,
          height: 18,
          decoration: BoxDecoration(
              color: p.accent, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 9),
        Expanded(
            child: Text(title,
                style: TextStyle(
                    color: p.ink,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    height: 1.35))),
      ],
    );
  }

  /// 特典の一覧。カードは現れたあとにイラストが一度だけ動く
  Widget _buildBenefits() {
    final p = _palette;
    final freeLabel = tr('paywall_free_label');
    // イラスト・見出し・説明・無料での状態・プレミアムでの状態
    final benefits = <(
      Widget Function(Animation<double> progress),
      String,
      String,
      String,
      String
    )>[
      (
        (progress) =>
            PaywallProjectsIllustration(palette: p, progress: progress),
        tr('feature_unlimited_count'),
        tr('paywall_projects_desc'),
        tr('paywall_free_projects'),
        tr('paywall_premium_projects'),
      ),
      (
        (progress) =>
            PaywallStitchesIllustration(palette: p, progress: progress),
        tr('feature_custom_stitches'),
        tr('paywall_stitches_desc'),
        tr('paywall_free_stitches'),
        tr('paywall_premium_stitches'),
      ),
      (
        (progress) => PaywallNoAdsIllustration(palette: p, progress: progress),
        tr('feature_no_ads'),
        tr('paywall_no_ads_desc'),
        tr('paywall_free_ads'),
        tr('paywall_premium_ads'),
      ),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      // カードごとに折り返しが違うと不揃いに見えるので、
      // 「無料 → プレミアム」を1行に並べるかどうかは全カードで揃える
      final compareOnOneLine = PaywallBenefitCard.fitsCompareOnOneLine(
        context,
        cardWidth: constraints.maxWidth,
        freeLabel: freeLabel,
        values: [for (final benefit in benefits) (benefit.$4, benefit.$5)],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, benefit) in benefits.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PaywallReveal(
                key: ValueKey('paywall_reveal_benefit_$index'),
                delay: Duration(milliseconds: 260 + 110 * index),
                duration: const Duration(milliseconds: 1500),
                builder: (context, progress) => PaywallEntrance(
                  animation: progress,
                  length: 0.32,
                  child: PaywallBenefitCard(
                    palette: p,
                    illustration: benefit.$1(paywallInterval(
                        progress, 0.22, 0.78,
                        curve: Curves.linear)),
                    title: benefit.$2,
                    description: benefit.$3,
                    freeLabel: freeLabel,
                    freeValue: benefit.$4,
                    premiumValue: benefit.$5,
                    compareOnOneLine: compareOnOneLine,
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildPlanCard(ProductDetails product, SubscriptionProvider provider) {
    final p = _palette;
    final yearly = product.id == 'yearly_sub';
    final selected = _selectedProduct?.id == product.id;
    final saving = yearly ? _yearlySaving(product) : null;
    // 「{price} / 年」の価格だけを大きく見せるため、前後の文言に分ける
    const pricePlaceholder = '\u0000';
    final priceParts = tr(yearly ? 'paywall_year_price' : 'paywall_month_price',
        namedArgs: {'price': pricePlaceholder}).split(pricePlaceholder);
    final unitStyle = TextStyle(
        color: p.muted, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3);
    final bannerColor = selected ? p.onAccent : p.accent;
    final bannerStyle = TextStyle(
        color: bannerColor,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        height: 1.35);
    const duration = Duration(milliseconds: 220);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        button: true,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: selected ? p.tint : p.surface,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: selected ? p.accent : p.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: p.accent.withValues(alpha: selected ? 0.16 : 0),
                  blurRadius: 18,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: ValueKey('plan_${product.id}'),
              splashColor: p.accent.withValues(alpha: 0.10),
              highlightColor: p.accent.withValues(alpha: 0.06),
              onTap: _isProcessing || provider.isPremium
                  ? null
                  : () {
                      setState(() => _selectedPlanId = product.id);
                    },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 月額より安い時だけ「おすすめ」と割引率を帯で示す
                  if (saving != null)
                    AnimatedContainer(
                      duration: duration,
                      color: selected ? p.accent : p.tint,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 2,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.star_rounded,
                                size: paywallIconSize(context, 15),
                                color: bannerColor),
                            const SizedBox(width: 4),
                            Flexible(
                                child: Text(tr('paywall_recommended'),
                                    style: bannerStyle)),
                          ]),
                          Text(
                              tr('paywall_saving',
                                  namedArgs: {'percent': '$saving'}),
                              style: bannerStyle),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                    child: Row(children: [
                      PaywallSelectionMark(palette: p, selected: selected),
                      const SizedBox(width: 13),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_planName(product.id),
                              style: TextStyle(
                                  color: p.ink,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  height: 1.35)),
                          const SizedBox(height: 2),
                          Text.rich(
                              textScaler: MediaQuery.textScalerOf(context)
                                  .clamp(maxScaleFactor: _priceMaxScale),
                              TextSpan(children: [
                                if (priceParts.first.isNotEmpty)
                                  TextSpan(
                                      text: priceParts.first, style: unitStyle),
                                TextSpan(
                                    text: product.price,
                                    style: TextStyle(
                                        color: p.ink,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 24,
                                        height: 1.3)),
                                if (priceParts.length > 1 &&
                                    priceParts.last.isNotEmpty)
                                  TextSpan(
                                      text: priceParts.last, style: unitStyle),
                              ])),
                          const SizedBox(height: 3),
                          Text(
                              yearly
                                  ? tr('paywall_month_equivalent', namedArgs: {
                                      'price': _monthlyEquivalent(product)
                                    })
                                  : tr('paywall_monthly_note'),
                              style: TextStyle(
                                  color: p.muted, fontSize: 12, height: 1.5)),
                        ],
                      )),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legalLinks() => Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        children: [
          TextButton(
              key: const ValueKey('restore_purchases_button'),
              onPressed: _isProcessing ? null : _restorePurchases,
              child: Text(tr('restore_purchases'))),
          TextButton(
              onPressed: _isProcessing
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TermsScreen())),
              child: Text(tr('terms'))),
          TextButton(
              onPressed: _isProcessing
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen())),
              child: Text(tr('privacy'))),
        ],
      );

  /// 請求額・購入ボタン・復元や規約へのリンク。
  /// [inline] は画面下に固定せず、スクロールする内容の最後に置く場合
  Widget _buildPurchaseBar(SubscriptionProvider provider,
      {bool inline = false}) {
    final p = _palette;
    final product = _selectedProduct;
    final canBuy = product != null &&
        _isAvailable &&
        !_loading &&
        !_isProcessing &&
        !provider.isPremium;
    final label = provider.isPremium
        ? tr('paywall_already_premium')
        : product != null
            ? tr('paywall_continue_plan',
                namedArgs: {'plan': _planName(product.id)})
            : tr('paywall_choose_plan');
    final radius = BorderRadius.circular(18);
    final billingStyle = TextStyle(color: p.muted, fontSize: 11.5, height: 1.5);
    final bar = SafeArea(
      top: false,
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding:
                EdgeInsets.fromLTRB(inline ? 0 : 20, 12, inline ? 0 : 20, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading) ...[
                  Text(tr('loading'),
                      textAlign: TextAlign.center, style: billingStyle),
                  const SizedBox(height: 9),
                ] else if (_storeFailed && !inline) ...[
                  // 画面下に固定している時は、スクロールしなくても原因と再試行が見えるようにする
                  Row(children: [
                    Icon(Icons.wifi_off_rounded, size: 18, color: p.accent),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(tr('paywall_store_unavailable'),
                            style: TextStyle(
                                color: p.ink, fontSize: 11.5, height: 1.45))),
                    const SizedBox(width: 4),
                    _buildRetryButton(),
                  ]),
                  const SizedBox(height: 4),
                ] else if (product != null && !provider.isPremium) ...[
                  Text(
                      tr(
                          product.id == 'yearly_sub'
                              ? 'paywall_year_billing'
                              : 'paywall_month_billing',
                          namedArgs: {'price': product.price}),
                      textAlign: TextAlign.center,
                      style: billingStyle),
                  const SizedBox(height: 9),
                ],
                PaywallShine(
                  borderRadius: radius,
                  enabled: canBuy,
                  trigger: product?.id,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: canBuy
                          ? LinearGradient(colors: [p.accentStart, p.accentEnd])
                          : null,
                      color: canBuy
                          ? null
                          : provider.isPremium
                              ? p.tint
                              : p.border,
                      boxShadow: [
                        BoxShadow(
                            color:
                                p.accent.withValues(alpha: canBuy ? 0.28 : 0),
                            blurRadius: 16,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: FilledButton(
                        key: const ValueKey('purchase_selected_plan'),
                        onPressed: canBuy ? () => _buy(product) : null,
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: p.onAccent,
                            disabledForegroundColor:
                                provider.isPremium ? p.accent : p.muted,
                            minimumSize: const Size.fromHeight(54),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: radius),
                            textStyle: TextStyle(
                                fontFamily: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.fontFamily,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (provider.isPremium) ...[
                              const Icon(Icons.check_circle_rounded, size: 19),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                                child:
                                    Text(label, textAlign: TextAlign.center)),
                          ],
                        )),
                  ),
                ),
                const SizedBox(height: 2),
                _legalLinks(),
              ],
            ),
          ),
        ),
      ),
    );
    if (inline) return bar;
    return DecoratedBox(
      decoration: BoxDecoration(
          color: p.surface, border: Border(top: BorderSide(color: p.border))),
      child: bar,
    );
  }

  /// ストアから料金を取得できなかった状態か（読み込み中は含まない）
  bool get _storeFailed => !_loading && (!_isAvailable || _plans.isEmpty);

  Widget _buildRetryButton() {
    final p = _palette;
    return TextButton.icon(
        key: const ValueKey('retry_store_button'),
        onPressed: _isProcessing ? null : _initStoreInfo,
        style: TextButton.styleFrom(
            foregroundColor: p.accent,
            textStyle: TextStyle(
                fontFamily: Theme.of(context).textTheme.labelLarge?.fontFamily,
                fontSize: 13.5,
                fontWeight: FontWeight.w700)),
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: Text(tr('retry')));
  }

  /// プランの読み込み中・読み込み失敗・プラン一覧のいずれか。
  /// [showRetry] がfalseの時は、再試行ボタンを画面下の購入バーに出す
  List<Widget> _buildPlans(SubscriptionProvider provider,
      {required bool showRetry}) {
    final p = _palette;
    if (_loading) return [PaywallPlanSkeleton(palette: p)];
    final plans = _plans;
    if (_storeFailed) {
      return [
        _note(Icons.wifi_off_rounded, tr('paywall_store_unavailable')),
        if (showRetry) ...[
          const SizedBox(height: 4),
          Center(child: _buildRetryButton()),
        ] else
          const SizedBox(height: 10),
      ];
    }
    return [
      for (var i = 0; i < plans.length; i++)
        _reveal('plan_${plans[i].id}', _buildPlanCard(plans[i], provider),
            delayMs: 90 * i),
    ];
  }

  Widget _buildDataSafetyNote() {
    final p = _palette;
    return Container(
      key: const ValueKey('data_safety_note'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: p.tint, shape: BoxShape.circle),
              child:
                  Icon(Icons.verified_user_rounded, size: 17, color: p.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(tr('data_safety_title'),
                    style: TextStyle(
                        color: p.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.4))),
          ]),
          const SizedBox(height: 9),
          Text(tr('paywall_data_note'),
              style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.6)),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Material(
                type: MaterialType.transparency,
                child: ExpansionTile(
                  key: const ValueKey('data_safety_details'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  dense: true,
                  iconColor: p.muted,
                  collapsedIconColor: p.muted,
                  title: Text(tr('paywall_more_details'),
                      style: TextStyle(color: p.muted, fontSize: 12)),
                  children: [
                    Text(tr('data_safety_body'),
                        style: TextStyle(
                            color: p.muted, fontSize: 12, height: 1.7))
                  ],
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(SubscriptionProvider provider,
      {bool inlinePurchase = false}) {
    final p = _palette;
    final finePrint = TextStyle(color: p.muted, fontSize: 11, height: 1.7);
    return SingleChildScrollView(
      key: const ValueKey('paywall_scroll'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 476),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _reveal('hero', PaywallHero(palette: p)),
              const SizedBox(height: 18),
              _reveal('headline', _buildHeadline(), delayMs: 90),
              if (provider.isPremium) ...[
                const SizedBox(height: 14),
                _note(
                    Icons.check_circle_outline_rounded,
                    tr('active_plan', namedArgs: {
                      'plan': provider.activeSubscriptionId == 'yearly_sub'
                          ? tr('yearly_plan')
                          : SubscriptionProvider.monthlyProductIds
                                  .contains(provider.activeSubscriptionId)
                              ? tr('monthly_plan')
                              : tr('premium_plan')
                    })),
              ],
              const SizedBox(height: 24),
              _reveal(
                  'benefits_title', _sectionTitle(tr('paywall_benefits_title')),
                  delayMs: 180),
              const SizedBox(height: 11),
              _buildBenefits(),
              const SizedBox(height: 16),
              _reveal(
                  'plans_title',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionTitle(tr('paywall_choose_plan')),
                      const SizedBox(height: 5),
                      Text(tr('paywall_same_features'),
                          style: TextStyle(
                              color: p.muted, fontSize: 12.5, height: 1.5)),
                    ],
                  ),
                  delayMs: 590),
              const SizedBox(height: 12),
              ..._buildPlans(provider, showRetry: inlinePurchase),
              if (_error != null) ...[
                const SizedBox(height: 2),
                Semantics(
                    liveRegion: true,
                    child: _note(Icons.error_outline_rounded, _error!,
                        error: true)),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              _buildDataSafetyNote(),
              const SizedBox(height: 14),
              Text(tr('restore_note'),
                  textAlign: TextAlign.center, style: finePrint),
              if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                const SizedBox(height: 6),
                Center(
                    child: TextButton(
                        onPressed: _isProcessing || _loading
                            ? null
                            : _checkPaymentStatus,
                        child: Text(tr('check_payment_status')))),
                if (provider.isPremium)
                  Center(
                      child: TextButton(
                          onPressed: _isProcessing ? null : _manageSubscription,
                          child: Text(tr('paywall_manage_subscription')))),
              ],
              const SizedBox(height: 8),
              Text(tr('paywall_renewal_note'),
                  textAlign: TextAlign.center, style: finePrint),
              if (inlinePurchase) ...[
                const SizedBox(height: 16),
                _buildPurchaseBar(provider, inline: true)
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();
    final p = _palette;
    final localTheme = Theme.of(context).copyWith(
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: p.muted,
                textStyle: TextStyle(
                    fontFamily:
                        Theme.of(context).textTheme.labelLarge?.fontFamily,
                    fontSize: 11.5))),
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: p.accent));
    return LayoutBuilder(builder: (context, constraints) {
      final inlinePurchase = constraints.maxHeight < 700 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.5;
      return Theme(
        data: localTheme,
        child: PopScope(
          canPop: !_isProcessing,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && _isProcessing) _showDialog(tr('processing_wait'));
          },
          child: Scaffold(
            backgroundColor: p.background,
            appBar: AppBar(
                backgroundColor: p.background,
                surfaceTintColor: Colors.transparent,
                foregroundColor: p.ink,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                    key: const ValueKey('close_paywall_button'),
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, size: 22)),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 15, color: p.accent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('Poco Premium',
                          style: TextStyle(
                              fontSize: 14,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w700,
                              color: p.accent)),
                    ),
                  ],
                )),
            bottomNavigationBar:
                inlinePurchase ? null : _buildPurchaseBar(provider),
            body: Stack(children: [
              _buildContent(provider, inlinePurchase: inlinePurchase),
              IgnorePointer(
                  child: Align(
                      alignment: Alignment.topCenter,
                      child: ConfettiWidget(
                          confettiController: _confettiController,
                          blastDirectionality: BlastDirectionality.explosive,
                          shouldLoop: false,
                          colors: const [
                            Color(0xFFEC407A),
                            Color(0xFFF7922D),
                            Color(0xFFFFD166),
                            Color(0xFF7CB342)
                          ],
                          numberOfParticles: 16,
                          maxBlastForce: 16,
                          minBlastForce: 6,
                          emissionFrequency: 0.05,
                          gravity: 0.2))),
              if (_isProcessing)
                Positioned.fill(
                  // 下の内容には触れられないようにしつつ（ColoredBoxが操作を受け止める）、
                  // この表示の中の「閉じる」は押せるようにする
                  child: ColoredBox(
                    color: p.background.withValues(alpha: 0.97),
                    child: Center(
                        child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        // 処理が終わるとこの表示ごと外れて、アニメーションも止まる
                        const CatLoadingIndicator(size: 150),
                        const SizedBox(height: 20),
                        Text(
                            _restorePending
                                ? tr('restoring_purchase_info')
                                : tr('purchase_processing'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: p.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        if (!_processingEscapable)
                          Text(tr('do_not_close_screen'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: p.muted, fontSize: 12))
                        else ...[
                          // しばらく待っても終わらない時は、ここから必ず抜けられる
                          Text(tr('paywall_processing_hint'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: p.muted, fontSize: 12.5, height: 1.6)),
                          const SizedBox(height: 14),
                          OutlinedButton(
                              key: const ValueKey('dismiss_processing_button'),
                              onPressed: _dismissProcessing,
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: p.accent,
                                  side: BorderSide(color: p.accent),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 28, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  textStyle: TextStyle(
                                      fontFamily: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.fontFamily,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              child: Text(tr('paywall_processing_dismiss'))),
                        ],
                      ]),
                    )),
                  ),
                ),
            ]),
          ),
        ),
      );
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (_isProcessing) return;
    final operation = ++_operation;
    setState(() {
      _checkingStatus = true;
      _error = null;
    });
    _startPurchaseTimeout();
    try {
      final status = await context
          .read<SubscriptionProvider>()
          .checkPaymentStatus()
          .timeout(const Duration(seconds: 15));
      if (!mounted || operation != _operation) return;
      if (status['available'] != true) {
        _showFailure(tr('payment_status_check_failed'));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(status['hasActiveSubscription'] == true
                ? 'active_subscription_found'
                : 'restore_nothing_found'))));
      }
    } catch (_) {
      if (mounted && operation == _operation) {
        _showFailure(tr('payment_status_check_failed'));
      }
    } finally {
      if (mounted && operation == _operation) {
        _cancelPurchaseTimeout();
        setState(() => _checkingStatus = false);
      }
    }
  }

  Future<void> _manageSubscription() async {
    try {
      final opened = await launchUrl(
          Uri.parse('https://apps.apple.com/account/subscriptions'),
          mode: LaunchMode.externalApplication);
      if (!opened) _showFailure(tr('paywall_manage_error'));
    } catch (_) {
      _showFailure(tr('paywall_manage_error'));
    }
  }
}
