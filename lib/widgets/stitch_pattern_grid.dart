import 'auto_scroll_text.dart';
import 'package:flutter/material.dart';
import '../l10n/script_metrics.dart';
import '../l10n/stitch_names.dart';
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
    required this.onStitchAdded,
    this.projectStitches, // プロジェクト固有の編み目設定
    this.onProjectStitchesChanged, // プロジェクト固有の編み目設定が変更された時のコールバック
    this.isLandscape = false, // 横向きモード
    this.buttonHeight = defaultButtonHeight,
    this.maxVisibleRows = 3,
  });

  static const double defaultButtonHeight = 80;

  // レイアウト用の固定寸法（heightFor と build で同じ値を使う）
  static const double _headerHeight = 36;
  static const double _headerGap = 6;
  static const double _gridPadding = 10;
  static const double _gridSpacing = 8;
  // スクロールできることが分かるよう、次の行を少しだけ見せる割合
  static const double _peekRatio = 0.35;

  /// 縦持ち・横持ちそれぞれの列数
  static int columnsFor({required bool isLandscape}) => isLandscape ? 2 : 3;

  /// このウィジェットが占める高さ。画面側のレイアウト計算に使う
  static double heightFor({
    required int stitchCount,
    required bool isLandscape,
    required double buttonHeight,
    int maxVisibleRows = 3,
  }) {
    return _headerHeight +
        _headerGap +
        _gridPadding * 2 +
        _gridHeight(
          stitchCount: stitchCount,
          isLandscape: isLandscape,
          buttonHeight: buttonHeight,
          maxVisibleRows: maxVisibleRows,
        );
  }

  static double _gridHeight({
    required int stitchCount,
    required bool isLandscape,
    required double buttonHeight,
    required int maxVisibleRows,
  }) {
    final columns = columnsFor(isLandscape: isLandscape);
    final rows = stitchCount <= 0 ? 1 : (stitchCount / columns).ceil();
    if (rows <= maxVisibleRows) {
      return rows * buttonHeight + (rows - 1) * _gridSpacing;
    }
    return maxVisibleRows * buttonHeight +
        maxVisibleRows * _gridSpacing +
        buttonHeight * _peekRatio;
  }

  final Function(dynamic) onStitchAdded;
  final List<dynamic>? projectStitches; // プロジェクト固有の編み目設定
  final Function(List<dynamic>)?
      onProjectStitchesChanged; // プロジェクト固有の編み目設定が変更された時のコールバック
  final bool isLandscape; // 横向きモード

  /// 編み方ボタン1つの高さ
  final double buttonHeight;

  /// スクロールなしで見せる最大行数（これを超えるとグリッド内でスクロール）
  final int maxVisibleRows;

  @override
  State<StitchPatternGrid> createState() => _StitchPatternGridState();
}

