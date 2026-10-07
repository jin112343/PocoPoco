import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

import 'package:poco/screens/upgrade_screen.dart';
import 'package:poco/screens/home_screen.dart';
import 'package:poco/services/storage_service.dart';
import 'package:poco/services/subscription_provider.dart';
import 'package:poco/widgets/paywall_widgets.dart';

// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'test_helpers.dart';

class _FakeLauncher extends UrlLauncherPlatform {
  @override
  get linkDelegate => null;
  bool succeeds = true;
  String? openedUrl;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    openedUrl = url;
    return succeeds;
  }
}

/// ストアの代役。購入可能な商品はなく、復元の結果はテストから流し込む
class _FakeStore extends InAppPurchasePlatform {
  final StreamController<List<PurchaseDetails>> purchases =
      StreamController<List<PurchaseDetails>>.broadcast();
  int restoreCalls = 0;
  int buyCalls = 0;
  String? purchasedProductId;
  bool available = true;
  List<ProductDetails> products = [];
  Future<ProductDetailsResponse> Function()? queryAction;
  Future<bool> Function()? availableAction;
  Future<bool> Function()? buyAction;
  Future<void> Function()? restoreAction;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => purchases.stream;

  @override
  Future<bool> isAvailable() async =>
      availableAction == null ? available : await availableAction!();

  @override
  Future<ProductDetailsResponse> queryProductDetails(
      Set<String> identifiers) async {
    if (queryAction != null) return queryAction!();
    return ProductDetailsResponse(
      productDetails: products,
      notFoundIDs: identifiers.toList(),
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyCalls++;
    purchasedProductId = purchaseParam.productDetails.id;
    return buyAction == null ? true : await buyAction!();
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls++;
    if (restoreAction != null) await restoreAction!();
  }
}

PurchaseDetails _restoredPurchase(String productId) {
  return PurchaseDetails(
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: '',
      source: 'test',
    ),
    transactionDate: '0',
    status: PurchaseStatus.restored,
  );
}

