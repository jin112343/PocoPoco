import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// 「1つ戻す」「段完成」「リセット」の操作ボタン。
///
/// よく使う「1つ戻す」「段完成」は大きく、押し間違えると困る「リセット」は
/// 小さくして反対側の端に離して置く。[leftHanded] で左右を入れ替えられる。
class ControlButtons extends StatelessWidget {
  const ControlButtons({
    super.key,
    required this.onRemoveStitch,
    required this.onCompleteRow,
    required this.onReset,
    required this.canRemoveStitch,
    required this.canCompleteRow,
    this.canReset = true,
    this.leftHanded = false,
    this.height = defaultHeight,
  });

  static const double defaultHeight = 60;

  // リセットを他のボタンから離す間隔
  static const double _resetGap = 20;
  static const double _resetWidth = 68;
  static const Color _undoColor = Color(0xFFE65100);
  static const Color _completeColor = Color(0xFF388E3C);

  final VoidCallback onRemoveStitch;
  final VoidCallback onCompleteRow;
  final VoidCallback onReset;
  final bool canRemoveStitch;
  final bool canCompleteRow;
  final bool canReset;

  /// true の場合は左手の親指に近い側（左端）へ「段完成」を置く
  final bool leftHanded;
  final double height;

  @override
  Widget build(BuildContext context) {
    // context.localeを参照して、言語が切り替わった時にラベルを作り直す
    // ignore: unused_local_variable
    final locale = context.locale;

    // 親指に近い側から「段完成」「1つ戻す」、一番遠い端に「リセット」
    final children = <Widget>[
      SizedBox(
        width: _resetWidth,
        child: _ResetButton(
          key: const ValueKey('reset_button'),
          label: 'reset'.tr(),
          onPressed: canReset ? onReset : null,
        ),
      ),
      const SizedBox(width: _resetGap),
      Expanded(
        flex: 5,
        child: _ActionButton(
          key: const ValueKey('undo_button'),
          icon: Icons.undo,
          label: 'undo'.tr(),
          color: _undoColor,
          onPressed: canRemoveStitch ? onRemoveStitch : null,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 6,
        child: _ActionButton(
          key: const ValueKey('complete_row_button'),
          icon: Icons.check_circle,
          label: 'complete_row'.tr(),
          color: _completeColor,
          onPressed: canCompleteRow ? onCompleteRow : null,
        ),
      ),
    ];

    // ボタン内の文字が端末の文字サイズ設定ではみ出さないよう上限を設ける
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: leftHanded ? children.reversed.toList() : children,
        ),
      ),
    );
  }
}

/// 「1つ戻す」「段完成」用の大きなボタン
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final enabled = onPressed != null;
    final background = enabled
        ? color
        : (isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0));
    final foreground = enabled
        ? Colors.white
        : (isDarkMode ? Colors.grey[600]! : Colors.grey[500]!);

    // ラベルは中のTextから、押す操作はInkWellから読み上げに伝わる
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        elevation: enabled ? 2 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 24, color: foreground),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 押し間違えにくいよう控えめにした「リセット」ボタン
class _ResetButton extends StatelessWidget {
  const _ResetButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final enabled = onPressed != null;
    final foreground = enabled
        ? (isDarkMode ? Colors.grey[300]! : Colors.grey[700]!)
        : (isDarkMode ? Colors.grey[700]! : Colors.grey[400]!);

    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: foreground.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 20, color: foreground),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