class _StitchPatternGridState extends State<StitchPatternGrid> {
  static const double _horizontalNameMaxScale = 1.1;

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
        shouldReload = _hasStitchesChanged(
            widget.projectStitches!, oldWidget.projectStitches!);
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
  bool _hasStitchesChanged(
      List<dynamic> newStitches, List<dynamic> oldStitches) {
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
      Colors.blue, // 0: 青
      Colors.grey, // 1: グレー
      Colors.green, // 2: 緑
      Colors.orange, // 3: オレンジ
      Colors.purple, // 4: 紫
      Colors.red, // 5: 赤
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
          result = localizedStitchName(context,
              nameJa: stitch['nameJa']!, nameEn: stitch['nameEn']!);
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
    final gridHeight = StitchPatternGrid._gridHeight(
      stitchCount: _stitches.length,
      isLandscape: widget.isLandscape,
      buttonHeight: widget.buttonHeight,
      maxVisibleRows: widget.maxVisibleRows,
    );

    if (_isLoading) {
      // 読み込み中も同じ高さを確保して、表示後にレイアウトが動かないようにする
      return SizedBox(
        height: StitchPatternGrid._headerHeight +
            StitchPatternGrid._headerGap +
            StitchPatternGrid._gridPadding * 2 +
            gridHeight,
      );
    }

    final columns =
        StitchPatternGrid.columnsFor(isLandscape: widget.isLandscape);
    final rows = (_stitches.length / columns).ceil();
    final scrollable = rows > widget.maxVisibleRows;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // ボタン内の文字が端末の文字サイズ設定ではみ出さないよう上限を設ける
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: StitchPatternGrid._headerHeight,
            child: Row(
              children: [
                Expanded(
                  child: AutoScrollText(
                    tr('select_stitch_hint'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                // 編み目カスタマイズボタン
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: StitchPatternGrid._headerHeight,
                  ),
                  onPressed: _openCustomization,
                  tooltip: tr('customize_stitches_tooltip'),
                ),
              ],
            ),
          ),
          const SizedBox(height: StitchPatternGrid._headerGap),
          Container(
            padding: const EdgeInsets.all(StitchPatternGrid._gridPadding),
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
            child: SizedBox(
              height: gridHeight,
              child: GridView.builder(
                padding: EdgeInsets.zero,
                physics:
                    scrollable ? null : const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: widget.buttonHeight,
                  crossAxisSpacing: StitchPatternGrid._gridSpacing,
                  mainAxisSpacing: StitchPatternGrid._gridSpacing,
                ),
                itemCount: _stitches.length,
                itemBuilder: (context, index) =>
                    _buildStitchButton(_stitches[index], index),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStitchButton(dynamic stitch, int index) {
    final buttonColor = _getStitchColorByIndex(index);
    final stitchName = _getStitchName(stitch);
    // 縦持ちでは「記号の下に名前」にして、名前にボタンの幅いっぱいを使う
    // （記号の横に置くと幅が狭く、短い名前でも途中で折り返してしまう）。
    // 高さに余裕があれば名前は2行、なければ1行（収まらない名前は横に流れる）
    final vertical = !widget.isLandscape && widget.buttonHeight >= 56;
    final nameLines = widget.buttonHeight >= 76 ? 2 : 1;

    // ラベルは中のTextから、押す操作はInkWellから読み上げに伝わる
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('stitch_button_$index'),
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            widget.onStitchAdded(stitch);
          },
          onLongPress: _openCustomization,
          child: Ink(
            decoration: BoxDecoration(
              color: buttonColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: buttonColor,
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: vertical
                  ? _buildVerticalContent(stitch, stitchName, buttonColor,
                      nameLines: nameLines)
                  : _buildHorizontalContent(stitch, stitchName, buttonColor),
            ),
          ),
        ),
      ),
    );
  }

  static const double _nameFontSize = 13;
  // 欧文・日本語での行の高さ（背の高い文字の言語では scriptLineHeight で広げる）
  static const double _nameBaseLineHeight = 1.15;
  // 名前が少しだけ収まらない時に、ここまで文字を縮める（それでも無理なら横に流す）
  static const double _nameMinScale = 0.8;

  /// 画像の下に名前を置くレイアウト。収まらない場合は全体を縮小する
  Widget _buildVerticalContent(
      dynamic stitch, String stitchName, Color buttonColor,
      {required int nameLines}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final nameHeight =
            MediaQuery.textScalerOf(context).scale(_nameFontSize) *
                scriptLineHeight(context, _nameBaseLineHeight) *
                nameLines;
        // 高さが低いボタンでは、名前の行を確保した残りに記号を収める
        final imageSize =
            (constraints.maxHeight - nameHeight - 3).clamp(24.0, 38.0);
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStitchImage(stitch, stitchName, buttonColor,
                    size: imageSize),
                const SizedBox(height: 3),
                // 名前の欄はいつも同じ行数ぶん確保して、名前の長さが違うボタン同士でも
                // 記号の位置が揃うようにする。収まらない名前は自動で横に流す
                SizedBox(
                  height: nameHeight,
                  child: Center(
                    child: AutoScrollText(
                      stitchName,
                      style: TextStyle(
                        fontSize: _nameFontSize,
                        height: scriptLineHeight(context, _nameBaseLineHeight),
                        fontWeight: FontWeight.w700,
                        color: buttonColor,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: nameLines,
                      minScale: _nameMinScale,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 画像の横に名前を置くレイアウト（高さが低いボタン・横持ち用）
  Widget _buildHorizontalContent(
      dynamic stitch, String stitchName, Color buttonColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStitchImage(stitch, stitchName, buttonColor, size: 36),
        const SizedBox(width: 6),
        Flexible(
          // 画像の横は幅が狭いので、名前が途中で切れないよう拡大を抑える。
          // それでも収まらない名前は自動で横に流す
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: _horizontalNameMaxScale,
            child: AutoScrollText(
              stitchName,
              style: TextStyle(
                fontSize: _nameFontSize,
                height: scriptLineHeight(context, _nameBaseLineHeight),
                fontWeight: FontWeight.w700,
                color: buttonColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              minScale: _nameMinScale,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStitchImage(
    dynamic stitch,
    String stitchName,
    Color buttonColor, {
    required double size,
  }) {
    final fallback = Text(
      stitchName.isNotEmpty ? stitchName.substring(0, 1) : '?',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: buttonColor,
      ),
      textScaler: TextScaler.noScaling,
    );

    return Container(
      width: size,
      height: size,
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
                  width: size - 10,
                  height: size - 10,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => fallback,
                ),
              )
            : fallback,
      ),
    );
  }
}
