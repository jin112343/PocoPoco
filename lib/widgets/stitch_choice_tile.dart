import 'package:flutter/material.dart';

import '../l10n/script_metrics.dart';
import 'auto_scroll_text.dart';

/// 編み目を選ぶ一覧の1マス。
///
/// 記号と名前の位置を固定して、名前の長さや行数が違ってもマス同士が揃うようにする。
/// 名前は2行まで折り返し、それでも収まらない時は自動で横に流す。
class StitchChoiceTile extends StatelessWidget {
  const StitchChoiceTile({
    super.key,
    required this.name,
    required this.imagePath,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String name;
  final String? imagePath;
  final bool selected;

  /// 選択中の枠とチェックの色
  final Color accentColor;
  final VoidCallback onTap;

  static const double _imageSize = 44;
  static const double _fontSize = 11;
  // 欧文・日本語での行の高さ（背の高い文字の言語では scriptLineHeight で広げる）
  static const double _baseLineHeight = 1.3;
  static const int _maxLines = 2;
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(6, 10, 6, 7);
  static const double _gap = 5;

  /// 名前の文字は、文字サイズの設定に合わせて大きくする（マスに収まる範囲で）
  static TextScaler _textScaler(BuildContext context) =>
      MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5);

  static double _labelHeight(BuildContext context) =>
      _textScaler(context).scale(_fontSize) *
          scriptLineHeight(context, _baseLineHeight) *
          _maxLines +
      1;

  /// マスの高さ。文字サイズの設定で名前の欄が広がる分だけ高くなる
  static double heightFor(BuildContext context) =>
      _padding.vertical + _imageSize + _gap + _labelHeight(context);

  /// 1行に並べるマスの数
  static int columnsFor(BuildContext context, double width) {
    // 普通の文字サイズのスマートフォンで3列。文字を大きくしている時は列を減らして名前の幅を確保する
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final target = large ? 128.0 : 96.0;
    return (width / target).floor().clamp(2, 6);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final ink = isDarkMode ? Colors.white : const Color(0xFF2B2B2B);
    final image = imagePath;
    final radius = BorderRadius.circular(14);

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? Color.alphaBlend(
                accentColor.withValues(alpha: isDarkMode ? 0.28 : 0.10),
                isDarkMode ? const Color(0xFF3D3D3D) : Colors.white,
              )
            : (isDarkMode ? const Color(0xFF3D3D3D) : Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected
                ? accentColor
                : (isDarkMode ? Colors.white24 : const Color(0xFFE2DCE4)),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: _padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 記号は名前の行数に関係なく、いつも同じ位置
                    SizedBox(
                      height: _imageSize,
                      child: Center(
                        child: image != null
                            ? Image.asset(
                                image,
                                width: _imageSize,
                                height: _imageSize,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    _Initial(name: name, color: ink),
                              )
                            : _Initial(name: name, color: ink),
                      ),
                    ),
                    const SizedBox(height: _gap),
                    SizedBox(
                      height: _labelHeight(context),
                      child: Center(
                        child: MediaQuery(
                          data: MediaQuery.of(context)
                              .copyWith(textScaler: _textScaler(context)),
                          child: AutoScrollText(
                            name,
                            maxLines: _maxLines,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _fontSize,
                              height:
                                  scriptLineHeight(context, _baseLineHeight),
                              fontWeight: FontWeight.w600,
                              color: ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.check, color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 記号の画像がない編み目は、名前の頭文字で代用する
class _Initial extends StatelessWidget {
  const _Initial({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      name.isEmpty ? '?' : name.characters.first,
      textScaler: TextScaler.noScaling,
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
    );
  }
}
