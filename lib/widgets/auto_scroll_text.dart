import 'dart:async';

import 'package:flutter/material.dart';

/// 収まる時はそのまま表示し、収まらない時は横に自動で流して全文を読めるようにする文字。
///
/// 言語や画面の幅・文字サイズの設定によって長さが変わる場所（編み目の名前、
/// ボタンの文言など）で、「…」で切れて読めなくなるのを防ぐために使う。
///
/// - [maxLines] 行に収まるなら、普通の [Text] と同じ（折り返して [textAlign] で揃える）
/// - 少しだけ足りない時は、[minScale] まで文字を縮めて収める
/// - それでも収まらないなら1行にして、端まで流す → 少し止まる → 先頭へ戻る、を繰り返す
/// - 端末の「視差効果を減らす」等が有効な時は流さず、「…」で省略する
///
/// 行の高さ（[TextStyle.height]）を指定した時は、どの文字でも1行がちょうどその高さになる
/// （文字の種類によって行が高くなり、高さを決めた欄からはみ出すのを防ぐ）。
///
/// 流す向きは、画面の向きではなく文字そのものの向きに合わせる
/// （右から左の言語の画面に日本語や英語の作品名を出しても、先頭から読めるように）。
class AutoScrollText extends StatefulWidget {
  const AutoScrollText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.minScale = 1,
  });

  final String text;
  final TextStyle? style;

  /// 折り返して表示できる最大の行数。これを超える時に横へ流す
  final int maxLines;
  final TextAlign textAlign;

  /// 流す前に、ここまでなら文字を縮めて収める（1 = 縮めない）
  final double minScale;

  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText> {
  // 流す速さ（1秒あたりの論理ピクセル）
  static const double _velocity = 32;
  // 流し始める前と、端まで流したあとに止まる時間
  static const Duration _startPause = Duration(milliseconds: 1500);
  static const Duration _endPause = Duration(milliseconds: 1100);
  // 先頭へ戻る時間
  static const Duration _rewind = Duration(milliseconds: 450);
  // 両端をぼかす幅
  static const double _fade = 10;

  final ScrollController _controller = ScrollController();
  Timer? _timer;
  bool _reduceMotion = false;
  // いま動かしている周回。作り直された時に古い周回を止めるための番号
  int _run = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(AutoScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.minScale != widget.minScale) {
      _restart();
    }
  }

  @override
  void dispose() {
    _run++;
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restart() {
    _run++;
    _timer?.cancel();
    _timer = null;
    if (_controller.hasClients) _controller.jumpTo(0);
  }

  /// レイアウト後に呼ぶ。流す必要があれば周回を始める（すでに動いていれば何もしない）
  void _ensureScrolling() {
    if (!mounted || _timer != null || !_controller.hasClients) return;
    if (_controller.position.maxScrollExtent <= 0) return;
    final run = ++_run;
    _timer = Timer(_startPause, () => _scrollToEnd(run));
  }

  Future<void> _scrollToEnd(int run) async {
    if (!mounted || run != _run || !_controller.hasClients) return;
    final distance = _controller.position.maxScrollExtent;
    if (distance <= 0) {
      _timer = null;
      return;
    }
    await _controller.animateTo(
      distance,
      duration: Duration(milliseconds: (distance / _velocity * 1000).round()),
      curve: Curves.linear,
    );
    if (!mounted || run != _run) return;
    _timer = Timer(_endPause, () => _scrollToStart(run));
  }

  Future<void> _scrollToStart(int run) async {
    if (!mounted || run != _run || !_controller.hasClients) return;
    await _controller.animateTo(0, duration: _rewind, curve: Curves.easeInOut);
    if (!mounted || run != _run) return;
    _timer = Timer(_startPause, () => _scrollToEnd(run));
  }

  /// 文字そのものの読む向き（最初に現れる、向きのはっきりした文字で決める）
  static TextDirection? _directionOf(String text) {
    for (final rune in text.runes) {
      // ヘブライ文字・アラビア文字など（右から左）
      if ((rune >= 0x0590 && rune <= 0x08FF) ||
          (rune >= 0xFB1D && rune <= 0xFDFF) ||
          (rune >= 0xFE70 && rune <= 0xFEFF)) {
        return TextDirection.rtl;
      }
      // 数字・記号・空白は向きを決めない。それ以外の文字は左から右
      if (rune >= 0x41 &&
          !(rune >= 0x5B && rune <= 0x60) &&
          !(rune >= 0x7B && rune <= 0xBF) &&
          !(rune >= 0x2000 && rune <= 0x2BFF) &&
          !(rune >= 0x3000 && rune <= 0x303F) &&
          !(rune >= 0xFF00 && rune <= 0xFF20)) {
        return TextDirection.ltr;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final baseSize = style.fontSize ?? 14;
        final painter = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          // 言語によって字形（と幅）が変わるフォントがあるので、表示と同じ言語で測る
          locale: Localizations.maybeLocaleOf(context),
          maxLines: widget.maxLines,
        );
        // 行の高さが指定されていれば、代替フォントの文字が混ざっても行の高さを変えない
        StrutStyle? strutAt(double scale) => style.height == null
            ? null
            : StrutStyle.fromTextStyle(
                style.copyWith(fontSize: baseSize * scale),
                forceStrutHeight: true,
              );
        bool fitsAt(double scale) {
          painter.text = TextSpan(
              text: widget.text,
              style: style.copyWith(fontSize: baseSize * scale));
          painter.strutStyle = strutAt(scale);
          painter.layout(maxWidth: constraints.maxWidth);
          return !painter.didExceedMaxLines;
        }

        // そのまま収まるか。だめなら少しずつ縮めて、収まる大きさを探す
        var scale = 1.0;
        var fits = fitsAt(scale);
        while (!fits && scale - 0.05 >= widget.minScale - 0.001) {
          scale -= 0.05;
          fits = fitsAt(scale);
        }
        painter.dispose();
        final fittedStyle = scale < 1
            ? (widget.style ?? const TextStyle())
                .copyWith(fontSize: baseSize * scale)
            : widget.style;

        if (fits || _reduceMotion || !constraints.hasBoundedWidth) {
          // 流さない場合は、動いていた周回を止めておく
          if (_timer != null) {
            _run++;
            _timer?.cancel();
            _timer = null;
          }
          return Text(
            widget.text,
            style: fits ? fittedStyle : widget.style,
            strutStyle: strutAt(fits ? scale : 1),
            maxLines: widget.maxLines,
            textAlign: widget.textAlign,
            overflow: TextOverflow.ellipsis,
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _ensureScrolling());
        return ShaderMask(
          // 流れている文字の両端を少しぼかして、切れ目をやわらげる
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            final edge = (_fade / bounds.width).clamp(0.0, 0.3);
            return LinearGradient(
              colors: const [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0, edge, 1 - edge, 1],
            ).createShader(bounds);
          },
          child: Directionality(
            // 文字の先頭が見える側から流し始める
            textDirection:
                _directionOf(widget.text) ?? Directionality.of(context),
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: _fade),
              child: Text(
                widget.text,
                style: widget.style,
                strutStyle: strutAt(1),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        );
      },
    );
  }
}
