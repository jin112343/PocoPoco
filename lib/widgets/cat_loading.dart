import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 猫が毛糸玉を転がすローディングアニメーション。
///
/// 読み込み中だけツリーに置く想定（完了したら親が外す＝即終了する）。
/// 失敗時は [animate] を false にして静止させ、再試行ボタンを並べて使う。
class CatLoadingIndicator extends StatefulWidget {
  const CatLoadingIndicator({
    super.key,
    this.size = 160,
    this.animate = true,
  });

  /// 横幅。高さは横幅の 5/8。
  final double size;

  /// false の場合は動かさず静止画として表示する（失敗時用）
  final bool animate;

  @override
  State<CatLoadingIndicator> createState() => _CatLoadingIndicatorState();
}

class _CatLoadingIndicatorState extends State<CatLoadingIndicator>
    with SingleTickerProviderStateMixin {
  // 毛糸玉が1往復する時間
  static const _loopDuration = Duration(milliseconds: 1400);
  // 静止表示のときのポーズ（毛糸玉が少し転がった位置）
  static const _restProgress = 0.18;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _loopDuration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(CatLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    // 端末の「視差効果を減らす」等が有効な場合は動かさない
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shouldAnimate = widget.animate && !reduceMotion;
    if (shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = _restProgress;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size * CatLoadingPainter.aspectRatio,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: CatLoadingPainter(progress: _controller.value),
          ),
        ),
      ),
    );
  }
}

/// 猫と毛糸玉の描画。[progress] は 0.0〜1.0 で1往復。
class CatLoadingPainter extends CustomPainter {
  CatLoadingPainter({required this.progress, this.showStage = true});

  final double progress;

  /// 背景の角丸パネルを描くか（別の背景の上に重ねる時はfalse）
  final bool showStage;

  /// 高さ / 横幅
  static const double aspectRatio = _designHeight / _designWidth;

  static const double _designWidth = 240;
  static const double _designHeight = 150;
  static const double _groundY = 124;
  static const double _ballRadius = 24;
  // 毛糸玉が猫の手元にあるときの中心X と、転がる距離
  static const double _ballRestX = 96;
  static const double _ballTravel = 40;

