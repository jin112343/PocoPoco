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
  // 静止表示のときのポーズ（毛糸玉に手を添えて見つめている、1周の始まりの姿勢）
  static const _restProgress = 0.0;

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

/// 1周（0.0〜1.0）のある時点での、猫と毛糸玉の動き。
///
/// 流れ: 手を引いて構える → 毛糸玉をはじく → 玉が転がって止まる →
/// 戻ってくる玉をおしりを振って待ち構える → 手で受け止める（ここが0.0の姿勢）。
/// 0.0 と 1.0 は同じ姿勢で、途切れずに繰り返せる。
@visibleForTesting
class CatMotion {
  CatMotion(double progress) : t = progress % 1.0;

  /// 1周の中の位置（0.0〜1.0）
  final double t;

  // 毛糸玉が猫の手元にある時の中心X と、転がっていく距離
  static const double ballRestX = 98;
  static const double ballTravel = 42;
  static const double ballRadius = 23;

  // 時間の区切り
  static const double _strikeStart = 0.09;
  static const double _hit = 0.14;
  static const double _rollOutEnd = 0.50;
  static const double _rollBackStart = 0.58;
  static const double _arrive = 0.94;

  static double _smooth(double from, double to, double x) {
    final u = ((x - from) / (to - from)).clamp(0.0, 1.0);
    return u * u * (3 - 2 * u);
  }

  static double _easeOutCubic(double u) {
    final v = 1 - u.clamp(0.0, 1.0);
    return 1 - v * v * v;
  }

  static double _easeInOutCubic(double u) {
    final v = u.clamp(0.0, 1.0);
    return v < 0.5 ? 4 * v * v * v : 1 - math.pow(-2 * v + 2, 3) / 2;
  }

  /// 毛糸玉がどれだけ遠くへ行っているか（0: 手元 〜 1: いちばん遠く）
  double get away {
    if (t < _hit) return 0;
    if (t < _rollOutEnd) {
      // はじかれた直後が速く、だんだん遅くなる
      return _easeOutCubic((t - _hit) / (_rollOutEnd - _hit));
    }
    if (t < _rollBackStart) return 1;
    if (t < _arrive) {
      return 1 - _easeInOutCubic((t - _rollBackStart) / (_arrive - _rollBackStart));
    }
    return 0;
  }

  double get ballX => ballRestX - ballTravel * away;

  /// はじかれた直後に小さく弾む高さ
  double get ballHop {
    final u = (t - _hit) / 0.11;
    return u <= 0 || u >= 1 ? 0 : 3.2 * math.sin(math.pi * u);
  }

  /// 転がった距離ぶんの回転（滑らずに転がって見える）
  double get ballAngle => (ballX - ballRestX) / ballRadius;

  /// わくわく度（0〜1）。玉が戻ってくる時と、はじく前後に高まる。瞳やしっぽに使う
  double get excitement => t < 0.5
      ? 1 - _smooth(0.16, 0.28, t)
      : _smooth(0.78, 0.88, t);

  /// 戻ってくる玉を待ち構えて、おしりを振る横ゆれ
  double get wiggle {
    final envelope = _smooth(0.76, 0.82, t) * (1 - _smooth(0.90, 0.95, t));
    return 1.7 * envelope * math.sin(2 * math.pi * 7 * t);
  }

  /// 呼吸による体のふくらみ（-1〜1）
  double get breath => math.sin(2 * math.pi * t);

  /// まぶたの開き（1: 開いている 〜 0: 閉じている）。1周に1回まばたきする
  double get eyeOpen {
    final u = (t - 0.63) / 0.075;
    return u <= 0 || u >= 1 ? 1 : 1 - math.sin(math.pi * u);
  }

  /// 耳をぴくっと動かす角度
  double get earFlick {
    final u = (t - 0.30) / 0.07;
    return u <= 0 || u >= 1 ? 0 : 0.2 * math.sin(2 * math.pi * u);
  }

