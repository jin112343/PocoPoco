import 'package:flutter/material.dart';
import '../models/crochet_stitch.dart';
import 'package:easy_localization/easy_localization.dart';

class StitchHistorySection extends StatefulWidget {
  const StitchHistorySection({
    super.key,
    required this.stitchHistory,
    required this.currentStitches,
    this.onRowTap,
    this.onRowCompleted,
    this.onStitchRemoved,
    this.currentRow,
    this.currentStitchCount,
  });

  final List<Map<String, dynamic>> stitchHistory;
  final List<dynamic> currentStitches;
  final Function(int)? onRowTap;
  final Function(int)? onRowCompleted;
  final Function(int)? onStitchRemoved; // 編み目削除コールバック

  final int? currentRow;
  final int? currentStitchCount;

  @override
  State<StitchHistorySection> createState() => _StitchHistorySectionState();
}

class _StitchHistorySectionState extends State<StitchHistorySection> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _rowKeys = {};
  final Map<int, ScrollController> _horizontalScrollControllers = {};
  int _lastMaxRow = 0;

  @override
  void initState() {
    super.initState();
    _lastMaxRow = _getMaxRow();
  }

  @override
  void didUpdateWidget(StitchHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);

    final currentMaxRow = _getMaxRow();
    final currentHistoryLength = widget.stitchHistory.length;
    final oldHistoryLength = oldWidget.stitchHistory.length;

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
        if (widget.onRowCompleted != null) {
          widget.onRowCompleted!(currentMaxRow);
        }
      });
    }

    // 削除された段のキーとコントローラーをクリーンアップ
    _cleanupRemovedRows();

    _lastMaxRow = currentMaxRow;
  }

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
    final currentRows = widget.stitchHistory
        .map((e) => e['row'] as int)
        .toSet();

    // _rowKeysから削除された段のキーを削除
    final keysToRemove = _rowKeys.keys
        .where((row) => !currentRows.contains(row))
        .toList();
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



  // ボタンの位置に基づいた固定色を取得（stitch_pattern_grid.dartと同じロジック）
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

  // 編み目のインデックスを取得
  int _getStitchIndexInCurrentList(dynamic stitchObj) {
    try {
      final index = widget.currentStitches.indexWhere((s) {
        if (stitchObj is CrochetStitch && s is CrochetStitch) {
          return s.nameJa == stitchObj.nameJa;
        } else if (stitchObj is CustomStitch && s is CustomStitch) {
          return s.nameJa == stitchObj.nameJa;
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
      if (stitch is CrochetStitch) {
        return stitch.getName(context);
      } else if (stitch is CustomStitch) {
        return stitch.getName(context);
      } else if (stitch is Map<String, String>) {
        final locale = context.locale.languageCode;
        return locale == 'ja' ? stitch['nameJa']! : stitch['nameEn']!;
      } else {
        return 'Unknown';
      }
    } catch (e) {
      // エラー時は日本語名を返す
      if (stitch is CrochetStitch) {
        return stitch.nameJa;
      } else if (stitch is CustomStitch) {
        return stitch.nameJa;
      }
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // build時に最新の編み目が右端に表示されるよう自動スクロール
    if (widget.stitchHistory.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        try {
          final latestRow = widget.stitchHistory.last['row'] as int;
          final controller = _horizontalScrollControllers[latestRow];

          if (controller != null && controller.hasClients) {
            final maxScrollExtent = controller.position.maxScrollExtent;
            // 現在のスクロール位置が右端でない場合のみスクロール
            if (maxScrollExtent > 0 && controller.offset < maxScrollExtent) {
              controller.jumpTo(maxScrollExtent);
            }
          }
        } catch (e) {
          // スクロール中にエラーが発生した場合は無視
        }
      });
    }

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
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text(
                  '編み目履歴',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(全${widget.stitchHistory.length}目)',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey,
                  ),
                ),
                const Spacer(),
                if (widget.currentRow != null &&
                    widget.currentStitchCount != null)
                  Text(
                    '${widget.currentRow}段目 ${widget.currentStitchCount}目',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey,
                      fontWeight: FontWeight.w500,
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timeline,
                          size: 64,
                          color: isDarkMode ? Colors.grey[600] : const Color(0xFFE0E0E0),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '編み目の履歴が表示されます\nタップで編み目を追加してください',
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[400] : Colors.grey,
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildHistoryItems(),
                      ),
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

      // 各段にキーを割り当て
      _rowKeys[row] = GlobalKey();

      // 段のヘッダー＋編み目を縦並び
      items.add(
        Dismissible(
          key: ValueKey('row_${row}_${rowStitches.length}_${rowStitches.first['timestamp']?.millisecondsSinceEpoch ?? row}'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 24),
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
                title: const Text('段を削除'),
                content: Text('$row段目を削除しますか？\nこの段の編み目がすべて削除されます。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('キャンセル'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child:
                        const Text('削除', style: TextStyle(color: Colors.red)),
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
            margin: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    scrollToRow(row);
                    if (widget.onRowTap != null) {
                      widget.onRowTap!(row);
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFFAD1457) : const Color(0xFFF8BBD9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$row段',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFFAD1457),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // この段の編み目を横スクロール可能に表示
                if (rowStitches.any((stitch) => stitch['position'] != 0))
                  SizedBox(
                    height: 80, // 固定高さで横スクロール
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
                          final stitchIndex = _getStitchIndexInCurrentList(stitchObj);
                          final stitchColor = _getStitchColorByIndex(stitchIndex);

                                                  return Padding(
                          key: ValueKey('stitch_${row}_${position}_${stitchData['timestamp']?.millisecondsSinceEpoch ?? '${row}_$position'}'),
                            padding: const EdgeInsets.only(right: 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: (stitchObj is CrochetStitch ||
                                              stitchObj is CustomStitch) &&
                                          stitchObj.isOval
                                      ? 56
                                      : 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? const Color(0xFF3D3D3D) : Colors.white,
                                    borderRadius: (stitchObj is CrochetStitch ||
                                                stitchObj is CustomStitch) &&
                                            stitchObj.isOval
                                        ? BorderRadius.circular(24)
                                        : BorderRadius.circular(10),
                                    border: Border.all(
                                      color: stitchColor,
                                      width: 3,
                                    ),
                                  ),
                                  child: Center(
                                    child: (stitchObj is CrochetStitch ||
                                                stitchObj is CustomStitch) &&
                                            stitchObj.imagePath != null
                                        ? Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            padding: const EdgeInsets.all(2),
                                            child: Image.asset(
                                              stitchObj.imagePath!,
                                              width: 32,
                                              height: 32,
                                              fit: BoxFit.contain,
                                            ),
                                          )
                                        : Text(
                                            _getStitchName(stitchObj)
                                                .substring(0, 1),
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: stitchColor,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$position',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode ? Colors.grey[400] : Colors.grey,
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
                      color: isDarkMode ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
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
                          '編み目を追加してください',
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

  // 履歴のstitch情報を現在のボタンリストから探す
  dynamic _findStitchInCurrentList(
      dynamic stitch, List<dynamic> currentStitches) {
    String? nameJa;
    String? nameEn;
    
    if (stitch is CrochetStitch) {
      nameJa = stitch.nameJa;
      nameEn = stitch.nameEn;
    } else if (stitch is CustomStitch) {
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
        if (s is CrochetStitch) {
          return s.nameJa == nameJa || s.nameEn == nameEn;
        } else if (s is CustomStitch) {
          return s.nameJa == nameJa || s.nameEn == nameEn;
        }
        return false;
      },
      orElse: () {
        // なければMapからCustomStitchを生成
        if (stitch is Map &&
            (stitch['type'] == 'custom' || stitch['imagePath'] != null)) {
          return CustomStitch(
            nameJa: stitch['nameJa'] ?? stitch['name'] ?? nameJa ?? '',
            nameEn: stitch['nameEn'] ?? stitch['name'] ?? nameEn ?? '',
            imagePath: stitch['imagePath'],
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
