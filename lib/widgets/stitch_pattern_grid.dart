import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/crochet_stitch.dart';
import '../screens/stitch_customization_screen.dart';
import '../screens/upgrade_screen.dart';
import '../services/stitch_settings_service.dart';
import 'package:provider/provider.dart';
import '../services/subscription_provider.dart';
import 'package:easy_localization/easy_localization.dart';

class StitchPatternGrid extends StatefulWidget {
  const StitchPatternGrid({
    super.key,
    required this.selectedStitch,
    required this.onStitchSelected,
    required this.onStitchAdded,
    this.projectStitches, // プロジェクト固有の編み目設定
    this.onStitchSettingsChanged, // 編み目設定が変更された時のコールバック
    this.onProjectStitchesChanged, // プロジェクト固有の編み目設定が変更された時のコールバック
  });

  final CrochetStitch selectedStitch;
  final Function(CrochetStitch) onStitchSelected;
  final Function(dynamic) onStitchAdded;
  final List<dynamic>? projectStitches; // プロジェクト固有の編み目設定
  final VoidCallback? onStitchSettingsChanged; // 編み目設定が変更された時のコールバック
  final Function(List<dynamic>)?
      onProjectStitchesChanged; // プロジェクト固有の編み目設定が変更された時のコールバック

  @override
  State<StitchPatternGrid> createState() => _StitchPatternGridState();
}

class _StitchPatternGridState extends State<StitchPatternGrid> {
  List<dynamic> _stitches = [];
  bool _isLoading = true;
  bool? _wasPremium; // 前回のプレミアム状態を記録
  Map<dynamic, String> _stitchNameCache = {}; // 編み目名のキャッシュ
  bool _hasTriedEasyLocalization = false; // EasyLocalization再試行フラグ

  @override
  void initState() {
    super.initState();
    _loadStitches();
  }

