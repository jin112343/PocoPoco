import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../controllers/project_controller.dart';
import '../models/stitch_info.dart';

/// カウンター画面から、メモとこれまでの編み方をその場で確認するシート。
/// 画面を移動せずに「使っている糸・針」「前の段をどう編んだか」を見返せる。
Future<void> showProjectNotesSheet(
  BuildContext context, {
  required ProjectController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => ProjectNotesSheet(controller: controller),
  );
}

class ProjectNotesSheet extends StatefulWidget {
  const ProjectNotesSheet({super.key, required this.controller});

  final ProjectController controller;

  @override
  State<ProjectNotesSheet> createState() => _ProjectNotesSheetState();
}

class _ProjectNotesSheetState extends State<ProjectNotesSheet> {
  static const int _memoMaxLength = 500;

  late final TextEditingController _memoController =
      TextEditingController(text: widget.controller.memo);

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDarkMode ? Colors.white : Colors.black87;
    final subColor = isDarkMode ? Colors.grey[400]! : Colors.grey[700]!;
    final rows = _summarizeRows(context);
    final legend = _summarizeStitches(context);

    return Padding(
      // キーボードが出てもメモ欄が隠れないようにする
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('notes_and_stitches'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: tr('close'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextField(
                key: const ValueKey('memo_field'),
                controller: _memoController,
                minLines: 3,
                maxLines: 6,
                maxLength: _memoMaxLength,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: tr('memo_label'),
                  hintText: tr('memo_hint'),
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
                // 入力のたびに作品へ反映し、自動保存に任せる
                onChanged: widget.controller.setMemo,
              ),
              const SizedBox(height: 16),
              _SectionTitle(text: tr('stitches_used_title'), color: titleColor),
              const SizedBox(height: 8),
              if (legend.isEmpty)
                Text(tr('row_summary_empty'), style: TextStyle(color: subColor))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in legend)
                      _LegendChip(item: item, isDarkMode: isDarkMode),
                  ],
                ),
              const SizedBox(height: 20),
              _SectionTitle(text: tr('row_summary_title'), color: titleColor),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                Text(tr('row_summary_empty'), style: TextStyle(color: subColor))
              else
                for (final row in rows)
                  _RowSummaryTile(
                    summary: row,
                    isCurrent: row.row == widget.controller.currentRow,
                    isDarkMode: isDarkMode,
                  ),
            ],
          );
        },
      ),
    );
  }

  /// 段ごとに「細編み×10 → 鎖編み×2」のような並びにまとめる（新しい段が先頭）
  List<_RowSummary> _summarizeRows(BuildContext context) {
    final byRow = <int, List<Map<String, dynamic>>>{};
    for (final entry in widget.controller.history) {
      if (entry['position'] == 0) continue;
      byRow.putIfAbsent(entry['row'] as int, () => []).add(entry);
    }

    final summaries = <_RowSummary>[];
    for (final row in byRow.keys.toList()..sort((a, b) => b.compareTo(a))) {
      final entries = byRow[row]!
        ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));

      // 同じ編み目が続く部分をまとめる
      final runs = <_StitchRun>[];
      for (final entry in entries) {
        final info = StitchInfo.of(entry['stitch']);
        final key = info?.key ?? '?';
        if (runs.isNotEmpty && runs.last.key == key) {
          runs.last.count++;
        } else {
          runs.add(_StitchRun(key, info?.displayName(context) ?? '?'));
        }
      }
      summaries.add(_RowSummary(
        row: row,
        stitchCount: entries.length,
        text: runs
            .map((run) => run.count > 1 ? '${run.name}×${run.count}' : run.name)
            .join(' → '),
      ));
    }
    return summaries;
  }

  /// 作品全体で使った編み目と回数（多い順）
  List<_LegendItem> _summarizeStitches(BuildContext context) {
    final items = <String, _LegendItem>{};
    for (final entry in widget.controller.history) {
      if (entry['position'] == 0) continue;
      final info = StitchInfo.of(entry['stitch']);
      if (info == null) continue;
      items
          .putIfAbsent(
            info.key,
            () => _LegendItem(info.displayName(context), info.imagePath),
          )
          .count++;
    }
    return items.values.toList()..sort((a, b) => b.count.compareTo(a.count));
  }
}

class _StitchRun {
  _StitchRun(this.key, this.name);

  final String key;
  final String name;
  int count = 1;
}

class _RowSummary {
  const _RowSummary({
    required this.row,
    required this.stitchCount,
    required this.text,
  });

  final int row;
  final int stitchCount;
  final String text;
}

class _LegendItem {
  _LegendItem(this.name, this.imagePath);

  final String name;
  final String? imagePath;
  int count = 0;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.item, required this.isDarkMode});

  final _LegendItem item;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF3D3D3D) : const Color(0xFFFCE4EC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.imagePath != null) ...[
            Container(
              width: 26,
              height: 26,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Image.asset(
                item.imagePath!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              '${item.name} ×${item.count}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowSummaryTile extends StatelessWidget {
  const _RowSummaryTile({
    required this.summary,
    required this.isCurrent,
    required this.isDarkMode,
  });

  final _RowSummary summary;
  final bool isCurrent;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final labelColor = isDarkMode ? Colors.white : const Color(0xFFAD1457);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isCurrent
                  ? (isDarkMode
                      ? const Color(0xFFAD1457)
                      : const Color(0xFFF8BBD9))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode
                    ? const Color(0xFFAD1457)
                    : const Color(0xFFF8BBD9),
              ),
            ),
            child: Text(
              tr('row_label', namedArgs: {'row': '${summary.row}'}),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: labelColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  tr('row_summary_count',
                      namedArgs: {'count': '${summary.stitchCount}'}),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
