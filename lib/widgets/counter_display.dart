import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../controllers/project_controller.dart';
import '../models/project_markers.dart';

/// カウンター画面上部の大きな「いま何段目・何目」表示。
///
/// 保存状態・くり返しの目印・メモへの入口もここにまとめ、編みながら
/// 一目で確認できるようにする。高さは [heightFor] で決まる固定値なので、
/// 端末の文字サイズを大きくしても下のボタンを押し出さない。
class CounterDisplay extends StatelessWidget {
  const CounterDisplay({
    super.key,
    required this.currentRow,
    required this.currentStitchCount,
    required this.saveStatus,
    required this.isNewUnconfirmed,
    required this.markers,
    required this.memo,
    required this.onSaveStatusTap,
    required this.onMarkersTap,
    required this.onNotesTap,
    this.compact = false,
  });

  final int currentRow;
  final int currentStitchCount;
  final SaveStatus saveStatus;

  /// 新規作成後まだ「保存」を選んでいない作品（自動保存のみ）か
  final bool isNewUnconfirmed;
  final ProjectMarkers markers;
  final String memo;

  /// 保存に失敗している時に状態表示をタップした
  final VoidCallback onSaveStatusTap;
  final VoidCallback onMarkersTap;
  final VoidCallback onNotesTap;

  /// 画面の高さが足りない端末向けの小さめ表示
  final bool compact;

  static const double _maxTextScale = 1.3;
  static const EdgeInsets _margin = EdgeInsets.fromLTRB(12, 6, 12, 4);
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(14, 6, 10, 8);
  static const double _gap = 4;