  @override
  void didUpdateWidget(StitchPatternGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    // デバッグモード時のみログ出力
    if (kDebugMode) {
      print('StitchPatternGrid: didUpdateWidget called');
      print('old projectStitches length: ${oldWidget.projectStitches?.length}');
      print('new projectStitches length: ${widget.projectStitches?.length}');
    }

    // プロジェクト固有の編み目設定が変更された場合は再読み込み
    bool shouldReload = false;

    // 参照が同じ場合は内容変更なしとみなす
    if (identical(widget.projectStitches, oldWidget.projectStitches)) {
      if (kDebugMode) {
        print('StitchPatternGrid: projectStitchesの参照が同じ、変更なし');
      }
      return;
    }

    // nullチェック
    if (widget.projectStitches == null && oldWidget.projectStitches != null) {
      shouldReload = true;
      if (kDebugMode) {
        print('StitchPatternGrid: projectStitchesがnullに変更されました');
      }
    } else if (widget.projectStitches != null &&
        oldWidget.projectStitches == null) {
      shouldReload = true;
      if (kDebugMode) {
        print('StitchPatternGrid: projectStitchesがnullから変更されました');
      }
    } else if (widget.projectStitches != null &&
        oldWidget.projectStitches != null) {
      // 長さの比較
      if (widget.projectStitches!.length != oldWidget.projectStitches!.length) {
        shouldReload = true;
        if (kDebugMode) {
          print('StitchPatternGrid: projectStitchesの長さが変更されました');
        }
      } else {
        // 内容の比較（深い比較）
        shouldReload = _hasStitchesChanged(widget.projectStitches!, oldWidget.projectStitches!);
        if (shouldReload && kDebugMode) {
          print('StitchPatternGrid: projectStitchesの内容が変更されました');
        }
      }
    }

    // キーの変更もチェック
    if (widget.key != oldWidget.key) {
      shouldReload = true;
      if (kDebugMode) {
        print('StitchPatternGrid: キーが変更されました');
      }
    }

    // 必要な場合のみ再読み込みを実行
    if (shouldReload) {
      if (kDebugMode) {
        print('StitchPatternGrid: 編み目設定を再読み込みします');
      }
      _loadStitches();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // EasyLocalizationが準備完了するまで待つ
    if (!mounted || !context.mounted) {
      return;
    }
    
    try {
      // EasyLocalizationの準備状況をチェック
      final locale = context.locale;
      if (kDebugMode) {
        print('EasyLocalization ready: ${locale.languageCode}');
      }
      
      _checkPremiumStatusChange();

      // 依存関係が変更された時に編み目設定を再読み込み
      if (_stitches.isEmpty && !_isLoading) {
        _loadStitches();
      }
    } catch (e) {
      if (kDebugMode) {
        print('EasyLocalization not ready yet: $e');
      }
      // 無限ループを防ぐため、一度だけ再試行
      if (!_hasTriedEasyLocalization) {
        _hasTriedEasyLocalization = true;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _hasTriedEasyLocalization = false;
            didChangeDependencies();
          }
        });
      }
    }
  }

  void _checkPremiumStatusChange() {
    // 前回と同じ状態の場合はスキップ
    final isPremium = context.read<SubscriptionProvider>().isPremium;
    final wasPremium = _wasPremium;

    if (wasPremium != null && wasPremium && !isPremium) {
      // プレミアムから解約された場合のみ処理
      if (kDebugMode) {
        print('StitchPatternGrid: プレミアム解約を検知しました');
      }
      _loadStitches(); // 編み目設定を再読み込み
    }

    _wasPremium = isPremium;
  }

  Future<void> _loadStitches() async {
    print('StitchPatternGrid: _loadStitches called');

    try {
      // 編み目設定が変更された場合はキャッシュをクリア
      _stitchNameCache.clear();
      
      // プロジェクト固有の編み目設定がある場合はそれを使用、なければ基本6つの編み目を使用
      if (widget.projectStitches != null &&
          widget.projectStitches!.isNotEmpty) {
        _stitches = List.from(widget.projectStitches!);
        print('プロジェクト固有の編み目設定を使用: ${_stitches.length}個');
      } else {
        // プロジェクト固有の編み目設定がない場合は基本6つの編み目を使用
        _stitches = StitchSettingsService.getDefaultStitches();
        print('基本編み目設定を使用: ${_stitches.length}個');
      }

      // 編み目リストが空の場合はデフォルト設定を使用
      if (_stitches.isEmpty) {
        print('編み目リストが空のため、デフォルト設定を使用します');
        _stitches = StitchSettingsService.getDefaultStitches();
      }

      // デバッグモード時のみ編み目リストの内容をログ出力
      if (kDebugMode) {
        print('読み込まれた編み目リスト:');
        for (int i = 0; i < _stitches.length; i++) {
          final stitch = _stitches[i];
          try {
            // initState中は安全な名前取得を使用
            String stitchName = 'Loading...';
            if (mounted && context.mounted) {
              stitchName = _getStitchName(stitch);
            } else if (stitch is CrochetStitch) {
              stitchName = stitch.nameEn; // デフォルトで英語名を使用
            } else if (stitch is CustomStitch) {
              stitchName = stitch.nameEn; // デフォルトで英語名を使用
            }
            print('  $i: $stitchName (${stitch.runtimeType})');
          } catch (e) {
            print('  $i: エラーで名前を取得できませんでした (${stitch.runtimeType}): $e');
          }
        }
      }

      // UIを一度だけ更新
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('StitchPatternGrid: UI更新完了、編み目数: ${_stitches.length}');
      }
    } catch (e) {
      print('編み目設定読み込みエラー: $e');
      _stitches = StitchSettingsService.getDefaultStitches();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('StitchPatternGrid: エラー後のデフォルト設定使用、編み目数: ${_stitches.length}');
      }
    }
  }

  // 編み目設定の内容が変更されたかチェック
  bool _hasStitchesChanged(List<dynamic> newStitches, List<dynamic> oldStitches) {
    if (newStitches.length != oldStitches.length) return true;
    
    for (int i = 0; i < newStitches.length; i++) {
      final newStitch = newStitches[i];
      final oldStitch = oldStitches[i];
      
      // 型が異なる場合は変更あり
      if (newStitch.runtimeType != oldStitch.runtimeType) return true;
      
      // 編み目の名前を比較
      String newName, oldName;
      try {
        newName = _getStitchName(newStitch);
        oldName = _getStitchName(oldStitch);
      } catch (e) {
        // 名前取得でエラーが発生した場合は変更ありとみなす
        return true;
      }
      
      if (newName != oldName) return true;
    }
    
    return false;
  }

  String _getStitchName(dynamic stitch) {
    // キャッシュをチェック
    if (_stitchNameCache.containsKey(stitch)) {
      return _stitchNameCache[stitch]!;
    }
    
    try {
      // EasyLocalizationが利用可能になるまで待つ
      if (!mounted || !context.mounted) {
        return 'Loading...';
      }
      
      // context.localeが利用可能かチェック
      String locale = 'en'; // デフォルトで英語
      try {
        locale = context.locale.languageCode;
      } catch (e) {
        // EasyLocalizationがまだ初期化されていない場合はデフォルトで英語を使用
        print('EasyLocalization not ready, using default locale: en');
      }
      
      String result;

      if (stitch is CrochetStitch) {
        result = locale == 'ja' ? stitch.nameJa : stitch.nameEn;
      } else if (stitch is CustomStitch) {
        // CustomStitchの場合はgetNameメソッドを使用
        result = stitch.getName(context);
      } else if (stitch is Map<String, String>) {
        result = locale == 'ja' ? stitch['nameJa']! : stitch['nameEn']!;
      } else {
        result = 'Unknown';
      }
      
      // 結果が空文字列の場合はデフォルト値を返す
      if (result.isEmpty) {
        if (stitch is CrochetStitch) {
          result = stitch.nameEn; // 英語名をフォールバックとして使用
        } else if (stitch is CustomStitch) {
          result = stitch.nameEn; // 英語名をフォールバックとして使用
        } else {
          result = 'Unknown';
        }
      }
      
      // キャッシュに保存
      _stitchNameCache[stitch] = result;
      
      // デバッグモード時のみ詳細ログ出力
      if (kDebugMode) {
        print(
            'StitchPatternGrid: _getStitchName - stitch: ${stitch.runtimeType}, result: $result, locale: $locale');
      }
      return result;
    } catch (e) {
      print('StitchPatternGrid: _getStitchName error: $e');
      // エラーが発生した場合のフォールバック
      String fallbackName = 'Unknown';
      if (stitch is CrochetStitch) {
        fallbackName = stitch.nameEn;
      } else if (stitch is CustomStitch) {
        fallbackName = stitch.nameEn;
      }
      
      // フォールバック名もキャッシュに保存
      _stitchNameCache[stitch] = fallbackName;
      return fallbackName;
    }
  }

  @override
  Widget build(BuildContext context) {
    // デバッグモード時のみログ出力
    if (kDebugMode) {
      print('StitchPatternGrid: build called, _stitches.length = ${_stitches.length}');
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '編み方を選択（タップで追加）',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            // 編み目カスタマイズボタン
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () async {
                final isPremium =
                    context.read<SubscriptionProvider>().isPremium;

                if (isPremium) {
                  print('編み目カスタマイズ画面を開きます');

                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => StitchCustomizationScreen(
                        projectStitches: widget.projectStitches,
                        onProjectStitchesChanged:
                            widget.onProjectStitchesChanged,
                      ),
                    ),
                  );

                  if (result == true) {
                    // 編み目設定が変更された場合
                    print('StitchPatternGrid: 編み目設定が変更されました');

                    // 少し待ってから再読み込み（保存処理の完了を待つ）
                    await Future.delayed(const Duration(milliseconds: 500));

                    // 編み目カスタマイズ画面から戻ってきたら再読み込み
                    print('StitchPatternGrid: 編み目設定を再読み込み中...');
                    await _loadStitches();
                    print('StitchPatternGrid: 編み目設定の再読み込み完了');

                    // 編み目設定が変更されたことを通知（緑のポップアップを防ぐため削除）
                    // widget.onStitchSettingsChanged?.call();
                  }
                } else {
                  // 無料プランの場合はアップグレード画面に遷移
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const UpgradeScreen(),
                    ),
                  );
                }
              },
              tooltip: '編み目をカスタマイズ',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // 7つ以上のボタンがある場合はスクロール可能にする
              _stitches.length > 7
                  ? SizedBox(
                      height: _calculateGridHeight(_stitches.length),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _stitches.length,
                        scrollDirection: Axis.vertical,
                        itemBuilder: (context, index) {
                          final stitch = _stitches[index];
                          final isCustomStitch = stitch is CustomStitch;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                widget.onStitchAdded(stitch);
                              },
                              onLongPress: () async {
                                print('編み目ボタンが長押しされました。編み目カスタマイズ画面を開きます');

                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        StitchCustomizationScreen(
                                      projectStitches: widget.projectStitches,
                                      onProjectStitchesChanged:
                                          widget.onProjectStitchesChanged,
                                    ),
                                  ),
                                );

                                if (result == true) {
                                  // 編み目設定が変更された場合
                                  print('StitchPatternGrid: 編み目設定が変更されました');

                                  // 少し待ってから再読み込み（保存処理の完了を待つ）
                                  await Future.delayed(
                                      const Duration(milliseconds: 500));

                                  // 編み目カスタマイズ画面から戻ってきたら再読み込み
                                  print('StitchPatternGrid: 編み目設定を再読み込み中...');
                                  await _loadStitches();
                                  print('StitchPatternGrid: 編み目設定の再読み込み完了');

                                  // 編み目設定が変更されたことを通知（緑のポップアップを防ぐため削除）
                                  // widget.onStitchSettingsChanged?.call();
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: (isCustomStitch
                                          ? stitch.color
                                          : stitch.color)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isCustomStitch
                                        ? stitch.color
                                        : stitch.color,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: stitch.imagePath != null
                                            ? Image.asset(
                                                stitch.imagePath!,
                                                width: 28,
                                                height: 28,
                                                fit: BoxFit.contain,
                                              )
                                            : Text(
                                                _getStitchName(stitch).isNotEmpty 
                                                    ? _getStitchName(stitch).substring(0, 1)
                                                    : '?',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: isCustomStitch
                                                      ? stitch.color
                                                      : stitch.color,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _getStitchName(stitch).isNotEmpty && _getStitchName(stitch).length > 8
                                            ? '${_getStitchName(stitch).substring(0, 6)}...'
                                            : _getStitchName(stitch),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isCustomStitch
                                              ? stitch.color
                                              : stitch.color,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      scrollDirection: Axis.vertical,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _stitches.length,
                      itemBuilder: (context, index) {
                        final stitch = _stitches[index];
                        final isCustomStitch = stitch is CustomStitch;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              widget.onStitchAdded(stitch);
                            },
                            onLongPress: () async {
                              final isPremium = context
                                  .read<SubscriptionProvider>()
                                  .isPremium;

                              if (isPremium) {
                                print('編み目ボタンが長押しされました。編み目カスタマイズ画面を開きます');

                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        StitchCustomizationScreen(
                                      projectStitches: widget.projectStitches,
                                      onProjectStitchesChanged:
                                          widget.onProjectStitchesChanged,
                                    ),
                                  ),
                                );

                                if (result == true) {
                                  // 編み目設定が変更された場合
                                  print('StitchPatternGrid: 編み目設定が変更されました');

                                  // 少し待ってから再読み込み（保存処理の完了を待つ）
                                  await Future.delayed(
                                      const Duration(milliseconds: 500));

                                  // 編み目カスタマイズ画面から戻ってきたら再読み込み
                                  print('StitchPatternGrid: 編み目設定を再読み込み中...');
                                  await _loadStitches();
                                  print('StitchPatternGrid: 編み目設定の再読み込み完了');

                                  // 編み目設定が変更されたことを通知（緑のポップアップを防ぐため削除）
                                  // widget.onStitchSettingsChanged?.call();
                                }
                              } else {
                                // 無料プランの場合はアップグレード画面に遷移
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const UpgradeScreen(),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: (isCustomStitch
                                        ? stitch.color
                                        : stitch.color)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isCustomStitch
                                      ? stitch.color
                                      : stitch.color,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                                                          child: stitch.imagePath != null
                                        ? Image.asset(
                                            stitch.imagePath!,
                                            width: 28,
                                            height: 28,
                                            fit: BoxFit.contain,
                                          )
                                        : Text(
                                            _getStitchName(stitch).isNotEmpty 
                                                ? _getStitchName(stitch).substring(0, 1)
                                                : '?',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isCustomStitch
                                                  ? stitch.color
                                                  : stitch.color,
                                            ),
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _getStitchName(stitch).isNotEmpty && _getStitchName(stitch).length > 8
                                          ? '${_getStitchName(stitch).substring(0, 6)}...'
                                          : _getStitchName(stitch),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isCustomStitch
                                            ? stitch.color
                                            : stitch.color,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ],
    );
  }

  double _calculateGridHeight(int itemCount) {
    // ボタンの数に応じて適切な高さを計算
    // 3列のグリッドで、各ボタンの高さは約80px（childAspectRatio: 1.3を考慮）
    // 行数 = ceil(itemCount / 3)
    final rows = (itemCount / 3).ceil();

    // 各ボタンの高さ（約80px）+ 行間のスペース（10px）+ パディング
    final buttonHeight = 80.0;
    final rowSpacing = 10.0;
    final padding = 24.0; // 上下のパディング

    // 必要な高さを計算
    final calculatedHeight =
        (rows * buttonHeight) + ((rows - 1) * rowSpacing) + padding;

    // 最小高さと最大高さを設定
    final minHeight = 200.0;
    final maxHeight = 400.0;

    return calculatedHeight.clamp(minHeight, maxHeight);
  }
}
