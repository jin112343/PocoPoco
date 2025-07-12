import 'package:flutter/material.dart';
import '../models/crochet_stitch.dart';
import '../screens/stitch_customization_screen.dart';
import '../services/stitch_settings_service.dart';
import 'package:provider/provider.dart';
import '../services/subscription_provider.dart';

class StitchPatternGrid extends StatefulWidget {
  const StitchPatternGrid({
    super.key,
    required this.selectedStitch,
    required this.onStitchSelected,
    required this.onStitchAdded,
    this.projectStitches, // プロジェクト固有の編み目設定
    this.onStitchSettingsChanged, // 編み目設定が変更された時のコールバック
  });

  final CrochetStitch selectedStitch;
  final Function(CrochetStitch) onStitchSelected;
  final Function(CrochetStitch) onStitchAdded;
  final List<dynamic>? projectStitches; // プロジェクト固有の編み目設定
  final VoidCallback? onStitchSettingsChanged; // 編み目設定が変更された時のコールバック

  @override
  State<StitchPatternGrid> createState() => _StitchPatternGridState();
}

class _StitchPatternGridState extends State<StitchPatternGrid> {
  List<dynamic> _stitches = [];
  bool _isLoading = true;
  bool? _wasPremium; // 前回のプレミアム状態を記録

  @override
  void initState() {
    super.initState();
    _loadStitches();
  }

