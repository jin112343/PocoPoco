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
    this.isLandscape = false, // 横向きモード
  });

  final CrochetStitch selectedStitch;
  final Function(CrochetStitch) onStitchSelected;
  final Function(dynamic) onStitchAdded;
  final List<dynamic>? projectStitches; // プロジェクト固有の編み目設定
  final VoidCallback? onStitchSettingsChanged; // 編み目設定が変更された時のコールバック
  final Function(List<dynamic>)?
      onProjectStitchesChanged; // プロジェクト固有の編み目設定が変更された時のコールバック
  final bool isLandscape; // 横向きモード

  @override
  State<StitchPatternGrid> createState() => _StitchPatternGridState();
}

class _StitchPatternGridState extends State<StitchPatternGrid> {
  List<dynamic> _stitches = [];
  bool _isLoading = true;
  bool? _wasPremium; // 前回のプレミアム状態を記録
  final Map<dynamic, String> _stitchNameCache = {}; // 編み目名のキャッシュ
  bool _hasTriedEasyLocalization = false; // EasyLocalization再試行フラグ

  @override
  void initState() {
    super.initState();
    _loadStitches();
  }

  @override
  void didUpdateWidget(StitchPatternGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    // プロジェクト固有の編み目設定が変更された場合は再読み込み
    bool shouldReload = false;

    // 参照が同じ場合は内容変更なしとみなす
    if (identical(widget.projectStitches, oldWidget.projectStitches)) {
      return;
    }

    // nullチェック
    if (widget.projectStitches == null && oldWidget.projectStitches != null) {
      shouldReload = true;
    } else if (widget.projectStitches != null &&
        oldWidget.projectStitches == null) {
      shouldReload = true;
    } else if (widget.projectStitches != null &&
        oldWidget.projectStitches != null) {
      // 長さの比較
      if (widget.projectStitches!.length != oldWidget.projectStitches!.length) {
        shouldReload = true;
      } else {
        // 内容の比較（深い比較）
        shouldReload = _hasStitchesChanged(widget.projectStitches!, oldWidget.projectStitches!);
      }
    }

    // キーの変更もチェック
    if (widget.key != oldWidget.key) {
      shouldReload = true;
    }

    // 必要な場合のみ再読み込みを実行
    if (shouldReload) {
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

      // 依存関係が変更された時（特にlocale変更時）に名前キャッシュをクリアして再描画
      if (_stitches.isNotEmpty) {
        _stitchNameCache.clear();
        if (mounted) {
          setState(() {});
        }
      }

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
            setState(() {});
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
      _loadStitches(); // 編み目設定を再読み込み
    }

    _wasPremium = isPremium;
  }

  Future<void> _loadStitches() async {

    try {
      // 編み目設定が変更された場合はキャッシュをクリア
      _stitchNameCache.clear();

      // プロジェクト固有の編み目設定がある場合はそれを使用、なければ基本6つの編み目を使用
      if (widget.projectStitches != null &&
          widget.projectStitches!.isNotEmpty) {
        _stitches = List.from(widget.projectStitches!);
      } else {
        // プロジェクト固有の編み目設定がない場合は基本6つの編み目を使用
        _stitches = StitchSettingsService.getDefaultStitches();
      }

      // 編み目リストが空の場合はデフォルト設定を使用
      if (_stitches.isEmpty) {
        _stitches = StitchSettingsService.getDefaultStitches();
      }

      // UIを一度だけ更新
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _stitches = StitchSettingsService.getDefaultStitches();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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

  // ボタンの位置に基づいた固定色を取得
  Color _getStitchColorByIndex(int index) {
    final colors = [
      Colors.blue,    // 0: 青
      Colors.grey,    // 1: グレー
      Colors.green,   // 2: 緑
      Colors.orange,  // 3: オレンジ
      Colors.purple,  // 4: 紫
      Colors.red,     // 5: 赤
    ];
    return colors[index % colors.length];
  }

  String _getStitchName(dynamic stitch) {
    // キャッシュをチェック
    if (_stitchNameCache.containsKey(stitch)) {
      return _stitchNameCache[stitch]!;
    }

    try {
      // EasyLocalizationが利用可能になるまで待つ
      if (!mounted || !context.mounted) {
        // コンテキストが利用できない場合はデフォルトで日本語を返す
        if (stitch is StitchDef) {
          return stitch.nameJa;
        }
        return 'Loading...';
      }

      String result;

      if (stitch is StitchDef) {
        // getNameメソッドを使用（context.localeを使用）
        result = stitch.getName(context);
      } else if (stitch is Map<String, String>) {
        try {
          final locale = context.locale.languageCode;
          result = locale == 'ja' ? stitch['nameJa']! : stitch['nameEn']!;
        } catch (e) {
          result = stitch['nameJa'] ?? stitch['nameEn'] ?? 'Unknown';
        }
      } else {
        result = 'Unknown';
      }

      // 結果が空文字列の場合はデフォルト値を返す
      if (result.isEmpty) {
        if (stitch is StitchDef) {
          result = stitch.nameJa; // 日本語名をフォールバックとして使用
        } else {
          result = 'Unknown';
        }
      }

      // キャッシュに保存
      _stitchNameCache[stitch] = result;

      return result;
    } catch (e) {
      // エラーが発生した場合のフォールバック（日本語優先）
      String fallbackName = 'Unknown';
      if (stitch is StitchDef) {
        fallbackName = stitch.nameJa;
      }

      // フォールバック名もキャッシュに保存
      _stitchNameCache[stitch] = fallbackName;
      return fallbackName;
    }
  }

  // 横向き時の列数を取得
  int _getCrossAxisCount() {
    return widget.isLandscape ? 2 : 3;
  }

  // 横向き時のアスペクト比を取得
  double _getChildAspectRatio() {
    return widget.isLandscape ? 2.0 : 1.3;
  }

  /// 編み目カスタマイズ画面を開く（プレミアム未加入の場合はアップグレード画面へ）
  Future<void> _openCustomization() async {
    final isPremium = context.read<SubscriptionProvider>().isPremium;

    if (!isPremium) {
      // 無料プランの場合はアップグレード画面に遷移
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const UpgradeScreen(),
        ),
      );
      return;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StitchCustomizationScreen(
          projectStitches: widget.projectStitches,
          onProjectStitchesChanged: widget.onProjectStitchesChanged,
        ),
      ),
    );

