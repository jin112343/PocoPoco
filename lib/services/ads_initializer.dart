import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 広告SDKの初期化を1度だけ行う。
///
/// 起動画面は広告SDKの初期化完了を待たずにホームへ進み（通信状況が悪いと
/// 初期化に時間がかかり、読み込み表示が終わらなくなるため）、
/// 広告を読み込む側が [ready] を待つ。
class AdsInitializer {
  static Future<void>? _initialization;

  /// 初期化を開始する。ATT（トラッキング許可）の回答後に呼ぶこと
  static Future<void> start() => _initialization ??= _initialize();

  /// 広告を読み込む前に待つ。初期化に失敗しても完了する
  static Future<void> get ready => start();

  static Future<void> _initialize() async {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('MobileAds initialization failed: $e');
    }
  }
}
