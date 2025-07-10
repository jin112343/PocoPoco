import 'package:flutter/material.dart';
import '../models/crochet_stitch.dart';

class StitchHistorySection extends StatefulWidget {
  const StitchHistorySection({
    super.key,
    required this.stitchHistory,
    this.onRowTap,
    this.onRowCompleted,
    this.currentRow,
    this.currentStitchCount,
  });

  final List<Map<String, dynamic>> stitchHistory;
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

    // 編み目が追加された場合、横スクロールを最新まで自動移動（アニメーションなし）
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

  void scrollToRow(int rowNumber) {
    final key = _rowKeys[rowNumber];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
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

    if (controller != null) {
      // 横スクロールを最右端まで（アニメーションなしで直接移動）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.hasClients && controller.position.maxScrollExtent > 0) {
          controller.jumpTo(controller.position.maxScrollExtent);
        }
      });
    }
  }

  ScrollController _getHorizontalScrollController(int row) {
    if (!_horizontalScrollControllers.containsKey(row)) {
      _horizontalScrollControllers[row] = ScrollController();
    }
    return _horizontalScrollControllers[row]!;
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
                        final stitch = stitchData['stitch'] as CrochetStitch;
                        final position = stitchData['position'] as int;

                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: stitch.isOval ? 56 : 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: stitch.isOval
                                      ? BorderRadius.circular(24)
                                      : BorderRadius.circular(10),
                                  border:
                                      Border.all(color: stitch.color, width: 3),
                                ),
                                child: Center(
                                  child: stitch.imagePath != null
                                      ? Image.asset(
                                          stitch.imagePath!,
                                          width: 32,
                                          height: 32,
                                          fit: BoxFit.contain,
                                        )
                                      : Text(
                                          stitch.name.substring(0, 1),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: stitch.color,
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
}
