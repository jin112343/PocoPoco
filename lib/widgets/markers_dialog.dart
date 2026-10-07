import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/project_markers.dart';

/// くり返し編みの目印（◯段ごとに確認・模様のくり返し回数）を設定するダイアログ。
/// 保存した場合は新しい設定を、キャンセルした場合はnullを返す。
Future<ProjectMarkers?> showMarkersDialog(
  BuildContext context, {
  required ProjectMarkers markers,
  required int currentRow,
}) {
  return showDialog<ProjectMarkers>(
    context: context,
    builder: (context) =>
        _MarkersDialog(markers: markers, currentRow: currentRow),
  );
}

class _MarkersDialog extends StatefulWidget {
  const _MarkersDialog({required this.markers, required this.currentRow});

  final ProjectMarkers markers;
  final int currentRow;

  @override
  State<_MarkersDialog> createState() => _MarkersDialogState();
}

class _MarkersDialogState extends State<_MarkersDialog> {
  // 初めて設定する時の初期値
  static const int _defaultCheckEvery = 10;
  static const int _defaultRepeatRows = 4;
  static const int _defaultRepeatTotal = 5;

  late bool _checkEnabled = widget.markers.hasCheck;
  late bool _repeatEnabled = widget.markers.hasRepeat;
  bool _showErrors = false;

  late final TextEditingController _checkEvery = TextEditingController(
      text: '${widget.markers.checkEveryRows ?? _defaultCheckEvery}');
  late final TextEditingController _repeatRows = TextEditingController(
      text: '${widget.markers.repeatRows ?? _defaultRepeatRows}');
  late final TextEditingController _repeatTotal = TextEditingController(
      text: '${widget.markers.repeatTotal ?? _defaultRepeatTotal}');
  // 新しく設定する場合は、いま編んでいる段から模様を数え始める
  late final TextEditingController _repeatStart = TextEditingController(
      text: '${widget.markers.hasRepeat ? widget.markers.repeatStartRow : widget.currentRow}');

  @override
  void dispose() {
    _checkEvery.dispose();
    _repeatRows.dispose();
    _repeatTotal.dispose();
    _repeatStart.dispose();
    super.dispose();
  }

  /// 1〜上限の整数として読めなければnull
  int? _parse(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value < 1 || value > ProjectMarkers.maxValue) {
      return null;
    }
    return value;
  }

  void _save() {
    final checkEvery = _checkEnabled ? _parse(_checkEvery) : null;
    final repeatRows = _repeatEnabled ? _parse(_repeatRows) : null;
    final repeatTotal = _repeatEnabled ? _parse(_repeatTotal) : null;
    final repeatStart = _repeatEnabled ? _parse(_repeatStart) : null;

    final hasError = (_checkEnabled && checkEvery == null) ||
        (_repeatEnabled &&
            (repeatRows == null || repeatTotal == null || repeatStart == null));
    if (hasError) {
      setState(() => _showErrors = true);
      return;
    }

    Navigator.of(context).pop(ProjectMarkers(
      checkEveryRows: checkEvery,
      repeatRows: repeatRows,
      repeatTotal: repeatTotal,
      repeatStartRow: repeatStart ?? 1,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('markers_title')),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                key: const ValueKey('marker_check_switch'),
                secondary: const Icon(Icons.outlined_flag),
                title: Text(tr('marker_check_title')),
                subtitle: Text(tr('marker_check_desc')),
                value: _checkEnabled,
                onChanged: (value) => setState(() => _checkEnabled = value),
              ),
              if (_checkEnabled)
                _NumberField(
                  key: const ValueKey('marker_check_every_field'),
                  controller: _checkEvery,
                  label: tr('marker_check_every_label'),
                  showError: _showErrors && _parse(_checkEvery) == null,
                ),
              const Divider(height: 24),
              SwitchListTile(
                key: const ValueKey('marker_repeat_switch'),
                secondary: const Icon(Icons.repeat),
                title: Text(tr('marker_repeat_title')),
                subtitle: Text(tr('marker_repeat_desc')),
                value: _repeatEnabled,
                onChanged: (value) => setState(() => _repeatEnabled = value),
              ),
              if (_repeatEnabled) ...[
                _NumberField(
                  key: const ValueKey('marker_repeat_rows_field'),
                  controller: _repeatRows,
                  label: tr('marker_repeat_rows_label'),
                  showError: _showErrors && _parse(_repeatRows) == null,
                ),
                _NumberField(
                  key: const ValueKey('marker_repeat_total_field'),
                  controller: _repeatTotal,
                  label: tr('marker_repeat_total_label'),
                  showError: _showErrors && _parse(_repeatTotal) == null,
                ),
                _NumberField(
                  key: const ValueKey('marker_repeat_start_field'),
                  controller: _repeatStart,
                  label: tr('marker_repeat_start_label'),
                  showError: _showErrors && _parse(_repeatStart) == null,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('cancel')),
        ),
        TextButton(
          key: const ValueKey('markers_save_button'),
          onPressed: _save,
          child: Text(tr('save')),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.showError,
  });

  final TextEditingController controller;
  final String label;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          errorText: showError
              ? tr('marker_value_error',
                  namedArgs: {'max': '${ProjectMarkers.maxValue}'})
              : null,
        ),
      ),
    );
  }
}
