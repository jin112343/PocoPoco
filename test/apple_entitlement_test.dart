import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poco/services/apple_entitlement_service.dart';
import 'package:poco/services/subscription_provider.dart';

class _Store extends InAppPurchasePlatform {
  int completed = 0;
  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed++;
  }
}

PurchaseDetails purchase(String id) => PurchaseDetails(
      productID: id,
      purchaseID: 'order1',
      transactionDate: '1234',
      verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: 'test'),
      status: PurchaseStatus.restored,
    )..pendingCompletePurchase = true;
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Store store;
  setUpAll(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = null;
  });
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'crochet_project_saved': 'unchanged', 'custom_stitches': 'unchanged'});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    store = _Store();
    InAppPurchasePlatform.instance = store;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });
  for (final id in ['monthly_sub', 'yearly_sub']) {
    test(
        '$id restore uses verified store expiry and never starts a local trial',
        () async {
      final expiration = DateTime(2026, 10, 8, 12);
      final provider = SubscriptionProvider(
          appleEntitlementReader: ({bool restore = false}) async =>
              AppleEntitlement(
                  active: true, productId: id, expiresAt: expiration));
      expect(await provider.handleStorePurchase(purchase(id)), true);
      expect(provider.subscriptionExpiryDate, expiration);
      expect(provider.isInTrialPeriod, false);
      expect(store.completed, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('crochet_project_saved'), 'unchanged');
      expect(prefs.getString('custom_stitches'), 'unchanged');
      provider.dispose();
    });
  }
  test(
      'Expired or revoked entitlement disables premium but retains project and custom data',
      () async {
    final provider = SubscriptionProvider(
        appleEntitlementReader: ({bool restore = false}) async =>
            const AppleEntitlement(active: false));
    await provider.setPremium(true,
        subscriptionId: 'yearly_sub', expiryDate: DateTime(2030));
    expect(await provider.refreshAppleEntitlement(restore: true), false);
    expect(provider.isPremium, false);
    expect(provider.activeSubscriptionId, null);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('crochet_project_saved'), 'unchanged');
    expect(prefs.getString('custom_stitches'), 'unchanged');
    provider.dispose();
  });
  test(
      'Verification failure retains prior state and does not finish the purchase',
      () async {
    final provider = SubscriptionProvider(
        appleEntitlementReader: ({bool restore = false}) async =>
            throw const FormatException('unverified'));
    await provider.setPremium(true,
        subscriptionId: 'yearly_sub', expiryDate: DateTime(2030));
    await expectLater(provider.handleStorePurchase(purchase('monthly_sub')),
        throwsFormatException);
    expect(provider.isPremium, true);
    expect(provider.activeSubscriptionId, 'yearly_sub');
    expect(store.completed, 0);
    provider.dispose();
  });
  test(
      'Screen and startup listener verify and finish the same transaction once',
      () async {
    final pending = Completer<AppleEntitlement>();
    var reads = 0;
    final provider =
        SubscriptionProvider(appleEntitlementReader: ({bool restore = false}) {
      reads++;
      return pending.future;
    });
    final item = purchase('monthly_sub');
    final a = provider.handleStorePurchase(item);
    final b = provider.handleStorePurchase(item);
    pending.complete(AppleEntitlement(
        active: true, productId: 'monthly_sub', expiresAt: DateTime(2030)));
    expect(await Future.wait([a, b]), [true, true]);
    expect(reads, 1);
    expect(store.completed, 1);
    await provider.handleStorePurchase(item);
    expect(store.completed, 1);
    provider.dispose();
  });
  test(
      'Restore follows an in-flight read and subsequent reads share its result',
      () async {
    final initial = Completer<AppleEntitlement>();
    final restored = Completer<AppleEntitlement>();
    final calls = <bool>[];
    final provider =
        SubscriptionProvider(appleEntitlementReader: ({bool restore = false}) {
      calls.add(restore);
      return restore ? restored.future : initial.future;
    });
    final first = provider.refreshAppleEntitlement();
    final second = provider.refreshAppleEntitlement(restore: true);
    expect(calls, [false]);
    initial.complete(const AppleEntitlement(active: false));
    await first;
    await Future<void>.delayed(Duration.zero);
    final third = provider.refreshAppleEntitlement();
    expect(calls, [false, true]);
    restored.complete(AppleEntitlement(
        active: true, productId: 'monthly_sub', expiresAt: DateTime(2030)));
    expect(await Future.wait([second, third]), [true, true]);
    expect(provider.isPremium, true);
    provider.dispose();
  });
  test('Native bridge rejects malformed and unknown active product results',
      () async {
    for (final data in [
      null,
      {'active': 'yes'},
      {'active': true, 'productId': 'unexpected'}
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              AppleEntitlementService.channel, (_) async => data);
      await expectLater(AppleEntitlementService.read(), throwsFormatException);
    }
  });
}