  /// しっぽの付け根側のゆれと、先端のゆれ（先端は少し遅れてついてくる）
  double get tailSway =>
      8 * math.sin(2 * math.pi * t + 0.5) +
      2.5 * math.sin(4 * math.pi * t) +
      2.6 * excitement * math.sin(2 * math.pi * 6 * t);

  double get tailTip =>
      10 * math.sin(2 * math.pi * t - 0.5) +
      3 * math.sin(4 * math.pi * t - 0.9) +
      3.4 * excitement * math.sin(2 * math.pi * 6 * t - 0.8);

  // 手先の位置
  static const Offset _pawOnBall = Offset(125.5, 105.5); // 玉に手を添えている
  static const Offset _pawBack = Offset(145, 99); // 引いて構える
  static const Offset _pawHit = Offset(121.5, 103); // 玉に当たる瞬間
  static const Offset _pawThrough = Offset(116, 105); // 振り抜いた先
  static const Offset _pawGround = Offset(139, 119.5); // 地面に下ろしている

  /// はじく側（手前）の手先の位置
  Offset get paw {
    if (t < _strikeStart) {
      return Offset.lerp(
          _pawOnBall, _pawBack, _easeInOutCubic(t / _strikeStart))!;
    }
    if (t < _hit) {
      final u = (t - _strikeStart) / (_hit - _strikeStart);
      return Offset.lerp(_pawBack, _pawHit, u * u)!;
    }
    if (t < 0.20) {
      return Offset.lerp(
          _pawHit, _pawThrough, _easeOutCubic((t - _hit) / (0.20 - _hit)))!;
    }
    if (t < 0.36) {
      return Offset.lerp(
          _pawThrough, _pawGround, _easeInOutCubic((t - 0.20) / 0.16))!;
    }
    if (t < 0.86) return _pawGround;
    if (t < _arrive) {
      return Offset.lerp(_pawGround, _pawOnBall,
          _easeInOutCubic((t - 0.86) / (_arrive - 0.86)))!;
    }
    return _pawOnBall;
  }

  /// はじく時に体を前へ乗り出す量（0〜1）。構えで少し引き、当たる瞬間に前へ出る
  double get lean {
    if (t < _strikeStart) return -0.35 * _easeInOutCubic(t / _strikeStart);
    if (t < _hit) {
      final u = (t - _strikeStart) / (_hit - _strikeStart);
      return -0.35 + 1.35 * u * u;
    }
    if (t < 0.34) return 1 - _easeInOutCubic((t - _hit) / (0.34 - _hit));
    return 0;
  }

  /// 玉をはじいた瞬間の勢いを示す線の濃さ（0〜1）
  double get impact {
    final u = (t - _hit) / 0.09;
    return u <= 0 || u >= 1 ? 0 : 1 - u;
  }
}