  // アプリアイコンに合わせた配色
  static const Color _stageColor = Color(0xFFFFD9D4);
  static const Color _catColor = Color(0xFF161B2B);
  static const Color _eyeColor = Color(0xFFFDF1DC);
  static const Color _noseColor = Color(0xFFF48FB1);
  static const Color _yarnColor = Color(0xFFF7922D);
  static const Color _yarnShade = Color(0xFFE07A14);
  static const Color _shadowColor = Color(0x33A0505A);
  static const Color _legLineColor = Color(0xFF6B6F80);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / _designWidth, size.height / _designHeight);
    canvas.save();
    canvas.translate(
      (size.width - _designWidth * scale) / 2,
      (size.height - _designHeight * scale) / 2,
    );
    canvas.scale(scale);

    final t = progress % 1.0;
    final wave = (1 - math.cos(2 * math.pi * t)) / 2; // 0→1→0（滑らかに往復）
    final ballX = _ballRestX - _ballTravel * wave;
    final ballCenter = Offset(ballX, _groundY - _ballRadius);
    // 転がった距離ぶんだけ回転させる（滑らずに転がって見える）
    final ballAngle = (ballX - _ballRestX) / _ballRadius;
    // 手は毛糸玉が手元にある間だけ伸ばす
    final pawReach = math.pow((math.cos(2 * math.pi * t) + 1) / 2, 2).toDouble();

    if (showStage) _paintStage(canvas);
    _paintThread(canvas, ballCenter, wave);
    _paintShadows(canvas, ballCenter);
    _paintTail(canvas, t);
    _paintBody(canvas);
    _paintPaw(canvas, pawReach);
    _paintHead(canvas, t, wave);
    _paintBall(canvas, ballCenter, ballAngle);

    canvas.restore();
  }

  void _paintStage(Canvas canvas) {
    final stage = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, _designWidth, _designHeight),
      const Radius.circular(28),
    );
    canvas.drawRRect(stage, Paint()..color = _stageColor);
  }

  void _paintShadows(Canvas canvas, Offset ballCenter) {
    final paint = Paint()..color = _shadowColor;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(ballCenter.dx, _groundY + 3), width: 44, height: 7),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: const Offset(168, _groundY + 3), width: 78, height: 8),
      paint,
    );
  }

  /// 毛糸玉から左へ伸びる糸。玉が近づくとたるみ、離れるとピンと張る
  void _paintThread(Canvas canvas, Offset ballCenter, double slack) {
    const anchor = Offset(18, _groundY - 1);
    final start = Offset(ballCenter.dx - _ballRadius * 0.55, _groundY - 3);
    final amplitude = 2.0 + 6.0 * slack;

    final path = Path()..moveTo(start.dx, start.dy);
    const segments = 24;
    for (var i = 1; i <= segments; i++) {
      final u = i / segments;
      final x = start.dx + (anchor.dx - start.dx) * u;
      final y = start.dy +
          (anchor.dy - start.dy) * u +
          math.sin(u * math.pi * 3) * amplitude * math.sin(u * math.pi);
      path.lineTo(x, y);
    }
    // 糸の端をくるんと丸める
    path.relativeQuadraticBezierTo(-9, 1, -6, -7);

    canvas.drawPath(
      path,
      Paint()
        ..color = _catColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintTail(Canvas canvas, double t) {
    final sway = math.sin(2 * math.pi * t) * 7;
    final path = Path()
      ..moveTo(192, _groundY - 8)
      ..cubicTo(
        214, _groundY - 6,
        222 + sway * 0.4, _groundY - 34,
        210 + sway, _groundY - 52,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = _catColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintBody(Canvas canvas) {
    final paint = Paint()..color = _catColor;
    // 胴体（おすわりの姿勢）
    canvas.drawOval(const Rect.fromLTRB(137, 62, 199, 128), paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(136, 98, 200, _groundY + 1),
        const Radius.circular(15),
      ),
      paint,
    );
    // 後ろ足のライン（アイコンの灰色の線）
    final legPaint = Paint()
      ..color = _legLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        const Offset(166, 100), const Offset(165, _groundY - 6), legPaint);
    final haunch = Path()
      ..moveTo(187, 100)
      ..quadraticBezierTo(178, 108, 180, _groundY - 6);
    canvas.drawPath(haunch, legPaint);
  }

  void _paintPaw(Canvas canvas, double reach) {
    const shoulder = Offset(150, 96);
    final paw = Offset(131 - 9 * reach, 112 - 7 * reach);
    canvas.drawLine(
      shoulder,
      paw,
      Paint()
        ..color = _catColor
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintHead(Canvas canvas, double t, double wave) {
    const headCenter = Offset(162, 54);
    final paint = Paint()..color = _catColor;

    canvas.save();
    // 毛糸玉を目で追って、頭を少しかしげる
    canvas.translate(headCenter.dx, headCenter.dy);
    canvas.rotate(-0.07 * wave);
    canvas.translate(-headCenter.dx, -headCenter.dy);

    // 耳
    final leftEar = Path()
      ..moveTo(134, 46)
      ..quadraticBezierTo(133, 20, 139, 13)
      ..quadraticBezierTo(150, 18, 160, 30)
      ..close();
    final rightEar = Path()
      ..moveTo(190, 46)
      ..quadraticBezierTo(192, 20, 186, 13)
      ..quadraticBezierTo(175, 18, 165, 30)
      ..close();
    canvas.drawPath(leftEar, paint);
    canvas.drawPath(rightEar, paint);

    // 頭
    canvas.drawOval(
      Rect.fromCenter(center: headCenter, width: 62, height: 54),
      paint,
    );

    // 目（まばたきは1往復に1回）
    final blink = (t > 0.62 && t < 0.70)
        ? 1 - (1 - ((t - 0.66).abs() / 0.04)).clamp(0.0, 1.0)
        : 1.0;
    final look = Offset(-2.6 * wave - 0.6, 1.2);
    for (final eyeX in const [149.0, 175.0]) {
      final eyeCenter = Offset(eyeX, 54);
      final eyeHeight = math.max(2.0, 21.0 * blink);
      canvas.drawOval(
        Rect.fromCenter(center: eyeCenter, width: 18, height: eyeHeight),
        Paint()..color = _eyeColor,
      );
      if (blink > 0.5) {
        canvas.drawCircle(eyeCenter + look, 5.6, paint);
      }
    }

    // 鼻
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(162, 67), width: 7, height: 4.5),
      Paint()..color = _noseColor,
    );

    canvas.restore();
  }

  void _paintBall(Canvas canvas, Offset center, double angle) {
    final ballRect = Rect.fromCircle(center: center, radius: _ballRadius);

    canvas.drawCircle(center, _ballRadius, Paint()..color = _yarnColor);

    // 糸の巻き目。玉の内側だけに描き、玉と一緒に回転させる
    canvas.save();
    canvas.clipPath(Path()..addOval(ballRect));
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final wrap = Paint()
      ..color = _catColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final shade = Paint()
      ..color = _yarnShade
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    // 斜めに巻かれた帯
    for (final dy in const [-15.0, -3.0, 9.0, 21.0]) {
      final band = Path()
        ..moveTo(-_ballRadius - 4, dy + 9)
        ..quadraticBezierTo(0, dy - 9, _ballRadius + 4, dy + 5);
      if (dy == -3.0) {
        canvas.drawPath(band.shift(const Offset(0, 6)), shade);
      }
      canvas.drawPath(band, wrap);
    }
    // 交差する向きの帯
    for (final dx in const [-10.0, 6.0]) {
      final band = Path()
        ..moveTo(dx - 6, -_ballRadius - 4)
        ..quadraticBezierTo(dx + 12, -4, dx - 2, _ballRadius * 0.2);
      canvas.drawPath(band, wrap);
    }
    canvas.restore();

    // 外枠
    canvas.drawCircle(
      center,
      _ballRadius,
      Paint()
        ..color = _catColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2,
    );
  }

  @override
  bool shouldRepaint(CatLoadingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.showStage != showStage;
}

/// 猫のローディングとメッセージを縦に並べた表示（画面中央に置く）
class CatLoadingMessage extends StatelessWidget {
  const CatLoadingMessage({
    super.key,
    required this.message,
    this.size = 200,
  });

  final String message;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CatLoadingIndicator(size: size),
        const SizedBox(height: 20),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.grey[400] : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

/// 時間のかかる処理中に画面全体を覆う表示
class CatLoadingOverlay extends StatelessWidget {
  const CatLoadingOverlay({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CatLoadingIndicator(size: 150),
                const SizedBox(height: 18),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF333333),
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

/// 読み込みに失敗した時の表示。猫は動かさず、再試行ボタンを出す
/// （終わらないローディングを回し続けない）
class CatLoadFailedView extends StatelessWidget {
  const CatLoadFailedView({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  /// 再試行以外の選択肢（例: このまま続ける）
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CatLoadingIndicator(size: 180, animate: false),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('retry_button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEC407A),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