  @override
  void didUpdateWidget(StitchPatternGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    print('StitchPatternGrid: didUpdateWidget called');
    print('old projectStitches length: ${oldWidget.projectStitches?.length}');
    print('new projectStitches length: ${widget.projectStitches?.length}');

    // プロジェクト固有の編み目設定が変更された場合は再読み込み
    bool shouldReload = false;

    // nullチェック
    if (widget.projectStitches == null && oldWidget.projectStitches != null) {
      shouldReload = true;
      print('StitchPatternGrid: projectStitchesがnullに変更されました');
    } else if (widget.projectStitches != null &&
        oldWidget.projectStitches == null) {
      shouldReload = true;
      print('StitchPatternGrid: projectStitchesがnullから変更されました');
    } else if (widget.projectStitches != null &&
        oldWidget.projectStitches != null) {
      // 長さの比較
      if (widget.projectStitches!.length != oldWidget.projectStitches!.length) {
        shouldReload = true;
        print('StitchPatternGrid: projectStitchesの長さが変更されました');
      } else {
        // 内容の比較
        for (int i = 0; i < widget.projectStitches!.length; i++) {
          if (i >= oldWidget.projectStitches!.length) {
            shouldReload = true;
            break;
          }
          final newStitch = widget.projectStitches![i];
          final oldStitch = oldWidget.projectStitches![i];
          if (newStitch.runtimeType != oldStitch.runtimeType ||
              newStitch.name != oldStitch.name) {
            shouldReload = true;
            print('StitchPatternGrid: projectStitchesの内容が変更されました');
            break;
          }
        }
      }
    }

    if (shouldReload) {
      print('StitchPatternGrid: 編み目設定を再読み込みします');
      _loadStitches();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkPremiumStatusChange();
  }

  void _checkPremiumStatusChange() {
    final isPremium = context.read<SubscriptionProvider>().isPremium;
    final wasPremium = _wasPremium;

    if (wasPremium != null && wasPremium && !isPremium) {
      // プレミアムから解約された場合
      print('StitchPatternGrid: プレミアム解約を検知しました');
      _loadStitches(); // 編み目設定を再読み込み
    }

    _wasPremium = isPremium;
  }

  Future<void> _loadStitches() async {
    print('StitchPatternGrid: _loadStitches called');

    try {
      // プロジェクト固有の編み目設定がある場合はそれを使用、なければグローバル設定を使用
      if (widget.projectStitches != null &&
          widget.projectStitches!.isNotEmpty) {
        _stitches = List.from(widget.projectStitches!);
        print('プロジェクト固有の編み目設定を使用: ${_stitches.length}個');
      } else {
        _stitches = await StitchSettingsService.getGlobalStitches();
        print('グローバル編み目設定を使用: ${_stitches.length}個');
      }

      // 編み目リストの内容をログ出力
      print('読み込まれた編み目リスト:');
      for (int i = 0; i < _stitches.length; i++) {
        final stitch = _stitches[i];
        print('  $i: ${stitch.name} (${stitch.runtimeType})');
      }

      // UIを更新
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('編み目設定読み込みエラー: $e');
      _stitches = StitchSettingsService.getDefaultStitches();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        'StitchPatternGrid: build called, _stitches.length = ${_stitches.length}');
    print('StitchPatternGrid: 現在の編み目リスト:');
    for (int i = 0; i < _stitches.length; i++) {
      final stitch = _stitches[i];
      if (stitch is CrochetStitch) {
        print('  $i: ${(stitch as CrochetStitch).name} (CrochetStitch)');
      } else if (stitch is CustomStitch) {
        print('  $i: ${(stitch as CustomStitch).name} (CustomStitch)');
      } else {
        print('  $i: 不明な型 (${stitch.runtimeType})');
      }
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '編み方を選択（タップで追加）',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
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
                                if (stitch is CrochetStitch) {
                                  widget.onStitchAdded(stitch);
                                } else if (isCustomStitch) {
                                  // CustomStitchをCrochetStitchに変換して追加
                                  final crochetStitch =
                                      CrochetStitch.singleCrochet;
                                  widget.onStitchAdded(crochetStitch);
                                }
                              },
                              onLongPress: () async {
                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        StitchCustomizationScreen(
                                      projectStitches: widget.projectStitches,
                                      onProjectStitchesChanged: (newStitches) {
                                        // プロジェクト固有の編み目設定が変更された場合の処理
                                        print(
                                            'StitchPatternGrid: プロジェクト固有の編み目設定が変更されました');
                                        // 少し待ってからコールバックを呼び出し
                                        Future.delayed(
                                            const Duration(milliseconds: 100),
                                            () {
                                          widget.onStitchSettingsChanged
                                              ?.call();
                                        });
                                      },
                                    ),
                                  ),
                                );

                                if (result == true) {
                                  // 編み目設定が変更された場合
                                  print('編み目設定が変更されました');

                                  // 少し待ってから再読み込み（保存処理の完了を待つ）
                                  await Future.delayed(
                                      const Duration(milliseconds: 200));

                                  // 編み目カスタマイズ画面から戻ってきたら再読み込み
                                  print('StitchPatternGrid: 編み目設定を再読み込み中...');
                                  await _loadStitches();
                                  print('StitchPatternGrid: 編み目設定の再読み込み完了');

                                  // 編み目設定が変更されたことを通知
                                  widget.onStitchSettingsChanged?.call();
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
                                                stitch.name.substring(0, 1),
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
                                        stitch.name.length > 8
                                            ? '${stitch.name.substring(0, 6)}...'
                                            : stitch.name,
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
                              if (stitch is CrochetStitch) {
                                widget.onStitchAdded(stitch);
                              } else if (isCustomStitch) {
                                // CustomStitchをCrochetStitchに変換して追加
                                final crochetStitch =
                                    CrochetStitch.singleCrochet;
                                widget.onStitchAdded(crochetStitch);
                              }
                            },
                            onLongPress: () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      StitchCustomizationScreen(
                                    projectStitches: widget.projectStitches,
                                    onProjectStitchesChanged: (newStitches) {
                                      // プロジェクト固有の編み目設定が変更された場合の処理
                                      print(
                                          'StitchPatternGrid: プロジェクト固有の編み目設定が変更されました');
                                      // 少し待ってからコールバックを呼び出し
                                      Future.delayed(
                                          const Duration(milliseconds: 100),
                                          () {
                                        widget.onStitchSettingsChanged?.call();
                                      });
                                    },
                                  ),
                                ),
                              );

                              if (result == true) {
                                // 編み目設定が変更された場合
                                print('編み目設定が変更されました');

                                // 少し待ってから再読み込み（保存処理の完了を待つ）
                                await Future.delayed(
                                    const Duration(milliseconds: 200));

                                // 編み目カスタマイズ画面から戻ってきたら再読み込み
                                print('StitchPatternGrid: 編み目設定を再読み込み中...');
                                await _loadStitches();
                                print('StitchPatternGrid: 編み目設定の再読み込み完了');

                                // 編み目設定が変更されたことを通知
                                widget.onStitchSettingsChanged?.call();
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
                                              stitch.name.substring(0, 1),
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
                                      stitch.name.length > 8
                                          ? '${stitch.name.substring(0, 6)}...'
                                          : stitch.name,
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
