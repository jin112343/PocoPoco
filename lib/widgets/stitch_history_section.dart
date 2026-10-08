import 'auto_scroll_text.dart';
import 'package:flutter/material.dart';
import '../l10n/stitch_names.dart';
import '../models/crochet_stitch.dart';
import '../models/project_markers.dart';
import 'package:easy_localization/easy_localization.dart';

class StitchHistorySection extends StatefulWidget {
  const StitchHistorySection({
    super.key,
    required this.stitchHistory,
    required this.currentStitches,
    this.onStitchRemoved,
    this.currentRow,
    this.markers = ProjectMarkers.none,
  });

  final List<Map<String, dynamic>> stitchHistory;
  final List<dynamic> currentStitches;
  final Function(int)? onStitchRemoved; // 編み目削除コールバック

  /// いま編んでいる段（見出しを強調表示する）
  final int? currentRow;

  /// くり返し編みの目印（確認の段・模様の始まりに印を付ける）
  final ProjectMarkers markers;

  @override
  State<StitchHistorySection> createState() => _StitchHistorySectionState();
}

class _StitchHistorySectionState extends State<StitchHistorySection> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _rowKeys = {};

  // 編み目の列の標準の高さ（記号＋番号）
  static const double _stripHeight = 80;
  // 履歴の欄が低い小さな画面では、記号の列を縮めて1列ぶんが切れずに見えるようにする
  double _stripScale = 1;
  final Map<int, ScrollController> _horizontalScrollControllers = {};
  int _lastMaxRow = 0;
  int _lastHistoryLength = 0;
  bool _didInitialScroll = false;

  @override
  void initState() {
    super.initState();
    _lastMaxRow = _getMaxRow();
    _lastHistoryLength = widget.stitchHistory.length;
    // 既存プロジェクトを開いた直後は、いま編んでいる段（一番下）の
    // 右端（最後に編んだ目）を表示する。続きがすぐ分かるようにするため
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_didInitialScroll) {
        _didInitialScroll = true;
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
        _scrollLatestRowToEnd(animate: false);
      }
    });
  }

  @override
  void didUpdateWidget(StitchHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);

    final currentMaxRow = _getMaxRow();
    final currentHistoryLength = widget.stitchHistory.length;
    // 注意: 親は同じListインスタンスをin-placeで変更して渡すため、
    // oldWidget.stitchHistoryは常にwidget.stitchHistoryと同一で比較できない。
    // 前回のビルドでState側に記録した長さ（_lastHistoryLength）と比較する。
    final oldHistoryLength = _lastHistoryLength;

    // 段が削除された場合の処理を追加
    if (currentHistoryLength < oldHistoryLength) {
      // 段削除後のクリーンアップとUI更新
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cleanupRemovedRows();
        // 強制的にUIを更新
        if (mounted) {
          setState(() {});
        }
      });
    }

    // 新しい段が開始された場合（段完成時）のみ自動スクロール
    if (currentMaxRow > _lastMaxRow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToLatestRow();
      });
    } else if (currentHistoryLength > oldHistoryLength) {
      // 編み目が追加された場合は、その段の右端（新しい編み目）まで滑らかにスクロール
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ensureLatestRowVisible();
          _scrollLatestRowToEnd(animate: true);
        }
      });
    }

    // 削除された段のキーとコントローラーをクリーンアップ
    _cleanupRemovedRows();

    _lastMaxRow = currentMaxRow;
    _lastHistoryLength = currentHistoryLength;
  }

  /// 全体の目数（段の開始マーカーは数えない）
  int _totalStitchCount() =>
      widget.stitchHistory.where((e) => e['position'] != 0).length;

  int _getMaxRow() {
    try {
      if (widget.stitchHistory.isEmpty) return 0;
      return widget.stitchHistory
          .map((e) => e['row'] as int)
          .reduce((a, b) => a > b ? a : b);
    } catch (e) {
      // エラーが発生した場合は0を返す
      return 0;
    }
  }

  // 削除された段のキーとコントローラーをクリーンアップ
  void _cleanupRemovedRows() {
    // 現在存在する段番号のセットを作成
    final currentRows =
        widget.stitchHistory.map((e) => e['row'] as int).toSet();

    // _rowKeysから削除された段のキーを削除
    final keysToRemove =
        _rowKeys.keys.where((row) => !currentRows.contains(row)).toList();
    for (final row in keysToRemove) {
      _rowKeys.remove(row);
    }

    // _horizontalScrollControllersから削除された段のコントローラーを削除
    final controllersToRemove = _horizontalScrollControllers.keys
        .where((row) => !currentRows.contains(row))
        .toList();
    for (final row in controllersToRemove) {
      final controller = _horizontalScrollControllers.remove(row);
      controller?.dispose();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final controller in _horizontalScrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void scrollToRow(int row) {
    try {
      if (_rowKeys.containsKey(row)) {
        final key = _rowKeys[row]!;
        final context = key.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    } catch (e) {
      // エラーが発生した場合は無視（段が削除された可能性）
    }
  }

  void _scrollToLatestRow() {
    try {
      if (widget.stitchHistory.isEmpty) return;

      // 最新の段を取得
      final latestRow = widget.stitchHistory.last['row'] as int;
      final key = _rowKeys[latestRow];

      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.0, // 画面の上端に合わせる
        );
      }
    } catch (e) {
      // エラーが発生した場合は無視（段が削除された可能性）
    }
  }

  /// 前の段を見返している途中で編み目を追加しても、編んでいる段が見えるようにする
  /// （すでに見えている場合は動かさない）
  void _ensureLatestRowVisible() {
    try {
      if (widget.stitchHistory.isEmpty) return;
      final latestRow = widget.stitchHistory.last['row'] as int;
      final rowContext = _rowKeys[latestRow]?.currentContext;
      if (rowContext == null) return;
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    } catch (e) {
      // スクロール中にエラーが発生した場合は無視
    }
  }

  /// 最新段の横スクロールを右端（最後に追加された編み目）まで移動する
  void _scrollLatestRowToEnd({required bool animate}) {
    try {
      if (widget.stitchHistory.isEmpty) return;

      final latestRow = widget.stitchHistory.last['row'] as int;
      final controller = _horizontalScrollControllers[latestRow];
      if (controller == null || !controller.hasClients) return;

      final target = controller.position.maxScrollExtent;
      if (target <= controller.offset) return;

      if (animate) {
        controller.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        controller.jumpTo(target);
      }
    } catch (e) {
      // スクロール中にエラーが発生した場合は無視
    }
  }

  // ボタンの位置に基づいた固定色を取得（stitch_pattern_grid.dartと同じロジック）
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

  // 編み目のインデックスを取得
  int _getStitchIndexInCurrentList(dynamic stitchObj) {
    try {
      final index = widget.currentStitches.indexWhere((s) {
        if (stitchObj is StitchDef && s is StitchDef) {
          return s.nameJa == stitchObj.nameJa &&
              s.runtimeType == stitchObj.runtimeType;
        }
        return false;
      });
      return index >= 0 ? index : 0; // 見つからない場合は0を返す
    } catch (e) {
      return 0;
    }
  }

  ScrollController _getHorizontalScrollController(int row) {
    return _horizontalScrollControllers.putIfAbsent(row, () {
      return ScrollController();
    });
  }

  String _getStitchName(dynamic stitch) {
    try {
      if (stitch is StitchDef) {
        return stitch.getName(context);
      } else if (stitch is Map<String, String>) {
        return localizedStitchName(context,
            nameJa: stitch['nameJa']!, nameEn: stitch['nameEn']!);
      } else {
        return 'Unknown';
      }
    } catch (e) {
      // エラー時は日本語名を返す
      if (stitch is StitchDef) {
        return stitch.nameJa;
      }
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 各段は固定の高さで並べているため、文字サイズ設定による拡大に上限を設ける
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Builder(builder: (context) => _buildSection(context, isDarkMode)),
    );
  }

  Widget _buildSection(BuildContext context, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: AutoScrollText(
                          tr('stitch_history'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: AutoScrollText(
                          tr('total_stitches',
                              namedArgs: {'count': '${_totalStitchCount()}'}),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.stitchHistory.isNotEmpty)
                  Icon(
                    Icons.swipe,
                    size: 18,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey,
                  ),
              ],
            ),
          ),
          Expanded(
            child: widget.stitchHistory.isEmpty
                ? Center(
                    // 表示領域が狭い端末でもはみ出さないよう、収まらない時は縮小する
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timeline,
                              size: 56,
                              color: isDarkMode
                                  ? Colors.grey[600]
                                  : const Color(0xFFE0E0E0),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              tr('history_empty_message'),
                              style: TextStyle(
                                color:
                                    isDarkMode ? Colors.grey[400] : Colors.grey,
                                fontSize: 18,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _stripScale = constraints.hasBoundedHeight
                            ? (constraints.maxHeight / _stripHeight)
                                .clamp(0.6, 1.0)
                            : 1.0;
                        return SingleChildScrollView(
                          controller: _scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _buildHistoryItems(),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHistoryItems() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final groupedHistory = <int, List<Map<String, dynamic>>>{};

    // 段ごとにグループ化
    for (final stitchData in widget.stitchHistory) {
      final row = stitchData['row'] as int;
      groupedHistory.putIfAbsent(row, () => []).add(stitchData);
    }

    final List<Widget> items = [];

    for (final row in groupedHistory.keys.toList()..sort()) {
      final rowStitches = groupedHistory[row]!;

      // position順にソート（昇順：1, 2, 3...）
      rowStitches.sort((a, b) {
        final posA = a['position'] as int;
        final posB = b['position'] as int;
        return posA.compareTo(posB);
      });

      // 各段にキーを割り当て（既存のキーを再利用してウィジェットの再生成を防ぐ）
      _rowKeys.putIfAbsent(row, () => GlobalKey());

      // 段のヘッダー＋編み目を縦並び
      // キーには編み目数を含めない（含めると編み目追加のたびに段全体が
      // 再生成され、横スクロール位置が左端に戻ってしまう）
      items.add(
        Dismissible(
          key: ValueKey(
              'row_${row}_${rowStitches.first['timestamp']?.millisecondsSinceEpoch ?? row}'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
              size: 30,
            ),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(tr('delete_row_title')),
                content:
                    Text(tr('delete_row_message', namedArgs: {'row': '$row'})),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(tr('cancel')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(tr('delete'),
                        style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) {
            // 削除完了を通知（データ更新は親ウィジェットで一元管理）
            if (widget.onStitchRemoved != null) {
              widget.onStitchRemoved!(row);
            }
          },
          child: Container(
            key: _rowKeys[row],
            // 縮めている時は、最新の段の下に余白を残さず記号の列を見せる
            margin: EdgeInsets.only(bottom: _stripScale < 1 ? 4 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => scrollToRow(row),
                  child: _buildRowLabel(row, isDarkMode),
                ),
                SizedBox(height: _stripScale < 1 ? 6 : 12),
                // この段の編み目を横スクロール可能に表示
                if (rowStitches.any((stitch) => stitch['position'] != 0))
                  SizedBox(
                    height: _stripHeight * _stripScale, // 固定高さで横スクロール
                    child: RepaintBoundary(
                      child: SingleChildScrollView(
                        controller: _getHorizontalScrollController(row),
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.hardEdge,
                        physics: const ClampingScrollPhysics(),
                        child: Row(
                          children: rowStitches
                              .where((stitch) =>
                                  stitch['position'] != 0) // 段開始フラグの編み目を除外
                              .map((stitchData) {
                            final dynamic stitchObj = _findStitchInCurrentList(
                                stitchData['stitch'], widget.currentStitches);
                            final position = stitchData['position'] as int;
                            final stitchIndex =
                                _getStitchIndexInCurrentList(stitchObj);
                            final stitchColor =
                                _getStitchColorByIndex(stitchIndex);

                            return Padding(
                              key: ValueKey(
                                  'stitch_${row}_${position}_${stitchData['timestamp']?.millisecondsSinceEpoch ?? '${row}_$position'}'),
                              padding: const EdgeInsets.only(right: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: (stitchObj is StitchDef &&
                                                stitchObj.isOval
                                            ? 56
                                            : 48) *
                                        _stripScale,
                                    height: 48 * _stripScale,
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? const Color(0xFF3D3D3D)
                                          : Colors.white,
                                      borderRadius: stitchObj is StitchDef &&
                                              stitchObj.isOval
                                          ? BorderRadius.circular(24)
                                          : BorderRadius.circular(10),
                                      border: Border.all(
                                        color: stitchColor,
                                        width: 3,
                                      ),
                                    ),
                                    child: Center(
                                      child: stitchObj is StitchDef &&
                                              stitchObj.imagePath != null
                                          ? Container(
                                              width: 36 * _stripScale,
                                              height: 36 * _stripScale,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              padding: const EdgeInsets.all(2),
                                              child: Image.asset(
                                                stitchObj.imagePath!,
                                                width: 32 * _stripScale,
                                                height: 32 * _stripScale,
                                                fit: BoxFit.contain,
                                              ),
                                            )
                                          : Text(
                                              _getStitchName(stitchObj)
                                                  .substring(0, 1),
                                              style: TextStyle(
                                                fontSize: 20 * _stripScale,
                                                fontWeight: FontWeight.bold,
                                                color: stitchColor,
                                              ),
                                            ),
                                    ),
                                  ),
                                  SizedBox(height: _stripScale < 1 ? 2 : 4),
                                  Text(
                                    '$position',
                                    // 縮めている時は、番号も列の高さに収まる大きさにする
                                    textScaler: _stripScale < 1
                                        ? TextScaler.noScaling
                                        : null,
                                    style: TextStyle(
                                      fontSize: _stripScale < 1 ? 11 : 14,
                                      color: isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  )
                else
                  // 空の段の場合の表示
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.grey.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 24,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tr('add_stitch_prompt'),
                          style: TextStyle(
                            fontSize: 16,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return items;
  }

  /// 段の見出し。編んでいる段は濃い色で強調し、目印のある段には印を付ける
  Widget _buildRowLabel(int row, bool isDarkMode) {
    final isCurrent = row == widget.currentRow;
    final isCheckRow = widget.markers.isCheckRow(row);
    final repeatNumber = widget.markers.repeatNumberStartingAt(row);

    final Color background;
    final Color foreground;
    if (isCurrent) {
      background =
          isDarkMode ? const Color(0xFFEC407A) : const Color(0xFFAD1457);
      foreground = Colors.white;
    } else {
      background =
          isDarkMode ? const Color(0xFF6A1B45) : const Color(0xFFF8BBD9);
      foreground = isDarkMode ? Colors.white : const Color(0xFFAD1457);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            tr('row_label', namedArgs: {'row': '$row'}),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: foreground,
            ),
          ),
        ),
        if (isCheckRow) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.flag,
            key: ValueKey('row_check_flag_$row'),
            size: 20,
            color:
                isDarkMode ? const Color(0xFFFFD54F) : const Color(0xFFF57F17),
            semanticLabel: tr('marker_check_row_semantics'),
          ),
        ],
        if (repeatNumber != null) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.repeat,
            size: 16,
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
          ),
          const SizedBox(width: 2),
          Flexible(
            child: AutoScrollText(
              tr('marker_repeat_row_badge',
                  namedArgs: {'current': '$repeatNumber'}),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 履歴のstitch情報を現在のボタンリストから探す
  dynamic _findStitchInCurrentList(
      dynamic stitch, List<dynamic> currentStitches) {
    String? nameJa;
    String? nameEn;

    if (stitch is StitchDef) {
      nameJa = stitch.nameJa;
      nameEn = stitch.nameEn;
    } else if (stitch is Map) {
      nameJa = stitch['nameJa'] as String?;
      nameEn = stitch['nameEn'] as String?;
    } else if (stitch is String) {
      nameJa = stitch;
      nameEn = stitch;
    }

    // 現在のボタンリストから一致するものを探す（日本語名または英語名で一致）
    final found = currentStitches.firstWhere(
      (s) {
        if (s is StitchDef) {
          return s.nameJa == nameJa || s.nameEn == nameEn;
        }
        return false;
      },
      orElse: () {
        // CustomStitchの場合はそのまま返す（画像パス情報を保持）
        if (stitch is CustomStitch) {
          return stitch;
        }
        // MapからCustomStitchを生成
        if (stitch is Map &&
            (stitch['type'] == 'custom' || stitch['imagePath'] != null)) {
          final imagePathRaw = stitch['imagePath'] as String?;
          final imagePath = (imagePathRaw == null || imagePathRaw.isEmpty)
              ? null
              : imagePathRaw;
          return CustomStitch(
            nameJa: stitch['nameJa'] ?? stitch['name'] ?? nameJa ?? '',
            nameEn: stitch['nameEn'] ?? stitch['name'] ?? nameEn ?? '',
            imagePath: imagePath,
            color:
                stitch['color'] != null ? Color(stitch['color']) : Colors.pink,
            isOval: stitch['isOval'] ?? false,
          );
        }
        // デフォルト
        return CrochetStitch.singleCrochet;
      },
    );
    return found;
  }
}