  /// 数字の拡大率。端末の文字サイズ設定に合わせて大きくするが上限を設ける
  static double _numberScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, _maxTextScale);

  static double _numbersHeight(BuildContext context, bool compact) =>
      (compact ? 44.0 : 54.0) * _numberScale(context);

  static double _chipHeight(bool compact) => compact ? 30.0 : 32.0;

  /// このウィジェットが占める高さ
  static double heightFor(BuildContext context, {required bool compact}) {
    return _margin.vertical +
        _padding.vertical +
        _numbersHeight(context, compact) +
        _gap +
        _chipHeight(compact);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scale = _numberScale(context);
    final numberSize = (compact ? 36.0 : 44.0) * scale;
    final unitSize = (compact ? 15.0 : 17.0) * scale;
    final numberColor =
        isDarkMode ? const Color(0xFFF8BBD0) : const Color(0xFFAD1457);
    final unitColor = isDarkMode ? Colors.grey[300]! : Colors.grey[800]!;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: Container(
        margin: _margin,
        padding: _padding,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _numbersHeight(context, compact),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: tr('row_stitch_status', namedArgs: {
                        'row': '$currentRow',
                        'count': '$currentStitchCount',
                      }),
                      child: ExcludeSemantics(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              _NumberWithUnit(
                                key: const ValueKey('counter_row'),
                                template: tr('counter_row_format'),
                                value: currentRow,
                                numberSize: numberSize,
                                unitSize: unitSize,
                                numberColor: numberColor,
                                unitColor: unitColor,
                              ),
                              SizedBox(width: 18 * scale),
                              _NumberWithUnit(
                                key: const ValueKey('counter_stitches'),
                                template: tr('counter_stitch_format'),
                                value: currentStitchCount,
                                numberSize: numberSize,
                                unitSize: unitSize,
                                numberColor: numberColor,
                                unitColor: unitColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SaveStatusChip(
                    status: saveStatus,
                    isNewUnconfirmed: isNewUnconfirmed,
                    isDarkMode: isDarkMode,
                    onTap: onSaveStatusTap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: _gap),
            SizedBox(
              height: _chipHeight(compact),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _BandChip(
                    key: const ValueKey('notes_chip'),
                    icon: memo.trim().isEmpty
                        ? Icons.sticky_note_2_outlined
                        : Icons.sticky_note_2,
                    label: _memoLabel(),
                    isDarkMode: isDarkMode,
                    onTap: onNotesTap,
                  ),
                  ..._buildMarkerChips(isDarkMode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// メモがあれば最初の行を、なければ入口の名前を表示する
  String _memoLabel() {
    for (final line in memo.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return tr('notes_and_stitches');
  }

  List<Widget> _buildMarkerChips(bool isDarkMode) {
    if (markers.isEmpty) {
      return [
        _BandChip(
          key: const ValueKey('marker_add_chip'),
          icon: Icons.outlined_flag,
          label: tr('marker_add'),
          isDarkMode: isDarkMode,
          onTap: onMarkersTap,
        ),
      ];
    }

    final chips = <Widget>[];
    if (markers.hasCheck) {
      final isCheckRow = markers.isCheckRow(currentRow);
      chips.add(_BandChip(
        key: const ValueKey('marker_check_chip'),
        icon: isCheckRow ? Icons.flag : Icons.outlined_flag,
        label: isCheckRow
            ? tr('marker_check_now',
                namedArgs: {'n': '${markers.checkEveryRows}'})
            : tr('marker_check_remaining',
                namedArgs: {'rows': '${markers.rowsUntilCheck(currentRow)}'}),
        tone: isCheckRow ? _ChipTone.attention : _ChipTone.normal,
        isDarkMode: isDarkMode,
        onTap: onMarkersTap,
      ));
    }

    final progress = markers.repeatProgressAt(currentRow);
    if (progress != null) {
      final String label;
      var tone = _ChipTone.normal;
      if (progress.isFinished) {
        label = tr('marker_repeat_done');
        tone = _ChipTone.done;
      } else if (progress.isNotStarted) {
        label = tr('marker_repeat_not_started',
            namedArgs: {'row': '${progress.startRow}'});
      } else {
        label = tr('marker_repeat_progress', namedArgs: {
          'current': '${progress.current}',
          'total': '${progress.total}',
          'remaining': '${progress.remaining}',
        });
      }
      chips.add(_BandChip(
        key: const ValueKey('marker_repeat_chip'),
        icon: Icons.repeat,
        label: label,
        tone: tone,
        isDarkMode: isDarkMode,
        onTap: onMarkersTap,
      ));
    }
    return chips;
  }
}

/// 「5段目」「Row 5」のように、数字だけ大きくした表示
class _NumberWithUnit extends StatelessWidget {
  const _NumberWithUnit({
    super.key,
    required this.template,
    required this.value,
    required this.numberSize,
    required this.unitSize,
    required this.numberColor,
    required this.unitColor,
  });

  /// 数字の位置を {n} で示した文字列（例: "{n}段目" / "Row {n}"）
  final String template;
  final int value;
  final double numberSize;
  final double unitSize;
  final Color numberColor;
  final Color unitColor;

  @override
  Widget build(BuildContext context) {
    final parts = template.split('{n}');
    final prefix = parts.first;
    final suffix = parts.length > 1 ? parts[1] : '';
    final unitStyle = TextStyle(
      fontSize: unitSize,
      fontWeight: FontWeight.w600,
      color: unitColor,
    );

    return Text.rich(
      TextSpan(
        children: [
          if (prefix.isNotEmpty) TextSpan(text: prefix, style: unitStyle),
          TextSpan(
            text: '$value',
            style: TextStyle(
              fontSize: numberSize,
              fontWeight: FontWeight.w800,
              color: numberColor,
              height: 1.1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (suffix.isNotEmpty) TextSpan(text: suffix, style: unitStyle),
        ],
      ),
      maxLines: 1,
      softWrap: false,
      // 大きさは numberSize / unitSize 側で調整済み
      textScaler: TextScaler.noScaling,
    );
  }
}

/// 「保存済み」「未保存・再試行」などの保存状態表示
class _SaveStatusChip extends StatelessWidget {
  const _SaveStatusChip({
    required this.status,
    required this.isNewUnconfirmed,
    required this.isDarkMode,
    required this.onTap,
  });

  final SaveStatus status;
  final bool isNewUnconfirmed;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    Widget leading;
    var needsAction = false;

    switch (status) {
      case SaveStatus.none:
        return const SizedBox.shrink();
      case SaveStatus.pending:
        label = tr('save_status_saving');
        color = isDarkMode ? Colors.grey[300]! : Colors.grey[700]!;
        leading = SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        );
      case SaveStatus.saved:
        label = isNewUnconfirmed
            ? tr('save_status_autosaved')
            : tr('save_status_saved');
        color = isDarkMode ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
        leading = Icon(Icons.check_circle, size: 16, color: color);
      case SaveStatus.failed:
        label = tr('save_status_unsaved_retry');
        color = isDarkMode ? const Color(0xFFEF9A9A) : const Color(0xFFC62828);
        leading = Icon(Icons.error_outline, size: 16, color: color);
        needsAction = true;
      case SaveStatus.limitReached:
        label = tr('save_status_limit');
        color = isDarkMode ? const Color(0xFFFFCC80) : const Color(0xFFE65100);
        leading = Icon(Icons.lock_outline, size: 16, color: color);
        needsAction = true;
    }

    final chip = Container(
      key: ValueKey('save_status_${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: needsAction ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: needsAction ? Border.all(color: color, width: 1.2) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 170),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Semantics(
          liveRegion: true,
          button: needsAction,
          child: needsAction
              ? InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onTap,
                  child: chip,
                )
              : chip,
        ),
      ),
    );
  }
}

enum _ChipTone { normal, attention, done }

/// メモ・目印の入口になる小さなチップ
class _BandChip extends StatelessWidget {
  const _BandChip({
    super.key,
    required this.icon,
    required this.label,
    required this.isDarkMode,
    required this.onTap,
    this.tone = _ChipTone.normal,
  });

  final IconData icon;
  final String label;
  final bool isDarkMode;
  final VoidCallback onTap;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    switch (tone) {
      case _ChipTone.normal:
        background =
            isDarkMode ? const Color(0xFF424242) : const Color(0xFFFCE4EC);
        foreground = isDarkMode ? Colors.white : const Color(0xFF880E4F);
      case _ChipTone.attention:
        background =
            isDarkMode ? const Color(0xFF6D4C00) : const Color(0xFFFFE082);
        foreground = isDarkMode ? Colors.white : const Color(0xFF5D4037);
      case _ChipTone.done:
        background =
            isDarkMode ? const Color(0xFF1B5E20) : const Color(0xFFC8E6C9);
        foreground = isDarkMode ? Colors.white : const Color(0xFF1B5E20);
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