void main() {
  late _FakeStore store;
  Map<String, dynamic> appleEntitlement = {'active': false};
  int appleRestoreCalls = 0;
  Future<Map<String, dynamic>> Function()? appleAction;

  setUpAll(() async {
    await setUpTestEnvironment();
    if (const bool.fromEnvironment('PAYWALL_PREVIEWS')) {
      final textFont = FontLoader('NotoSansJP')
        ..addFont(rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/NotoSansJP-Bold.ttf'));
      await textFont.load();
      final iconFont = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await iconFont.load();
    }
    // InAppPurchase.instance は初回アクセス時にOS別の本物のストア実装を登録し、
    // 課金サービスへ接続しようとする。テストでは接続できないので、
    // ストア実装のないOSとして初期化してから代役を登録する
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = null;
  });

  setUp(() async {
    await clearStoredData();
    store = _FakeStore();
    InAppPurchasePlatform.instance = store;
    appleEntitlement = {'active': false};
    appleRestoreCalls = 0;
    appleAction = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.mizoishun.pocopoco/entitlements'),
            (call) async {
      if (call.method == 'restore') appleRestoreCalls++;
      return appleAction == null ? appleEntitlement : await appleAction!();
    });
  });

  Future<SubscriptionProvider> openUpgradeScreen(WidgetTester tester) async {
    setScreen(tester, size: const Size(390, 844));
    final subscription = await pumpWithApp(tester, const UpgradeScreen());
    // ストア情報の読み込みと表示アニメーションを待つ
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));
    return subscription;
  }

  /// 画面を閉じて、残っているタイマーとアニメーションを止める
  Future<void> closeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  }

  final restoreButton = find.byKey(const ValueKey('restore_purchases_button'));

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    final name = platform == TargetPlatform.android ? 'Android' : 'iOS';

    testWidgets('$name: 解約時のデータの扱いと、購入の復元が案内されている', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await openUpgradeScreen(tester);

        // 具体例つきの機能説明
        expect(find.text('作品の保存が無制限'), findsWidgets);
        expect(find.textContaining('マフラーも帽子も'), findsOneWidget);
        expect(find.textContaining('引き上げ編み'), findsOneWidget);
        expect(find.textContaining('手を止めずに'), findsOneWidget);
        // 無料プランとの違い
        expect(find.text('3作品まで'), findsOneWidget);
        expect(find.text('無制限'), findsOneWidget);
        expect(find.text('6種類'), findsOneWidget);
        expect(find.text('60種類以上'), findsOneWidget);
        expect(find.text('広告あり'), findsOneWidget);

        // 解約しても作品が消えないことの説明
        expect(find.byKey(const ValueKey('data_safety_note')), findsOneWidget);
        expect(find.text('解約しても作品は消えません'), findsOneWidget);

        // 購入の復元はどちらのOSでもできる
        expect(restoreButton, findsOneWidget);
        // 支払い状況の確認はiOSのみ
        expect(
          find.text('支払い状況を確認'),
          platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
        );
        await closeScreen(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('$name: 復元で購入が見つかればプレミアムに戻り、作品データはそのまま', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        final storage = StorageService();
        await storage.save(buildProject(id: 'p1', rows: const [3, 2]));
        final subscription = await openUpgradeScreen(tester);
        expect(subscription.isPremium, isFalse);
        appleEntitlement = {
          'active': true,
          'productId': 'monthly_sub',
          'expiresAt':
              DateTime.now().add(const Duration(days: 2)).millisecondsSinceEpoch
        };

        await tester.ensureVisible(restoreButton);
        await tester.pump();
        await tester.tap(restoreButton);
        await tester.pump();
        expect(
            platform == TargetPlatform.iOS
                ? appleRestoreCalls
                : store.restoreCalls,
            1);

        // ストアから復元結果が届く
        store.purchases.add([_restoredPurchase('monthly_sub')]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(subscription.isPremium, isTrue);
        expect(find.text('復元できる購入が見つかりませんでした'), findsNothing);

        // 作品データには一切触れない
        final project = (await storage.loadProjects()).single;
        expect(project.id, 'p1');
        expect(project.stitchHistory.length, 6);
        expect(project.currentRow, 2);
        await closeScreen(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('$name: 復元できる購入がなければ、その旨を伝える', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        final subscription = await openUpgradeScreen(tester);

        await tester.ensureVisible(restoreButton);
        await tester.pump();
        await tester.tap(restoreButton);
        await tester.pump();
        expect(
            platform == TargetPlatform.iOS
                ? appleRestoreCalls
                : store.restoreCalls,
            1);

        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('復元できる購入が見つかりませんでした'), findsOneWidget);
        expect(subscription.isPremium, isFalse);
        await closeScreen(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
  final purchaseButton = find.byKey(const ValueKey('purchase_selected_plan'));
  final yearlyCard = find.byKey(const ValueKey('plan_yearly_sub'));
  final monthlyCard = find.byKey(const ValueKey('plan_monthly_sub'));

  void addPlans({double yearPrice = 3000, double monthPrice = 300}) {
    store.products = [
      ProductDetails(
          id: 'monthly_sub',
          title: 'Monthly',
          description: '',
          price: '¥${monthPrice.toInt()}',
          rawPrice: monthPrice,
          currencyCode: 'JPY'),
      ProductDetails(
          id: 'yearly_sub',
          title: 'Yearly',
          description: '',
          price: '¥${yearPrice.toInt()}',
          rawPrice: yearPrice,
          currencyCode: 'JPY'),
    ];
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final state in ['free', 'active', 'expired', 'storeFailure']) {
      testWidgets('$platform: ホームから設定経由で課金画面を開く $state', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          addPlans();
          if (state == 'storeFailure') {
            store.availableAction = () async => throw StateError('offline');
          }
          final subscription = SubscriptionProvider();
          if (state == 'active' || state == 'expired') {
            final expiry =
                DateTime.now().add(Duration(days: state == 'active' ? 7 : -7));
            appleEntitlement = state == 'active'
                ? {
                    'active': true,
                    'productId': 'monthly_sub',
                    'expiresAt': expiry.millisecondsSinceEpoch
                  }
                : {'active': false};
            await subscription.setPremium(true,
                subscriptionId: 'monthly_sub', expiryDate: expiry);
            await subscription.loadStatus();
          }
          await StorageService()
              .save(buildProject(id: 'entry-test', rows: const [5, 2]));
          final prefs = await SharedPreferences.getInstance();
          final before = {
            for (final key in prefs.getKeys()) key: prefs.get(key)
          };
          setScreen(tester, size: const Size(390, 844));
          await pumpWithApp(tester, const HomeScreen(),
              subscription: subscription);
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.settings));
          await tester.pumpAndSettle();
          await tester.tap(find.text('プレミアムプラン').first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(UpgradeScreen), findsOneWidget);
          expect(find.text('Poco Premium'), findsOneWidget);
          expect(subscription.isPremium, state == 'active');
          expect(restoreButton, findsOneWidget);
          if (state == 'storeFailure') {
            expect(find.byKey(const ValueKey('retry_store_button')),
                findsOneWidget);
          } else {
            expect(yearlyCard, findsOneWidget);
            expect(monthlyCard, findsOneWidget);
            expect(
                tester.widget<FilledButton>(purchaseButton).onPressed == null,
                state == 'active');
          }
          expect(
              {for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
          await tester.tap(find.byKey(const ValueKey('close_paywall_button')));
          await tester.pumpAndSettle();
          expect(find.byType(UpgradeScreen), findsNothing);
          await closeScreen(tester);
          subscription.dispose();
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }

  testWidgets('StoreKit2の実際の型の商品リストが遅れて届いてもプラン画面が残る', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final response = Completer<ProductDetailsResponse>();
      store.queryAction = () => response.future;
      await openUpgradeScreen(tester);
      expect(find.text('Poco Premium'), findsOneWidget);
      expect(yearlyCard, findsNothing);
      final products = <AppStoreProduct2Details>[
        for (final id in ['yearly_sub', 'monthly_sub'])
          AppStoreProduct2Details.fromSK2Product(SK2Product(
            id: id,
            displayName: id,
            description: '',
            price: id == 'yearly_sub' ? 3000 : 300,
            displayPrice: id == 'yearly_sub' ? '¥3,000' : '¥300',
            type: SK2ProductType.autoRenewable,
            priceLocale:
                SK2PriceLocale(currencyCode: 'JPY', currencySymbol: '¥'),
          )),
      ];
      response.complete(
          ProductDetailsResponse(productDetails: products, notFoundIDs: []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.text('Poco Premium'), findsOneWidget);
      expect(yearlyCard, findsOneWidget);
      expect(monthlyCard, findsOneWidget);
      final subscription = tester
          .element(find.byType(UpgradeScreen))
          .read<SubscriptionProvider>();
      await subscription.setPremium(true,
          subscriptionId: 'monthly_sub',
          expiryDate: DateTime.now().add(const Duration(days: 1)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('ご利用中のプラン: 月額プラン'), findsOneWidget);
      await subscription.setPremium(false);
      await tester.pumpAndSettle();
      await tester.ensureVisible(monthlyCard);
      await tester.tap(monthlyCard);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(purchaseButton);
      await tester.tap(purchaseButton);
      await tester.pump();
      expect(store.purchasedProductId, 'monthly_sub');
      await closeScreen(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final result in ['empty', 'error', 'exception', 'closed']) {
    testWidgets('商品読込が遅れて $result になっても描画や破棄後更新で例外にならない', (tester) async {
      final response = Completer<ProductDetailsResponse>();
      store.queryAction = () => response.future;
      await openUpgradeScreen(tester);
      expect(find.text('Poco Premium'), findsOneWidget);
      if (result == 'closed') await closeScreen(tester);
      if (result == 'exception') {
        response.completeError(
            PlatformException(code: 'storekit2_products_error'));
      } else {
        response.complete(ProductDetailsResponse(
          productDetails: <AppStoreProduct2Details>[],
          notFoundIDs: ['yearly_sub', 'monthly_sub'],
          error: result == 'error'
              ? IAPError(
                  source: 'app_store',
                  code: 'storekit_no_response',
                  message: 'unavailable')
              : null,
        ));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      if (result != 'closed') {
        expect(find.text('Poco Premium'), findsOneWidget);
        expect(
            find.byKey(const ValueKey('retry_store_button')), findsOneWidget);
        expect(restoreButton, findsOneWidget);
        await closeScreen(tester);
      }
    });
  }

  testWidgets('年額・月額の比較と請求額がストアの価格に追従し、選択した商品を購入する', (tester) async {
    addPlans(yearPrice: 2400, monthPrice: 400);
    await openUpgradeScreen(tester);
    expect(find.text('月額より50%お得'), findsOneWidget);
    expect(find.text('月あたり¥200相当・年額でお支払い'), findsOneWidget);
    expect(find.text('¥2400/年のお支払い。自動更新。'), findsOneWidget);
    expect(find.text('3日間無料で試す'), findsNothing);

    await tester.ensureVisible(monthlyCard);
    await tester.pumpAndSettle();
    await tester.tap(monthlyCard);
    await tester.pumpAndSettle();
    expect(store.buyCalls, 0);
    expect(find.text('月額プランで続ける'), findsOneWidget);
    expect(find.text('¥400/月のお支払い。自動更新。'), findsOneWidget);
    await tester.ensureVisible(purchaseButton);
    await tester.pump();
    await tester.tap(purchaseButton);
    await tester.pump();
    expect(store.buyCalls, 1);
    expect(store.purchasedProductId, 'monthly_sub');
    expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNull);
    await closeScreen(tester);
  });

  testWidgets('無料体験済みの場合は体験の案内を出さず、年額を明示する', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_used_trial', true);
    addPlans();
    final provider = SubscriptionProvider();
    await provider.loadStatus();
    setScreen(tester, size: const Size(390, 844));
    await pumpWithApp(tester, const UpgradeScreen(), subscription: provider);
    await tester.pumpAndSettle();
    expect(find.text('3日間無料で試す'), findsNothing);
    expect(find.text('初回は3日間無料体験'), findsNothing);
    expect(find.text('年間プランで続ける'), findsOneWidget);
    expect(find.text('¥3000/年のお支払い。自動更新。'), findsOneWidget);
    await closeScreen(tester);
  });

  testWidgets('ストアが使えなくても閉じる・復元ができ、再読み込みでプランが表示される', (tester) async {
    store.available = false;
    await openUpgradeScreen(tester);
    expect(find.byKey(const ValueKey('close_paywall_button')), findsOneWidget);
    expect(restoreButton, findsOneWidget);
    expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNull);
    store.available = true;
    addPlans();
    final retry = find.byKey(const ValueKey('retry_store_button'));
    await tester.ensureVisible(retry);
    await tester.pump();
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(yearlyCard, findsOneWidget);
    expect(monthlyCard, findsOneWidget);
    expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNotNull);
    await closeScreen(tester);
  });

  testWidgets('プレミアム利用中は追加の購入を無効にしてプラン名を表示する', (tester) async {
    addPlans();
    final provider = SubscriptionProvider();
    await provider.setPremium(true,
        subscriptionId: 'monthly_sub',
        expiryDate: DateTime.now().add(const Duration(days: 30)));
    setScreen(tester, size: const Size(390, 844));
    await pumpWithApp(tester, const UpgradeScreen(), subscription: provider);
    await tester.pumpAndSettle();
    expect(find.text('プレミアムをご利用中'), findsOneWidget);
    expect(find.text('ご利用中のプラン: 月額プラン'), findsOneWidget);
    expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNull);
    await closeScreen(tester);
  });

  for (final language in ['ja', 'en', 'ko', 'es', 'de']) {
    for (final dark in [false, true]) {
      testWidgets('$language: 幅320・文字サイズ1.5・ダーク=$dark でも表示が崩れない',
          (tester) async {
        addPlans();
        setScreen(tester, size: const Size(320, 640), textScale: 1.5);
        await pumpWithApp(
            tester,
            Theme(
                data: ThemeData(
                    brightness: dark ? Brightness.dark : Brightness.light),
                child: const UpgradeScreen()),
            locale: Locale(language));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(monthlyCard);
        await tester.pumpAndSettle();
        await tester.tap(monthlyCard);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
            tester.widget<FilledButton>(purchaseButton).onPressed, isNotNull);
        await tester.ensureVisible(restoreButton);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await closeScreen(tester);
      });
    }
  }

  testWidgets('商品読込が停止しても15秒で再試行でき、復元も利用できる', (tester) async {
    store.availableAction = () => Completer<bool>().future;
    await openUpgradeScreen(tester);
    await tester.pump(const Duration(seconds: 16));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('retry_store_button')), findsOneWidget);
    expect(tester.widget<TextButton>(restoreButton).onPressed, isNotNull);
    await closeScreen(tester);
  });

  for (final returnFalse in [false, true]) {
    testWidgets('購入開始の非同期失敗 false=$returnFalse から再操作できる', (tester) async {
      addPlans();
      store.buyAction = () async {
        if (returnFalse) return false;
        throw StateError('offline');
      };
      await openUpgradeScreen(tester);
      await tester.tap(purchaseButton);
      await tester.pump();
      expect(store.buyCalls, 1);
      expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNotNull);
      expect(find.textContaining('購入を開始できませんでした'), findsWidgets);
      expect(tester.takeException(), isNull);
      await closeScreen(tester);
    });
  }

  testWidgets('購入の連打・復元の割込みを防ぎ、60秒後には再操作できる', (tester) async {
    addPlans();
    store.buyAction = () => Completer<bool>().future;
    await openUpgradeScreen(tester);
    final buy = tester.widget<FilledButton>(purchaseButton).onPressed!;
    buy();
    buy();
    await tester.pump();
    expect(store.buyCalls, 1);
    expect(tester.widget<TextButton>(restoreButton).onPressed, isNull);
    await tester.pump(const Duration(seconds: 61));
    expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNotNull);
    expect(tester.widget<TextButton>(restoreButton).onPressed, isNotNull);
    await closeScreen(tester);
  });

  testWidgets('復元の非同期失敗を表示し、再試行できる', (tester) async {
    store.restoreAction = () async => throw StateError('offline');
    await openUpgradeScreen(tester);
    await tester.tap(restoreButton);
    await tester.pump();
    expect(tester.widget<TextButton>(restoreButton).onPressed, isNotNull);
    expect(find.textContaining('購入を復元できませんでした'), findsWidgets);
    expect(tester.takeException(), isNull);
    await closeScreen(tester);
  });

  testWidgets('iOS復元の連打と無応答を保護し、失敗後も作品を保持する', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final storage = StorageService();
      await storage.save(buildProject(id: 'safe', memo: '残す'));
      appleAction = () => Completer<Map<String, dynamic>>().future;
      await openUpgradeScreen(tester);
      final restore = tester.widget<TextButton>(restoreButton).onPressed!;
      restore();
      restore();
      await tester.pump();
      expect(appleRestoreCalls, 1);
      await tester.pump(const Duration(seconds: 61));
      expect(tester.widget<TextButton>(restoreButton).onPressed, isNotNull);
      expect((await storage.loadProjects()).single.memo, '残す');
      await closeScreen(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final status in [PurchaseStatus.canceled, PurchaseStatus.error]) {
    testWidgets('購入イベント $status で待機解除する', (tester) async {
      addPlans();
      await openUpgradeScreen(tester);
      await tester.tap(purchaseButton);
      await tester.pump();
      final purchase = _restoredPurchase('yearly_sub')..status = status;
      store.purchases.add([purchase]);
      await tester.pump();
      expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNotNull);
      await closeScreen(tester);
    });
  }

  testWidgets('幅320・高さ568・文字2.5倍でも購入と復元までスクロールできる', (tester) async {
    addPlans();
    setScreen(tester, size: const Size(320, 568), textScale: 2.5);
    await pumpWithApp(tester, const UpgradeScreen());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(purchaseButton);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(restoreButton);
    await tester.pumpAndSettle();
    expect(tester.getRect(restoreButton).bottom, lessThanOrEqualTo(568));
    expect(tester.takeException(), isNull);
    await closeScreen(tester);
  });

  for (final opens in [true, false]) {
    testWidgets(
        'iOS subscription management opens=$opens never revokes local access',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addPlans();
      final prior = UrlLauncherPlatform.instance;
      final launcher = _FakeLauncher()..succeeds = opens;
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() {
        UrlLauncherPlatform.instance = prior;
      });
      final subscription = SubscriptionProvider();
      await subscription.setPremium(true,
          subscriptionId: 'monthly_sub', expiryDate: DateTime(2030));
      await StorageService().save(buildProject(memo: 'saved memo'));
      setScreen(tester, size: const Size(390, 844));
      await pumpWithApp(tester, const UpgradeScreen(),
          subscription: subscription);
      await tester.pumpAndSettle();
      final manage = find.text('App Storeで契約を管理');
      await tester.ensureVisible(manage);
      await tester.tap(manage);
      await tester.pumpAndSettle();
      expect(
          launcher.openedUrl, 'https://apps.apple.com/account/subscriptions');
      expect(subscription.isPremium, true);
      expect((await StorageService().loadProjects()).single.memo, 'saved memo');
      await closeScreen(tester);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  group('処理中のまま固まらない', () {
    final dismissButton =
        find.byKey(const ValueKey('dismiss_processing_button'));

    PurchaseDetails storeEvent(String productId, PurchaseStatus status) =>
        _restoredPurchase(productId)..status = status;

    Map<String, dynamic> activeEntitlement(String productId) => {
          'active': true,
          'productId': productId,
          'expiresAt': DateTime.now()
              .add(const Duration(days: 30))
              .millisecondsSinceEpoch,
        };

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('iOS: 購入シートを閉じて結果の通知が来なくても、すぐ操作できる状態に戻る', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        addPlans();
        final subscription = await openUpgradeScreen(tester);
        await tester.tap(purchaseButton);
        await settle(tester);
        expect(store.buyCalls, 1);
        // 60秒のタイムアウトを待たずに戻っている
        expect(find.text('購入処理中...'), findsNothing);
        expect(
            tester.widget<FilledButton>(purchaseButton).onPressed, isNotNull);
        expect(tester.widget<TextButton>(restoreButton).onPressed, isNotNull);
        expect(subscription.isPremium, isFalse);
        // キャンセルはエラーではないので、何も表示しない
        expect(find.textContaining('購入を開始できませんでした'), findsNothing);
        await tester.pump(const Duration(seconds: 61));
        expect(find.textContaining('タイムアウト'), findsNothing);
        await closeScreen(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('iOS: 購入できていれば、結果の通知が来なくてもプレミアムになり、案内は1回だけ', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        addPlans();
        store.buyAction = () async {
          // 購入シートで購入が完了した
          appleEntitlement = activeEntitlement('yearly_sub');
          return true;
        };
        final subscription = await openUpgradeScreen(tester);
        await tester.tap(purchaseButton);
        await settle(tester);
        expect(subscription.isPremium, isTrue);
        expect(find.text('購入処理中...'), findsNothing);
        expect(find.text('プレミアムプランにアップグレードしました！'), findsOneWidget);

        // 通知が遅れて届いても、同じ案内をもう一度出さない
        store.purchases
            .add([storeEvent('yearly_sub', PurchaseStatus.purchased)]);
        await settle(tester);
        // 最初の案内が消えるまで進める。もう1件たまっていれば、ここで続けて表示される
        for (var second = 0; second < 7; second++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(find.text('プレミアムプランにアップグレードしました！'), findsNothing);
        expect(subscription.isPremium, isTrue);
        await closeScreen(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('$platform: ストアが応答しない時は、少し待つと自分で閉じられる。あとから購入が届けば反映される',
          (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          addPlans();
          // 購入シートが出ないまま、ストアから何も返ってこない
          if (platform == TargetPlatform.iOS) {
            store.buyAction = () => Completer<bool>().future;
          }
          final subscription = await openUpgradeScreen(tester);
          await tester.tap(purchaseButton);
          await tester.pump();
          expect(find.text('購入処理中...'), findsOneWidget);
          expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNull);

          // 最初は待つだけ。少し経っても終わらなければ「閉じる」が出る
          await tester.pump(const Duration(seconds: 3));
          expect(dismissButton, findsNothing);
          await tester.pump(const Duration(seconds: 4));
          expect(dismissButton, findsOneWidget);
          await tester.tap(dismissButton);
          await tester.pump();
          expect(find.text('購入処理中...'), findsNothing);
          expect(
              tester.widget<FilledButton>(purchaseButton).onPressed, isNotNull);
          expect(tester.widget<TextButton>(restoreButton).onPressed, isNotNull);
          // 画面も閉じられる
          expect(
              tester
                  .widget<IconButton>(
                      find.byKey(const ValueKey('close_paywall_button')))
                  .onPressed,
              isNotNull);

          // 閉じたあとで購入が完了した場合も、プレミアムになる
          appleEntitlement = activeEntitlement('yearly_sub');
          store.purchases
              .add([storeEvent('yearly_sub', PurchaseStatus.purchased)]);
          await settle(tester);
          expect(subscription.isPremium, isTrue);

          // 自分で閉じたあとは、タイムアウトのエラーを出さない
          await tester.pump(const Duration(seconds: 61));
          expect(find.textContaining('タイムアウト'), findsNothing);
          expect(find.textContaining('購入を開始できませんでした'), findsNothing);
          expect(tester.takeException(), isNull);
          await closeScreen(tester);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    testWidgets('iOS: 復元が応答しない時も、少し待つと自分で閉じられる', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        addPlans();
        appleAction = () => Completer<Map<String, dynamic>>().future;
        await openUpgradeScreen(tester);
        await tester.tap(restoreButton);
        await tester.pump();
        expect(find.text('購入情報を復元中...'), findsOneWidget);
        await tester.pump(const Duration(seconds: 7));
        await tester.tap(dismissButton);
        await tester.pump();
        expect(find.text('購入情報を復元中...'), findsNothing);
        expect(tester.widget<TextButton>(restoreButton).onPressed, isNotNull);
        expect(
            tester.widget<FilledButton>(purchaseButton).onPressed, isNotNull);
        await tester.pump(const Duration(seconds: 61));
        expect(find.textContaining('タイムアウト'), findsNothing);
        expect(find.textContaining('購入を復元できませんでした'), findsNothing);
        expect(tester.takeException(), isNull);
        await closeScreen(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('$platform: 承認待ちの購入では画面を待たせず、あとで反映されることを伝える', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          addPlans();
          if (platform == TargetPlatform.iOS) {
            // 承認待ちの間は、購入の呼び出しが戻らないこともある
            store.buyAction = () => Completer<bool>().future;
          }
          final subscription = await openUpgradeScreen(tester);
          await tester.tap(purchaseButton);
          await tester.pump();
          store.purchases
              .add([storeEvent('yearly_sub', PurchaseStatus.pending)]);
          await settle(tester);
          expect(find.text('購入処理中...'), findsNothing);
          expect(
              tester.widget<FilledButton>(purchaseButton).onPressed, isNotNull);
          expect(find.textContaining('完了すると自動でプレミアムになります'), findsOneWidget);
          expect(subscription.isPremium, isFalse);

          // 承認されたら、そのままプレミアムになる
          appleEntitlement = activeEntitlement('yearly_sub');
          store.purchases
              .add([storeEvent('yearly_sub', PurchaseStatus.purchased)]);
          await settle(tester);
          expect(subscription.isPremium, isTrue);
          await tester.pump(const Duration(seconds: 61));
          expect(find.textContaining('タイムアウト'), findsNothing);
          await closeScreen(tester);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    for (final alreadyEntitled in [false, true]) {
      testWidgets(
          'iOS: 完了処理の済んでいない取引が残っていても購入できる（残りが有効な契約=$alreadyEntitled）',
          (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          addPlans();
          var attempts = 0;
          store.buyAction = () async {
            attempts++;
            if (attempts == 1) {
              // 未完了の取引が残っていると、StoreKitプラグインは購入を受け付けない
              throw PlatformException(
                  code: 'storekit_duplicate_product_object');
            }
            return true;
          };
          final finished = <Set<String>>[];
          final subscription = SubscriptionProvider(
              appleTransactionFinisher: (productIds) async {
            finished.add(productIds);
            return 1;
          });
          setScreen(tester, size: const Size(390, 844));
          await pumpWithApp(tester, const UpgradeScreen(),
              subscription: subscription);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(seconds: 1));
          if (alreadyEntitled) {
            appleEntitlement = activeEntitlement('yearly_sub');
          }

          await tester.tap(purchaseButton);
          await settle(tester);
          // 残っていた取引を完了させている
          expect(finished, hasLength(1));
          expect(finished.single, containsAll(['yearly_sub', 'monthly_sub']));
          expect(find.textContaining('購入を開始できませんでした'), findsNothing);
          expect(find.text('購入処理中...'), findsNothing);
          if (alreadyEntitled) {
            // 残っていた取引が有効な契約だったので、買い直さずにプレミアムになる
            expect(store.buyCalls, 1);
            expect(subscription.isPremium, isTrue);
            expect(find.text('プレミアムプランにアップグレードしました！'), findsOneWidget);
          } else {
            // 片付けたうえで、購入をやり直している
            expect(store.buyCalls, 2);
            expect(subscription.isPremium, isFalse);
            expect(tester.widget<FilledButton>(purchaseButton).onPressed,
                isNotNull);
          }
          await closeScreen(tester);
          subscription.dispose();
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    testWidgets('購入を始められなかった時は、原因を調べられるようエラーコードを添える', (tester) async {
      addPlans();
      store.buyAction = () async =>
          throw PlatformException(code: 'storekit2_failed_to_fetch_product');
      await openUpgradeScreen(tester);
      await tester.tap(purchaseButton);
      await settle(tester);
      expect(find.textContaining('購入を開始できませんでした'), findsWidgets);
      expect(find.textContaining('(storekit2_failed_to_fetch_product)'),
          findsWidgets);
      expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNotNull);
      await closeScreen(tester);
    });
  });

  group('表示とアニメーション', () {
    /// [finder] を包んでいる、いちばん近い入場アニメーションの不透明度
    double entranceOpacity(WidgetTester tester, Finder finder) => tester
        .widget<FadeTransition>(find
            .ancestor(of: finder, matching: find.byType(FadeTransition))
            .first)
        .opacity
        .value;

    testWidgets('画面外のプランはスクロールで現れ、表示のアニメーションは繰り返さない', (tester) async {
      addPlans();
      await openUpgradeScreen(tester);
      await tester.pumpAndSettle();
      // 動き続けるアニメーションが残っていない
      expect(tester.binding.transientCallbackCount, 0);

      // 最初から見えている特典は表示済み、画面外のプランはまだ現れていない
      expect(entranceOpacity(tester, find.text('作品の保存が無制限')), 1.0);
      expect(tester.getTopLeft(yearlyCard).dy, greaterThan(844));
      expect(entranceOpacity(tester, yearlyCard), 0.0);

      await tester.ensureVisible(yearlyCard);
      await tester.pumpAndSettle();
      expect(entranceOpacity(tester, yearlyCard), 1.0);
      expect(tester.binding.transientCallbackCount, 0);
      await closeScreen(tester);
    });

    testWidgets('イラストをタップすると、猫がもう一度だけ毛糸玉を転がす', (tester) async {
      addPlans();
      await openUpgradeScreen(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PaywallHero));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
      await closeScreen(tester);
    });

    testWidgets('アニメーションを減らす設定では、動かさずに最初から表示する', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      addPlans();
      setScreen(tester, size: const Size(390, 844));
      await pumpWithApp(tester, const UpgradeScreen());
      // 通常なら順番に現れている途中の時点で、すでに表示が終わっている
      expect(entranceOpacity(tester, find.text('広告なし').first), 1.0);
      // 料金の読み込み完了に伴うボタンの色の切り替え（短いフェード）だけ待つ
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.tap(find.byType(PaywallHero));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.ensureVisible(monthlyCard);
      await tester.pump();
      await tester.pump();
      expect(entranceOpacity(tester, monthlyCard), 1.0);
      await tester.tap(monthlyCard);
      await tester.pumpAndSettle();
      expect(find.text('月額プランで続ける'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await closeScreen(tester);
    });

    testWidgets('料金の読み込み中は、ボタンの上にその旨を表示する', (tester) async {
      final response = Completer<ProductDetailsResponse>();
      store.queryAction = () => response.future;
      addPlans();
      await openUpgradeScreen(tester);
      expect(find.text('読み込み中...'), findsOneWidget);
      expect(find.byType(PaywallPlanSkeleton), findsOneWidget);
      expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNull);

      response.complete(ProductDetailsResponse(
          productDetails: store.products, notFoundIDs: const []));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('読み込み中...'), findsNothing);
      expect(find.byType(PaywallPlanSkeleton), findsNothing);
      expect(find.text('¥3000/年のお支払い。自動更新。'), findsOneWidget);
      expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNotNull);
      await closeScreen(tester);
    });

    testWidgets('料金を読み込めなかった時は、スクロールしなくても原因と再試行が見える', (tester) async {
      store.available = false;
      await openUpgradeScreen(tester);
      await tester.pumpAndSettle();
      final retry = find.byKey(const ValueKey('retry_store_button'));
      expect(retry, findsOneWidget);
      final rect = tester.getRect(retry);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(844));
      expect(find.textContaining('料金を読み込めませんでした'), findsWidgets);

      // スクロールせずにそのまま再試行できる
      store.available = true;
      addPlans();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(retry, findsNothing);
      expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNotNull);
      await closeScreen(tester);
    });

    testWidgets('小さい画面では、再試行はプランの欄に1つだけ出る', (tester) async {
      store.available = false;
      setScreen(tester, size: const Size(320, 568));
      await pumpWithApp(tester, const UpgradeScreen());
      await tester.pumpAndSettle();
      final retry = find.byKey(const ValueKey('retry_store_button'));
      expect(retry, findsOneWidget);
      expect(find.textContaining('料金を読み込めませんでした'), findsOneWidget);
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await closeScreen(tester);
    });

    for (final width in [320.0, 360.0, 375.0, 390.0, 430.0]) {
      for (final language in ['ja', 'en', 'ko', 'es', 'de']) {
        testWidgets('$language 幅$width: 無料とプレミアムの比較は、3枚のカードで折り返し方が揃う',
            (tester) async {
          addPlans();
          setScreen(tester, size: Size(width, 844));
          await pumpWithApp(tester, const UpgradeScreen(),
              locale: Locale(language));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // 各カードで「✓ プレミアムでの状態」が「無料での状態」と同じ行にあるか
          final sameLine = <bool>[];
          for (final card in tester
              .widgetList<PaywallBenefitCard>(find.byType(PaywallBenefitCard))) {
            final free = tester.getRect(find.descendant(
                of: find.byWidget(card), matching: find.text(card.freeValue)));
            final premium = tester.getRect(find
                .descendant(
                    of: find.byWidget(card),
                    matching: find.text(card.premiumValue))
                .last);
            sameLine.add((free.center.dy - premium.center.dy).abs() < 4);
          }
          expect(sameLine, hasLength(3));
          expect(sameLine.toSet(), hasLength(1), reason: '$sameLine');
          await closeScreen(tester);
        });
      }
    }

    testWidgets('年額が月額より安くない時は「おすすめ」を出さない', (tester) async {
      addPlans(yearPrice: 3600, monthPrice: 300);
      await openUpgradeScreen(tester);
      await tester.pumpAndSettle();
      expect(yearlyCard, findsOneWidget);
      expect(find.text('おすすめ'), findsNothing);
      expect(find.textContaining('お得'), findsNothing);
      await closeScreen(tester);
    });

    testWidgets('年額が月額より安い時は「おすすめ」と割引率を出す', (tester) async {
      addPlans();
      await openUpgradeScreen(tester);
      await tester.pumpAndSettle();
      expect(find.text('おすすめ'), findsOneWidget);
      expect(find.text('月額より16%お得'), findsOneWidget);
      await closeScreen(tester);
    });
  });

  if (const bool.fromEnvironment('PAYWALL_PREVIEWS')) {
    /// イラストの画像を先に読み込む（通常のテスト内では画像の読み込みが完了しないため）
    Future<void> precachePaywallImages(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      final context = tester.element(find.byType(SizedBox));
      await tester.runAsync(() async {
        for (final asset in {
          ...PaywallHero.assets,
          ...PaywallStitchesIllustration.assets
        }) {
          await precacheImage(AssetImage(asset), context);
        }
      });
    }

    Future<void> capture(WidgetTester tester, GlobalKey boundaryKey, String name,
        {String? directory, double pixelRatio = 2}) async {
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(directory == null
            ? 'build/paywall-preview-$name.png'
            : '$directory/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    Widget previewScreen(GlobalKey boundaryKey, {bool dark = false}) => Theme(
        data: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
            fontFamily: 'NotoSansJP',
            useMaterial3: true),
        child: RepaintBoundary(key: boundaryKey, child: const UpgradeScreen()));

    // 画面の上端だけでなく、ページ全体も確認できるよう縦に長い画面でも撮る
    const tall = Size(390, 1640);
    final scenarios = <String, ({Size size, double textScale, String locale})>{
      'light': (size: const Size(390, 844), textScale: 1.0, locale: 'ja'),
      'dark': (size: const Size(390, 844), textScale: 1.0, locale: 'ja'),
      'large': (size: const Size(320, 568), textScale: 2.5, locale: 'ja'),
      'unavailable': (size: const Size(390, 844), textScale: 1.0, locale: 'ja'),
      'full': (size: tall, textScale: 1.0, locale: 'ja'),
      'full-dark': (size: tall, textScale: 1.0, locale: 'ja'),
      'full-premium': (size: tall, textScale: 1.0, locale: 'ja'),
      'full-en': (size: tall, textScale: 1.0, locale: 'en'),
      'full-de-narrow': (
        size: const Size(320, 1900),
        textScale: 1.0,
        locale: 'de'
      ),
      'full-large': (size: const Size(320, 3600), textScale: 2.5, locale: 'ja'),
      // Androidに多い幅360と、小さめのiPhoneの幅375
      'full-360': (size: const Size(360, 1700), textScale: 1.0, locale: 'ja'),
      'full-375': (size: const Size(375, 1700), textScale: 1.0, locale: 'ja'),
      'full-ko': (size: tall, textScale: 1.0, locale: 'ko'),
      'full-es': (size: tall, textScale: 1.0, locale: 'es'),
    };
    for (final MapEntry(key: scenario, value: setting) in scenarios.entries) {
      testWidgets('課金画面プレビュー $scenario', (tester) async {
        addPlans();
        if (scenario == 'unavailable') store.available = false;
        final subscription = SubscriptionProvider();
        if (scenario == 'full-premium') {
          await subscription.setPremium(true,
              subscriptionId: 'yearly_sub',
              expiryDate: DateTime.now().add(const Duration(days: 30)));
        }
        setScreen(tester, size: setting.size, textScale: setting.textScale);
        await precachePaywallImages(tester);
        final boundaryKey = GlobalKey();
        await pumpWithApp(
            tester, previewScreen(boundaryKey, dark: scenario.contains('dark')),
            subscription: subscription, locale: Locale(setting.locale));
        await tester.pumpAndSettle();
        if (scenario == 'large') {
          await tester.ensureVisible(restoreButton);
          await tester.pumpAndSettle();
        }
        await capture(tester, boundaryKey, scenario);
        expect(tester.takeException(), isNull);
        await closeScreen(tester);
        subscription.dispose();
      });
    }

    // 表示アニメーションの途中経過
    testWidgets('課金画面プレビュー motion', (tester) async {
      addPlans();
      setScreen(tester, size: const Size(390, 844));
      await precachePaywallImages(tester);
      final boundaryKey = GlobalKey();
      await pumpWithApp(tester, previewScreen(boundaryKey));
      var elapsed = 300; // pumpWithApp が進めた時間
      for (final at in [300, 600, 1000, 1500, 2200]) {
        await tester.pump(Duration(milliseconds: at - elapsed));
        elapsed = at;
        await capture(tester, boundaryKey, 'motion-$at');
      }
      expect(tester.takeException(), isNull);
      await closeScreen(tester);
    });

    // 処理中の表示（直後と、しばらく待って「閉じる」が出た状態）
    testWidgets('課金画面プレビュー processing', (tester) async {
      addPlans();
      store.buyAction = () => Completer<bool>().future;
      setScreen(tester, size: const Size(390, 844));
      await precachePaywallImages(tester);
      final boundaryKey = GlobalKey();
      await pumpWithApp(tester, previewScreen(boundaryKey));
      await tester.pumpAndSettle();
      await tester.tap(purchaseButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await capture(tester, boundaryKey, 'processing');
      await tester.pump(const Duration(seconds: 7));
      await capture(tester, boundaryKey, 'processing-escape');
      await tester.tap(find.byKey(const ValueKey('dismiss_processing_button')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 61));
      await closeScreen(tester);
    });

    // 動きを連番の画像に書き出す（開く → 下へスクロール → プランを切り替える）。
    // build/paywall-motion/ の画像をつなげると動画として確認できる
    testWidgets('課金画面プレビュー motion-frames', (tester) async {
      addPlans();
      setScreen(tester, size: const Size(390, 844));
      await precachePaywallImages(tester);
      final boundaryKey = GlobalKey();
      final directory = Directory('build/paywall-motion');
      if (directory.existsSync()) directory.deleteSync(recursive: true);
      var frame = 0;
      Future<void> record(int frames) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 40));
          final name = (frame++).toString().padLeft(4, '0');
          await capture(tester, boundaryKey, 'frame-$name',
              directory: directory.path, pixelRatio: 1);
        }
      }

      await pumpWithApp(tester, previewScreen(boundaryKey));
      await record(85);
      final position = tester
          .state<ScrollableState>(find
              .descendant(
                  of: find.byKey(const ValueKey('paywall_scroll')),
                  matching: find.byType(Scrollable))
              .first)
          .position;
      unawaited(position.animateTo(330,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut));
      await record(55);
      unawaited(position.animateTo(position.maxScrollExtent - 250,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut));
      await record(40);
      await tester.tap(monthlyCard);
      await record(30);
      await tester.tap(yearlyCard);
      await record(35);
      expect(tester.takeException(), isNull);
      await closeScreen(tester);
    });
  }
}
