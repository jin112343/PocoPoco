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
    this.currentRow,
    this.currentStitchCount,
  });

  final List<Map<String, dynamic>> stitchHistory;
  final List<dynamic> currentStitches;
  final Function(int)? onRowTap;
  final Function(int)? onRowCompleted;
  final int? currentRow;
  final int? currentStitchCount;

  @override
  State<StitchHistorySection> createState() => _StitchHistorySectionState();
}

class _StitchHistorySectionState extends State<StitchHistorySection> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _rowKeys = {};
  final Map<int, ScrollController> _horizontalScrollControllers = {};
  int _lastHistoryLength = 0;
  int _lastMaxRow = 0;

  @override
  void initState() {
    super.initState();
    _lastHistoryLength = widget.stitchHistory.length;
    _lastMaxRow = _getMaxRow();
  }

  @override
  void didUpdateWidget(StitchHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);

    final currentMaxRow = _getMaxRow();

    // 新しい段が開始された場合（段完成時）のみ自動スクロール
    if (currentMaxRow > _lastMaxRow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToLatestRow();
        if (widget.onRowCompleted != null) {
          widget.onRowCompleted!(currentMaxRow);
        }
      });
    }

    // 編み目が追加された場合、一番右の最新を表示するために自動スクロール
    if (widget.stitchHistory.length > _lastHistoryLength) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToLatestStitch();
      });
    }

    _lastHistoryLength = widget.stitchHistory.length;
    _lastMaxRow = currentMaxRow;
  }

  int _getMaxRow() {
    if (widget.stitchHistory.isEmpty) return 0;
    return widget.stitchHistory
        .map((e) => e['row'] as int)
        .reduce((a, b) => a > b ? a : b);
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
  }

  void _scrollToLatestRow() {
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
  }

  void _scrollToLatestStitch() {
    if (widget.stitchHistory.isEmpty) return;

    // 最新の段を取得
    final latestRow = widget.stitchHistory.last['row'] as int;
    final controller = _horizontalScrollControllers[latestRow];

    if (controller != null && controller.hasClients) {
      final position = controller.position;
      final maxScrollExtent = position.maxScrollExtent;

      if (maxScrollExtent > 0) {
        // 一番右の最新を表示するために最右端までスクロール
        controller.jumpTo(maxScrollExtent);
      }
    }
  }

  ScrollController _getHorizontalScrollController(int row) {
    return _horizontalScrollControllers.putIfAbsent(
        row, () => ScrollController());
  }

  String _getStitchName(dynamic stitch) {
    final locale = context.locale.languageCode;

    if (stitch is CrochetStitch) {
      return locale == 'ja' ? stitch.nameJa : stitch.nameEn;
    } else if (stitch is CustomStitch) {
      return stitch.getName(context);
    } else if (stitch is Map<String, String>) {
      return locale == 'ja' ? stitch['nameJa']! : stitch['nameEn']!;
    } else {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
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
                const Text(
                  '編み目履歴',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(全${widget.stitchHistory.length}目)',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                if (widget.currentRow != null &&
                    widget.currentStitchCount != null)
                  Text(
                    '${widget.currentRow}段目 ${widget.currentStitchCount}目',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (widget.stitchHistory.isNotEmpty)
                  Icon(
                    Icons.swipe,
                    size: 18,
                    color: Colors.grey,
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
                          color: const Color(0xFFE0E0E0),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '編み目の履歴が表示されます\nタップで編み目を追加してください',
                          style: TextStyle(
                            color: Colors.grey,
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
    final groupedHistory = <int, List<Map<String, dynamic>>>{};

    // 段ごとにグループ化
    for (final stitchData in widget.stitchHistory) {
      final row = stitchData['row'] as int;
      groupedHistory.putIfAbsent(row, () => []).add(stitchData);
    }

    final List<Widget> items = [];

    for (final row in groupedHistory.keys.toList()..sort()) {
      final rowStitches = groupedHistory[row]!;

      // 各段にキーを割り当て
      _rowKeys[row] = GlobalKey();

      // 段のヘッダー＋編み目を縦並び
      items.add(
        Container(
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
                    color: const Color(0xFFF8BBD9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$row段',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFAD1457),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // この段の編み目を横スクロール可能に表示
              if (rowStitches.any((stitch) => stitch['position'] != 0))
                SizedBox(
                  height: 80, // 固定高さで横スクロール
                  child: SingleChildScrollView(
                    controller: _getHorizontalScrollController(row),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: rowStitches
                          .where((stitch) =>
                              stitch['position'] != 0) // 段開始フラグの編み目を除外
                          .map((stitchData) {
                        final dynamic stitchObj = _findStitchInCurrentList(
                            stitchData['stitch'], widget.currentStitches);
                        final position = stitchData['position'] as int;

                        return Padding(
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
                                  color: Colors.white,
                                  borderRadius: (stitchObj is CrochetStitch ||
                                              stitchObj is CustomStitch) &&
                                          stitchObj.isOval
                                      ? BorderRadius.circular(24)
                                      : BorderRadius.circular(10),
                                  border: Border.all(
                                    color: (stitchObj is CrochetStitch ||
                                            stitchObj is CustomStitch)
                                        ? stitchObj.color
                                        : Colors.pink,
                                    width: 3,
                                  ),
                                ),
                                child: Center(
                                  child: (stitchObj is CrochetStitch ||
                                              stitchObj is CustomStitch) &&
                                          stitchObj.imagePath != null
                                      ? Image.asset(
                                          stitchObj.imagePath!,
                                          width: 32,
                                          height: 32,
                                          fit: BoxFit.contain,
                                        )
                                      : Text(
                                          _getStitchName(stitchObj)
                                              .substring(0, 1),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: (stitchObj
                                                        is CrochetStitch ||
                                                    stitchObj is CustomStitch)
                                                ? stitchObj.color
                                                : Colors.pink,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$position',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                )
              else
                // 空の段の場合の表示
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.grey.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 24,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '編み目を追加してください',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return items;
  }

  // 履歴のstitch情報を現在のボタンリストから探す
  dynamic _findStitchInCurrentList(
      dynamic stitch, List<dynamic> currentStitches) {
    String? name;
    if (stitch is CrochetStitch) {
      name = stitch.name;
    } else if (stitch is CustomStitch) {
      name = stitch.name;
    } else if (stitch is Map) {
      name = stitch['name'] ?? stitch['nameJa'] ?? stitch['nameEn'];
    } else if (stitch is String) {
      name = stitch;
    }
    // 現在のボタンリストから一致するものを探す
    final found = currentStitches.firstWhere(
      (s) => (s is CrochetStitch || s is CustomStitch) && s.name == name,
      orElse: () {
        // なければMapからCustomStitchを生成
        if (stitch is Map &&
            (stitch['type'] == 'custom' || stitch['imagePath'] != null)) {
          return CustomStitch(
            nameJa: stitch['nameJa'] ?? stitch['name'],
            nameEn: stitch['nameEn'] ?? stitch['name'],
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
