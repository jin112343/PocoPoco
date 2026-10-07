import 'package:flutter/services.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

/// StoreKitが検証した現在の利用権。端末の日付から契約期間を生成しない。
class AppleEntitlement {
  const AppleEntitlement(
      {required this.active, this.productId, this.expiresAt});
  final bool active;
  final String? productId;
  final DateTime? expiresAt;
}

typedef AppleEntitlementReader = Future<AppleEntitlement> Function(
    {bool restore});

/// 完了処理が済んでいない取引のうち、指定した商品のものを完了させる。完了させた件数を返す
typedef AppleTransactionFinisher = Future<int> Function(Set<String> productIds);

class AppleEntitlementService {
  static const channel = MethodChannel('com.mizoishun.pocopoco/entitlements');

  /// 完了処理が済んでいない取引を完了させる。
  ///
  /// 未完了の取引が残っている商品は、StoreKitが新しい購入を受け付けない。
  /// 完了させても契約中の利用権は失われない（利用権はストア側の契約状態で決まる）。
  static Future<int> finishUnfinished(Set<String> productIds) async {
    var finished = 0;
    for (final transaction in await SK2Transaction.unfinishedTransactions()) {
      final id = int.tryParse(transaction.id);
      if (id == null || !productIds.contains(transaction.productId)) continue;
      await SK2Transaction.finish(id);
      finished++;
    }
    return finished;
  }

  static Future<AppleEntitlement> read({bool restore = false}) async {
    final data = await channel.invokeMapMethod<String, dynamic>(
      restore ? 'restore' : 'current',
    );
    if (data == null || data['active'] is! bool) {
      throw const FormatException('Invalid StoreKit entitlement response');
    }
    final active = data['active'] as bool;
    final id = data['productId'] as String?;
    if (active &&
        !const {'monthly_sub', 'monthly-sub', 'yearly_sub'}.contains(id)) {
      throw const FormatException('Unknown StoreKit product');
    }
    final expires = data['expiresAt'] as num?;
    return AppleEntitlement(
      active: active,
      productId: id,
      expiresAt: expires == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expires.toInt()),
    );
  }
}
