// 起動画面（読み込み → ホーム）のテスト

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/types.dart';

import 'package:poco/main.dart';
import 'package:poco/screens/home_screen.dart';
import 'package:poco/widgets/cat_loading.dart';

import 'test_helpers.dart';

/// 読み書きがすべて失敗する保存領域
class _BrokenStore extends SharedPreferencesStorePlatform {
  _BrokenStore({this.hang = false});

  /// trueの場合は失敗もせず、いつまでも応答しない
  final bool hang;

  Future<T> _fail<T>() {
    if (hang) return Completer<T>().future;
    return Future<T>.error(StateError('storage is broken'));
  }

  @override
  Future<bool> clear() => _fail();

  @override
  Future<Map<String, Object>> getAll() => _fail();

  @override
  Future<Map<String, Object>> getAllWithParameters(
          GetAllParameters parameters) =>
      _fail();

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) => _fail();

  @override
  Future<bool> remove(String key) => _fail();

  @override
  Future<bool> setValue(String valueType, String key, Object value) => _fail();
}

/// 保存領域を、次の読み込みから [store] を使う状態にする
void _useStore(SharedPreferencesStorePlatform store) {
  // キャッシュ済みのインスタンスを捨ててから差し替える
  SharedPreferences.setMockInitialValues({});
  SharedPreferencesStorePlatform.instance = store;
}

Future<void> _pumpStartup(WidgetTester tester) async {
  setScreen(tester, size: const Size(390, 844));
  await pumpWithApp(tester, const InitializationScreen());
}

void main() {
  setUpAll(setUpTestEnvironment);

  // 注意: 保存領域が壊れているケースを先に実行する
  // （一度読み込みに成功すると、各サービスが保存領域を保持し続けるため）
  testWidgets('読み込みに失敗したら回し続けず、再試行で復帰できる', (tester) async {
    _useStore(_BrokenStore());
    await _pumpStartup(tester);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CatLoadFailedView), findsOneWidget);
    expect(find.text('読み込みに失敗しました。\nもう一度お試しください。'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    // 猫は止まっている
    expect(tester.hasRunningAnimations, isFalse);

    // 保存領域が回復したあとに「再試行」を押すとホームへ進む
    SharedPreferences.setMockInitialValues({});
    await tester.tap(find.byKey(const ValueKey('retry_button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(InitializationScreen), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('読み込みが終わらない時も、一定時間で打ち切って再試行を出す', (tester) async {
    _useStore(_BrokenStore(hang: true));
    await _pumpStartup(tester);

    // 読み込み中は猫のアニメーション
    expect(find.byType(CatLoadingIndicator), findsOneWidget);
    expect(find.text('読み込み中...'), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pump(const Duration(seconds: 16));
    await tester.pump();

    expect(find.byType(CatLoadFailedView), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('読み込みが終わればすぐホーム画面に切り替わる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpStartup(tester);
    // 待ち時間を挟まず、読み込み完了の直後にホームへ進む
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(InitializationScreen), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });
}