/// 猫と毛糸玉の描画。[progress] は 0.0〜1.0 で1周（[CatMotion] を参照）。
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
  static const double _ballRadius = CatMotion.ballRadius;

  // アプリアイコンに合わせた配色
  static const Color _stageColor = Color(0xFFFFD9D4);
  static const Color _catColor = Color(0xFF161B2B);
  // 毛並みの明るいところ（立体感を出す）
  static const Color _furLight = Color(0xFF2B3350);
  // 足の境目などの線
  static const Color _furLine = Color(0xFF5E657F);
  static const Color _eyeColor = Color(0xFFFDF1DC);
  static const Color _eyeShade = Color(0xFFEFD9A8);
  static const Color _noseColor = Color(0xFFF48FB1);
  static const Color _innerEarColor = Color(0xFFE58DA8);
  static const Color _whiskerColor = Color(0xFFD9DCE8);
  static const Color _yarnColor = Color(0xFFF7922D);
  static const Color _yarnLight = Color(0xFFFFB05C);
  static const Color _yarnShade = Color(0xFFDE7712);
  static const Color _shadowColor = Color(0x33A0505A);

  static const Offset _headCenter = Offset(160, 52);
  static const Offset _shoulder = Offset(151, 93);

  @override
  void paint(Canvas canvas, Size size) {
    final scale =
        math.min(size.width / _designWidth, size.height / _designHeight);
    canvas.save();
    canvas.translate(
      (size.width - _designWidth * scale) / 2,
      (size.height - _designHeight * scale) / 2,
    );
    canvas.scale(scale);

    final motion = CatMotion(progress);
    final ballCenter =
        Offset(motion.ballX, _groundY - _ballRadius - motion.ballHop);

    if (showStage) _paintStage(canvas);
    _paintShadows(canvas, motion);
    _paintThread(canvas, ballCenter, motion);

    // 体はおしりを振る分だけ横にゆれる（頭はほとんど動かさず、玉を見つめ続ける）。
    // はじく時は、肩と頭が玉のほうへ少し乗り出す
    final lean = motion.lean;
    canvas.save();
    canvas.translate(motion.wiggle, 0);
    _paintTail(canvas, motion);
    // 地面についた足は動かさず、上半身だけ傾ける
    canvas.translate(170, _groundY);
    canvas.skew(0.03 * lean, 0);
    canvas.translate(-170, -_groundY);
    _paintBody(canvas, motion);
    canvas.restore();

    canvas.save();
    canvas.translate(motion.wiggle * 0.25 - 2.4 * lean, 1.0 * lean.abs());
    _paintHead(canvas, motion);
    canvas.restore();

    _paintBall(canvas, ballCenter, motion);
    _paintNearLeg(canvas, motion);
    _paintImpact(canvas, motion);

    canvas.restore();
  }

  void _paintStage(Canvas canvas) {
    final stage = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, _designWidth, _designHeight),
      const Radius.circular(28),
    );
    canvas.drawRRect(stage, Paint()..color = _stageColor);
  }

  void _paintShadows(Canvas canvas, CatMotion motion) {
    final paint = Paint()..color = _shadowColor;
    // 玉が弾んでいる間は影を少し小さくする
    final hop = motion.ballHop / 3.2;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(motion.ballX, _groundY + 3),
        width: 42 - 6 * hop,
        height: 7 - hop,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(172 + motion.wiggle, _groundY + 3),
        width: 84,
        height: 8,
      ),
      paint,
    );
  }

  /// 毛糸玉から左へ伸びる糸。玉が近づくとたるみ、離れるとピンと張る
  void _paintThread(Canvas canvas, Offset ballCenter, CatMotion motion) {
    const anchor = Offset(18, _groundY - 1);
    final slack = 1 - motion.away;
    final start = Offset(ballCenter.dx - _ballRadius * 0.55, _groundY - 3);
    final amplitude = 2.0 + 6.0 * (1 - slack);

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
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// しっぽ。付け根から先へ波が伝わるようにゆれ、先端はくるんと丸まる
  void _paintTail(Canvas canvas, CatMotion motion) {
    final sway = motion.tailSway;
    final tip = motion.tailTip;
    final path = Path()
      ..moveTo(192, _groundY - 9)
      ..cubicTo(
        218, _groundY - 5,
        230 + sway * 0.25, _groundY - 26,
        222 + sway * 0.55, _groundY - 42,
      )
      ..quadraticBezierTo(
        217 + sway * 0.7, _groundY - 54,
        210 + tip * 0.5, _groundY - 50,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = _catColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// 胴体（おすわりの姿勢）と、奥の前足
  void _paintBody(Canvas canvas, CatMotion motion) {
    final paint = Paint()..color = _catColor;

    canvas.save();
    // 呼吸で、地面を支点にわずかにふくらむ
    canvas.translate(170, _groundY);
    canvas.scale(1 + 0.006 * motion.breath, 1 + 0.014 * motion.breath);
    canvas.translate(-170, -_groundY);

    final body = Path()
      ..moveTo(149, 70)
      // 胸から、奥の前足の前面へ
      ..cubicTo(144, 84, 146, 100, 149, 113)
      // 奥の前足の足先（少し前へ出る）
      ..quadraticBezierTo(144.5, 116.5, 145.5, 121)
      ..quadraticBezierTo(146.5, _groundY + 1, 153, _groundY + 1)
      ..lineTo(189, _groundY + 1)
      // 後ろ足の足先から、おしりの丸み、背中へ
      ..quadraticBezierTo(200, _groundY + 1.5, 203.5, 119)
      ..cubicTo(211, 107, 208, 92, 198, 82)
      ..cubicTo(192, 74, 185, 68, 177, 66)
      ..close();
    canvas.drawPath(body, paint);

    // 背中の毛並みの明るいところ
    canvas.drawPath(
      Path()
        ..moveTo(195, 84)
        ..cubicTo(204, 94, 205, 108, 200, 117),
      Paint()
        ..color = _furLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );

    final line = Paint()
      ..color = _furLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    // 奥の前足とおなかの境目
    canvas.drawLine(const Offset(163, 100), const Offset(162, _groundY - 5), line);
    // 後ろ足（太もも）の丸み
    canvas.drawPath(
      Path()
        ..moveTo(188, 97)
        ..quadraticBezierTo(176, 106, 179, _groundY - 4),
      line,
    );

    // 足先の指（奥の前足と後ろ足）
    final toe = Paint()
      ..color = _furLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final x in const [150.0, 154.5, 193.5, 198.0]) {
      canvas.drawLine(
          Offset(x, _groundY - 3.2), Offset(x, _groundY - 0.3), toe);
    }
    canvas.restore();
  }

  /// はじく側（手前）の前足。肩から手先へ伸び、手先は丸い
  void _paintNearLeg(Canvas canvas, CatMotion motion) {
    final shoulder =
        _shoulder + Offset(motion.wiggle * 0.6 - 1.2 * motion.lean, 0);
    final paw = motion.paw;
    final leg = Paint()
      ..color = _catColor
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(shoulder, paw, leg);

    // 手先（肉球のある丸み）
    final direction = (paw - shoulder).direction;
    canvas.save();
    canvas.translate(paw.dx, paw.dy);
    canvas.rotate(direction - math.pi / 2);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 1.5), width: 15, height: 12),
      Paint()..color = _catColor,
    );
    final toe = Paint()
      ..color = _furLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final x in const [-2.6, 2.6]) {
      canvas.drawLine(Offset(x, 3.2), Offset(x, 6.4), toe);
    }
    canvas.restore();
  }

  void _paintHead(Canvas canvas, CatMotion motion) {
    final paint = Paint()..color = _catColor;
    final look = motion.away;

    canvas.save();
    // 毛糸玉を目で追って、頭を少しかしげる
    canvas.translate(_headCenter.dx - 1.5 * look, _headCenter.dy);
    canvas.rotate(-0.085 * look - 0.02 * motion.excitement);
    canvas.translate(-_headCenter.dx, -_headCenter.dy);

    _paintEar(canvas, mirrored: false, flick: 0);
    _paintEar(canvas, mirrored: true, flick: motion.earFlick);

    // 頭（ほおがふっくらした形）
    canvas.drawOval(
        Rect.fromCenter(center: _headCenter, width: 66, height: 55), paint);
    for (final side in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_headCenter.dx + side * 22, _headCenter.dy + 11),
          width: 27,
          height: 26,
        ),
        paint,
      );
      // ほおの毛先（小さくひとつだけ）
      canvas.drawPath(
        Path()
          ..moveTo(_headCenter.dx + side * 31, _headCenter.dy + 9)
          ..quadraticBezierTo(
            _headCenter.dx + side * 38.5, _headCenter.dy + 15,
            _headCenter.dx + side * 39.5, _headCenter.dy + 19.5,
          )
          ..quadraticBezierTo(
            _headCenter.dx + side * 34, _headCenter.dy + 20.5,
            _headCenter.dx + side * 28, _headCenter.dy + 21,
          )
          ..close(),
        paint,
      );
    }

    // 頭のてっぺんの明るいところ
    canvas.drawArc(
      Rect.fromCenter(center: _headCenter, width: 56, height: 45),
      math.pi * 1.12,
      math.pi * 0.36,
      false,
      Paint()
        ..color = _furLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );

    _paintWhiskers(canvas, motion);
    _paintEyes(canvas, motion);

    // 鼻
    final nose = Path()
      ..moveTo(_headCenter.dx - 3.6, _headCenter.dy + 12)
      ..quadraticBezierTo(_headCenter.dx, _headCenter.dy + 10.6,
          _headCenter.dx + 3.6, _headCenter.dy + 12)
      ..quadraticBezierTo(_headCenter.dx, _headCenter.dy + 17,
          _headCenter.dx - 3.6, _headCenter.dy + 12)
      ..close();
    canvas.drawPath(nose, Paint()..color = _noseColor);

    // 口（ω の形）
    final mouth = Paint()
      ..color = _furLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final side in const [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(_headCenter.dx, _headCenter.dy + 15.2)
          ..quadraticBezierTo(
            _headCenter.dx + side * 1.2, _headCenter.dy + 19.6,
            _headCenter.dx + side * 5.4, _headCenter.dy + 18.2,
          ),
        mouth,
      );
    }

    canvas.restore();
  }

  void _paintEar(Canvas canvas, {required bool mirrored, required double flick}) {
    final side = mirrored ? 1.0 : -1.0;
    double x(double dx) => _headCenter.dx + side * dx;

    canvas.save();
    if (flick != 0) {
      // 付け根を支点に、ぴくっと動かす
      canvas.translate(x(20), 40);
      canvas.rotate(flick);
      canvas.translate(-x(20), -40);
    }
    final ear = Path()
      ..moveTo(x(28), 47)
      ..quadraticBezierTo(x(30), 21, x(23), 12)
      ..quadraticBezierTo(x(11), 18, x(1), 31)
      ..close();
    canvas.drawPath(ear, Paint()..color = _catColor);

    // 耳の内側
    final inner = Path()
      ..moveTo(x(24.5), 39)
      ..quadraticBezierTo(x(25.5), 25, x(21.5), 19.5)
      ..quadraticBezierTo(x(14.5), 24, x(10), 31.5)
      ..close();
    canvas.drawPath(inner, Paint()..color = _innerEarColor);
    canvas.restore();
  }

  void _paintWhiskers(Canvas canvas, CatMotion motion) {
    final paint = Paint()
      ..color = _whiskerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    // わくわくしている時は、ひげが少し前へ張る
    final lift = 1.6 * motion.excitement;
    for (final side in const [-1.0, 1.0]) {
      final root = Offset(_headCenter.dx + side * 17, _headCenter.dy + 15);
      for (final (dy, length) in const [(-5.0, 23.0), (0.0, 25.0), (5.0, 22.0)]) {
        final end = Offset(
          root.dx + side * length,
          root.dy + dy * 1.5 - lift * (1 - dy.abs() / 8),
        );
        canvas.drawPath(
          Path()
            ..moveTo(root.dx, root.dy + dy * 0.45)
            ..quadraticBezierTo(
              (root.dx + end.dx) / 2,
              (root.dy + end.dy) / 2 - 1.4,
              end.dx,
              end.dy,
            ),
          paint,
        );
      }
    }
  }

  void _paintEyes(Canvas canvas, CatMotion motion) {
    final look = motion.away;
    final open = motion.eyeOpen;
    // わくわくすると瞳が大きく丸くなる
    final pupilWidth = 9.4 + 3.2 * motion.excitement;
    final pupilHeight = 12.6 + 1.4 * motion.excitement;
    // 玉のある左下を見る
    final gaze = Offset(-3.0 * look - 1.0, 1.6);

    for (final side in const [-1.0, 1.0]) {
      final center = Offset(_headCenter.dx + side * 13.5, _headCenter.dy);
      final eye = Rect.fromCenter(
          center: center, width: 19.5, height: math.max(1.8, 22.5 * open));

      canvas.save();
      canvas.clipPath(Path()..addOval(eye));
      canvas.drawOval(eye, Paint()..color = _eyeColor);
      // 目の下側に淡い陰を入れて、丸みを出す
      canvas.drawOval(
        Rect.fromCenter(
            center: center + const Offset(0, 9), width: 24, height: 12),
        Paint()..color = _eyeShade,
      );
      if (open > 0.35) {
        final pupil = center + gaze;
        canvas.drawOval(
          Rect.fromCenter(
              center: pupil, width: pupilWidth, height: pupilHeight),
          Paint()..color = _catColor,
        );
        // 瞳のきらめき
        canvas.drawCircle(
            pupil + const Offset(-2.4, -3.2), 2.5, Paint()..color = Colors.white);
        canvas.drawCircle(
            pupil + const Offset(2.2, 2.6), 1.1, Paint()..color = Colors.white);
      }
      canvas.restore();
    }
  }

  void _paintBall(Canvas canvas, Offset center, CatMotion motion) {
    final ballRect = Rect.fromCircle(center: center, radius: _ballRadius);
    canvas.drawCircle(center, _ballRadius, Paint()..color = _yarnColor);

    canvas.save();
    canvas.clipPath(Path()..addOval(ballRect));
    // 光の当たる左上は明るく、右下は暗く（玉は回っても光の向きは変わらない）
    canvas.drawCircle(center + const Offset(8, 9), _ballRadius,
        Paint()..color = _yarnShade.withValues(alpha: 0.55));
    canvas.drawCircle(center + const Offset(-3, -4), _ballRadius - 3,
        Paint()..color = _yarnColor);
    canvas.drawCircle(center + const Offset(-8, -9), 8,
        Paint()..color = _yarnLight.withValues(alpha: 0.7));

    // 糸の巻き目。玉の内側だけに描き、玉と一緒に回転させる
    canvas.translate(center.dx, center.dy);
    canvas.rotate(motion.ballAngle);
    final wrap = Paint()
      ..color = _catColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    // 斜めに巻かれた帯
    for (final dy in const [-19.0, -9.0, 1.0, 11.0, 21.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(-_ballRadius - 4, dy + 9)
          ..quadraticBezierTo(0, dy - 9, _ballRadius + 4, dy + 5),
        wrap,
      );
    }
    // 交差する向きの帯
    for (final dx in const [-13.0, 0.0, 13.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(dx - 6, -_ballRadius - 4)
          ..quadraticBezierTo(dx + 12, -4, dx - 3, _ballRadius * 0.3),
        wrap,
      );
    }
    canvas.restore();

    // 外枠
    canvas.drawCircle(
      center,
      _ballRadius,
      Paint()
        ..color = _catColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  /// 玉をはじいた瞬間の勢いを示す短い線
  void _paintImpact(Canvas canvas, CatMotion motion) {
    final strength = motion.impact;
    if (strength <= 0) return;
    final paint = Paint()
      ..color = _catColor.withValues(alpha: 0.75 * strength)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const origin = Offset(CatMotion.ballRestX + _ballRadius + 3, 96);
    final reach = 4 + 6 * (1 - strength);
    for (final angle in const [-0.9, -0.25, 0.4]) {
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
          origin + direction * reach, origin + direction * (reach + 5), paint);
    }
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