    if (result == true && mounted) {
      // 編み目設定が変更された場合
      // 少し待ってから再読み込み（保存処理の完了を待つ）
      await Future.delayed(const Duration(milliseconds: 500));

      // 編み目カスタマイズ画面から戻ってきたら再読み込み
      await _loadStitches();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final crossAxisCount = _getCrossAxisCount();
    final childAspectRatio = _getChildAspectRatio();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                tr('select_stitch_hint'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 編み目カスタマイズボタン
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: _openCustomization,
              tooltip: tr('customize_stitches_tooltip'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.pink.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          // 7つ以上のボタンがある場合はスクロール可能にする
          child: _stitches.length > 7
              ? SizedBox(
                  height:
                      _calculateGridHeight(_stitches.length, crossAxisCount),
                  child: _buildStitchGrid(
                    crossAxisCount,
                    childAspectRatio,
                    scrollable: true,
                  ),
                )
              : _buildStitchGrid(
                  crossAxisCount,
                  childAspectRatio,
                  scrollable: false,
                ),
        ),
      ],
    );
  }

  Widget _buildStitchGrid(
    int crossAxisCount,
    double childAspectRatio, {
    required bool scrollable,
  }) {
    return GridView.builder(
      shrinkWrap: !scrollable,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      scrollDirection: Axis.vertical,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _stitches.length,
      itemBuilder: (context, index) =>
          _buildStitchButton(_stitches[index], index),
    );
  }

  Widget _buildStitchButton(dynamic stitch, int index) {
    final buttonColor = _getStitchColorByIndex(index);
    final stitchName = _getStitchName(stitch);
    final fallbackInitial = stitchName.isNotEmpty ? stitchName.substring(0, 1) : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          widget.onStitchAdded(stitch);
        },
        onLongPress: _openCustomization,
        child: Container(
          decoration: BoxDecoration(
            color: buttonColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: buttonColor,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: stitch.imagePath != null
                      ? Padding(
                          padding: const EdgeInsets.all(3),
                          child: Image.asset(
                            stitch.imagePath!,
                            width: 26,
                            height: 26,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Text(
                                fallbackInitial,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: buttonColor,
                                ),
                              );
                            },
                          ),
                        )
                      : Text(
                          fallbackInitial,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: buttonColor,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  stitchName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: buttonColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateGridHeight(int itemCount, int crossAxisCount) {
    // ボタンの数に応じて適切な高さを計算
    // 行数 = ceil(itemCount / crossAxisCount)
    final rows = (itemCount / crossAxisCount).ceil();

    // 各ボタンの高さ（横向きの場合は小さめ）+ 行間のスペース（10px）+ パディング
    final buttonHeight = widget.isLandscape ? 60.0 : 80.0;
    const rowSpacing = 10.0;
    const padding = 24.0; // 上下のパディング

    // 必要な高さを計算
    final calculatedHeight =
        (rows * buttonHeight) + ((rows - 1) * rowSpacing) + padding;

    // 最小高さと最大高さを設定（横向きの場合は調整）
    final minHeight = widget.isLandscape ? 150.0 : 200.0;
    final maxHeight = widget.isLandscape ? 300.0 : 400.0;

    return calculatedHeight.clamp(minHeight, maxHeight);
  }
}
