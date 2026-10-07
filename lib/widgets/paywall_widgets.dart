import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cat_loading.dart';

/// 購入画面の配色（ライト／ダーク）
class PaywallPalette {
  const PaywallPalette({
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accentStart,
    required this.accentEnd,
    required this.onAccent,
    required this.tint,
    required this.border,
    required this.chip,
    required this.chipInk,
    required this.danger,
    required this.heroTop,
    required this.heroBottom,
    required this.panel,
  });

  final Color background;
  final Color surface;

  /// 見出し・本文の文字色
  final Color ink;

  /// 補足の文字色
  final Color muted;

  /// 強調に使うアプリのピンク
  final Color accent;

  /// 購入ボタンのグラデーション
  final Color accentStart;
  final Color accentEnd;
  final Color onAccent;

  /// アクセント色の薄い面
  final Color tint;
  final Color border;

  /// 「無料プランでは」を示すチップの面と文字
  final Color chip;
  final Color chipInk;
  final Color danger;

  /// イラストの背景（黒猫や編み目記号が見えるよう、ダークモードでも明るい色）
  final Color heroTop;
  final Color heroBottom;
  final Color panel;

  static const PaywallPalette light = PaywallPalette(
    background: Color(0xFFFFF8F6),
    surface: Colors.white,
    ink: Color(0xFF32262B),
    muted: Color(0xFF7B6B72),
    accent: Color(0xFFD81B60),
    accentStart: Color(0xFFDD2C6A),
    accentEnd: Color(0xFFC2185B),
    onAccent: Colors.white,
    tint: Color(0xFFFDE8EF),
    border: Color(0xFFF1DEE3),
    chip: Color(0xFFF5ECEF),
    chipInk: Color(0xFF5F5158),
    danger: Color(0xFFA93838),
    heroTop: Color(0xFFFFE6DD),
    heroBottom: Color(0xFFFFD3DF),
    panel: Color(0xFFFDE8EF),
  );

  static const PaywallPalette dark = PaywallPalette(
    background: Color(0xFF1E191C),
    surface: Color(0xFF2B2428),
    ink: Color(0xFFF8EFF1),
    muted: Color(0xFFCBBBC1),
    accent: Color(0xFFF48FB1),
    accentStart: Color(0xFFF8A8C3),
    accentEnd: Color(0xFFF48FB1),
    onAccent: Color(0xFF3B0F22),
    tint: Color(0xFF40262F),
    border: Color(0xFF4C3A41),
    chip: Color(0xFF3A3035),
    chipInk: Color(0xFFD9CBD0),
    danger: Color(0xFFFFB4AB),
    heroTop: Color(0xFFF6D6CC),
    heroBottom: Color(0xFFF0C1CF),
    panel: Color(0xFFF3D6DE),
  );

  static PaywallPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

// イラストの中で使う色（背景が明るいので、ライト／ダーク共通）
const Color _illustrationInk = Color(0xFF32262B);
const Color _illustrationLine = Color(0xFFE7B9C6);
const Color _illustrationAccent = Color(0xFFD81B60);
const Color _illustrationShadow = Color(0x26A0505A);
const Color _yarnOrange = Color(0xFFF7922D);

/// [animation] のうち start〜start+length の区間を 0→1 に引き伸ばす
Animation<double> paywallInterval(
  Animation<double> animation,
  double start,
  double length, {
  Curve curve = Curves.easeOutCubic,
}) {
  return animation.drive(
    CurveTween(
      curve: Interval(start, math.min(1.0, start + length), curve: curve),
    ),
  );
}

/// 文字に添えるアイコンの大きさ。文字サイズの設定に合わせて大きくする（最大2倍）
double paywallIconSize(BuildContext context, double size) =>
    size * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);

/// 画面に入った時に一度だけアニメーションを再生する。
///
/// 画面を開いた時点で見えていれば [delay] だけ待って（上から順に現れるように）、
/// スクロールで現れた時は待たずに再生する。再生は1回きりで、繰り返さない。
class PaywallReveal extends StatefulWidget {
  const PaywallReveal({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 480),
    this.delay = Duration.zero,
  });

  final Duration duration;
  final Duration delay;

  /// progress は現れてから 0→1 に進む
  final Widget Function(BuildContext context, Animation<double> progress)
      builder;

  @override
  State<PaywallReveal> createState() => _PaywallRevealState();
}

class _PaywallRevealState extends State<PaywallReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  late final double _delayFraction;

  ScrollableState? _scrollable;
  ScrollPosition? _position;
  bool _reduceMotion = false;
  bool _started = false;
  bool _checkedOnce = false;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    _delayFraction = total == Duration.zero
        ? 0
        : widget.delay.inMicroseconds / total.inMicroseconds;
    _controller = AnimationController(vsync: this, duration: total);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(_delayFraction, 1),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _scrollable = Scrollable.maybeOf(context);
    final position = _scrollable?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_check);
      _position = position;
      if (!_started) _position?.addListener(_check);
    }
    _scheduleCheck();
  }

  @override
  void didUpdateWidget(PaywallReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // まわりの表示が変わって、スクロールせずに画面へ入ることがある
    _scheduleCheck();
  }

  void _scheduleCheck() {
    if (_started) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_started || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;

    var visible = true;
    final viewport = _scrollable?.context.findRenderObject();
    if (viewport is RenderBox && viewport.attached && viewport.hasSize) {
      final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      // 上端が少し画面に入ったら現れる
      visible = top < viewport.size.height - 24 && top + box.size.height > 0;
    }
    final openedVisible = !_checkedOnce;
    _checkedOnce = true;
    if (!visible) return;

    _started = true;
    _position?.removeListener(_check);
    if (_reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward(from: openedVisible ? 0 : _delayFraction);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _progress);
}

/// 下からふわっと現れる入場アニメーション
class PaywallEntrance extends StatelessWidget {
  const PaywallEntrance({
    super.key,
    required this.animation,
    required this.child,
    this.start = 0,
    this.length = 1,
  });

  final Animation<double> animation;
  final double start;
  final double length;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final progress = paywallInterval(animation, start, length);
    return FadeTransition(
      opacity: progress,
      // 現れる前でも読み上げの対象から外さない（スクロールで辿り着けるように）
      alwaysIncludeSemantics: true,
      child: AnimatedBuilder(
        animation: progress,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 18 * (1 - progress.value)),
          child: child,
        ),
      ),
    );
  }
}

/// 画面上部のイラスト。猫が毛糸玉を転がし、まわりに編み目記号が現れる。
/// タップするともう一度転がす。
class PaywallHero extends StatefulWidget {
  const PaywallHero({super.key, required this.palette});

  final PaywallPalette palette;

  // この大きさで配置を決め、表示幅に合わせて全体を拡大・縮小する
  static const double _designWidth = 350;
  static const double _designHeight = 168;

  // 記号の画像・左上の位置・大きさ・傾き
  static const List<(String, Offset, double, double)> _symbols = [
    ('assets/images/magic_ring.png', Offset(16, 56), 40, -0.14),
    ('assets/images/dc_front_post.png', Offset(62, 14), 44, 0.10),
    ('assets/images/長編み３目の玉編み目.png', Offset(122, 34), 38, -0.06),
    ('assets/images/dc_5_shell.png', Offset(254, 12), 44, 0.12),
    ('assets/images/picot_slip.png', Offset(298, 64), 40, -0.10),
  ];

  /// イラストに使う画像
  static List<String> get assets => [for (final symbol in _symbols) symbol.$1];

  @override
  State<PaywallHero> createState() => _PaywallHeroState();
}

class _PaywallHeroState extends State<PaywallHero>
    with TickerProviderStateMixin {
  // 猫が毛糸玉を転がす回数
  static const int _catLoops = 2;

  // 記号が順に現れる演出
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  // 猫が毛糸玉を転がす演出
  late final AnimationController _play = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2900),
  );

  bool _reduceMotion = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_started) return;
    _started = true;
    if (_reduceMotion) {
      _pop.value = 1;
      _play.value = 1;
    } else {
      _pop.forward();
      _play.forward();
    }
  }

  void _replay() {
    if (_reduceMotion || _play.isAnimating) return;
    _play.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    _play.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const width = PaywallHero._designWidth;
    const height = PaywallHero._designHeight;
    const catWidth = 210.0;
    final radius = BorderRadius.circular(28);

    return ExcludeSemantics(
      child: GestureDetector(
        onTap: _replay,
        child: RepaintBoundary(
          child: AspectRatio(
            aspectRatio: width / height,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: width,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.palette.heroTop,
                        widget.palette.heroBottom,
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      children: [
                        // やわらかい光の円
                        const Positioned(
                          left: -46,
                          bottom: -78,
                          child: _SoftCircle(size: 200, opacity: 0.34),
                        ),
                        const Positioned(
                          right: -34,
                          top: -64,
                          child: _SoftCircle(size: 160, opacity: 0.26),
                        ),
                        Positioned.fill(
                          child: CustomPaint(painter: _SparklePainter(_play)),
                        ),
                        // 猫と毛糸玉
                        Positioned(
                          left: 63,
                          bottom: 2,
                          width: catWidth,
                          height: catWidth * CatLoadingPainter.aspectRatio,
                          child: AnimatedBuilder(
                            animation: _play,
                            builder: (context, _) => CustomPaint(
                              painter: CatLoadingPainter(
                                progress: (_play.value * _catLoops) % 1.0,
                                showStage: false,
                              ),
                            ),
                          ),
                        ),
                        for (var i = 0; i < PaywallHero._symbols.length; i++)
                          Positioned(
                            left: PaywallHero._symbols[i].$2.dx,
                            top: PaywallHero._symbols[i].$2.dy,
                            child: _HeroSymbol(
                              asset: PaywallHero._symbols[i].$1,
                              size: PaywallHero._symbols[i].$3,
                              angle: PaywallHero._symbols[i].$4,
                              phase: i * 0.21,
                              pop: paywallInterval(_pop, 0.06 + i * 0.13, 0.42,
                                  curve: Curves.easeOutBack),
                              play: _play,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

/// ヒーローに散らすきらめき。猫が遊んでいる間だけまたたく
class _SparklePainter extends CustomPainter {
  _SparklePainter(this.play) : super(repaint: play);

  final Animation<double> play;

  // 中心の位置・大きさ・またたきのずれ
  static const List<(Offset, double, double)> _sparkles = [
    (Offset(22, 24), 6.0, 0.0),
    (Offset(178, 16), 5.0, 0.35),
    (Offset(320, 30), 6.5, 0.6),
    (Offset(30, 126), 4.5, 0.8),
    (Offset(322, 134), 5.0, 0.15),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = play.value;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.92);
    for (final (center, radius, phase) in _sparkles) {
      final twinkle =
          0.62 + 0.38 * math.sin(2 * math.pi * (t * 2 + phase)).abs();
      final r = radius * twinkle;
      // 4方向に尖った星
      final path = Path()..moveTo(center.dx, center.dy - r);
      for (var i = 1; i <= 4; i++) {
        final angle = -math.pi / 2 + i * math.pi / 2;
        path.quadraticBezierTo(
          center.dx,
          center.dy,
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => oldDelegate.play != play;
}

/// 編み目記号のボタン。アプリの編み方ボタンと同じ見た目
class _StitchTile extends StatelessWidget {
  const _StitchTile({required this.asset, required this.size, this.shadow});

  final String asset;
  final double size;
  final BoxShadow? shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        // 画像に描かれている枠の角丸に合わせる
        borderRadius: BorderRadius.circular(size * 0.1),
        boxShadow: [if (shadow != null) shadow!],
      ),
      child: Image.asset(asset, width: size, height: size),
    );
  }
}

/// ヒーローに浮かぶ編み目記号
class _HeroSymbol extends StatelessWidget {
  const _HeroSymbol({
    required this.asset,
    required this.size,
    required this.angle,
    required this.phase,
    required this.pop,
    required this.play,
  });

  final String asset;
  final double size;
  final double angle;
  final double phase;

  /// 現れる時の拡大（0→1）
  final Animation<double> pop;

  /// 猫が遊んでいる間の進行。この間だけ上下にゆれる
  final Animation<double> play;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pop, play]),
      child: _StitchTile(
        asset: asset,
        size: size,
        shadow: const BoxShadow(
          color: _illustrationShadow,
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ),
      builder: (context, child) {
        final t = play.value;
        // 始まりと終わりで揺れ幅が0になるので、止まった時に元の位置へ戻る
        final float = -3.5 *
            math.sin(2 * math.pi * (t * 2 + phase)) *
            math.sin(math.pi * t);
        return Transform.translate(
          offset: Offset(0, float),
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(scale: pop.value, child: child),
          ),
        );
      },
    );
  }
}

/// 特典1件ぶんのカード。イラスト・見出し・「無料 → プレミアム」の比較・説明を並べる。
class PaywallBenefitCard extends StatelessWidget {
  const PaywallBenefitCard({
    super.key,
    required this.palette,
    required this.illustration,
    required this.title,
    required this.description,
    required this.freeLabel,
    required this.freeValue,
    required this.premiumValue,
    this.compareOnOneLine = true,
  });

  final PaywallPalette palette;
  final Widget illustration;
  final String title;
  final String description;

  /// 「無料」
  final String freeLabel;

  /// 無料プランでの状態（例: 3作品まで）
  final String freeValue;

  /// プレミアムでの状態（例: 無制限）
  final String premiumValue;

  /// 「無料 → プレミアム」を1行に並べるか。カードごとに折り返しが違うと不揃いに
  /// 見えるので、[fitsCompareOnOneLine] で全カードまとめて決めた値を渡す
  final bool compareOnOneLine;

  static const double _padding = 12;
  static const double _borderWidth = 1;
  static const double _illustrationGap = 13;

  /// 文字を大きくしている時や幅が狭い時は、イラストを上に置いて文字の幅を確保する
  static bool _isStacked(BuildContext context, double innerWidth) =>
      MediaQuery.textScalerOf(context).scale(1) > 1.35 || innerWidth < 250;

  /// 幅 [cardWidth] のカードで、[values]（無料での状態, プレミアムでの状態）の
  /// 比較がどれも1行に収まるか
  static bool fitsCompareOnOneLine(
    BuildContext context, {
    required double cardWidth,
    required String freeLabel,
    required Iterable<(String, String)> values,
  }) {
    final innerWidth = cardWidth - 2 * (_padding + _borderWidth);
    final available = _isStacked(context, innerWidth)
        ? innerWidth
        : innerWidth - _IllustrationPanel.width - _illustrationGap;
    return values.every(
      (value) =>
          _CompareRow.oneLineWidth(
            context,
            freeLabel: freeLabel,
            freeValue: value.$1,
            premiumValue: value.$2,
          ) <=
          available,
    );
  }

  @override
  Widget build(BuildContext context) {
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 7),
        _CompareRow(
          palette: palette,
          freeLabel: freeLabel,
          freeValue: freeValue,
          premiumValue: premiumValue,
          oneLine: compareOnOneLine,
        ),
        const SizedBox(height: 7),
        Text(
          description,
          style: TextStyle(color: palette.muted, fontSize: 12.5, height: 1.55),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border, width: _borderWidth),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_isStacked(context, constraints.maxWidth)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [illustration, const SizedBox(height: 10), texts],
            );
          }
          return Row(
            children: [
              illustration,
              const SizedBox(width: _illustrationGap),
              Expanded(child: texts),
            ],
          );
        },
      ),
    );
  }
}

/// 「無料 3作品まで → ✓ 無制限」のように、無料とプレミアムの違いを並べる
class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.palette,
    required this.freeLabel,
    required this.freeValue,
    required this.premiumValue,
    required this.oneLine,
  });

  final PaywallPalette palette;
  final String freeLabel;
  final String freeValue;
  final String premiumValue;

  /// 1行に並べるか（falseなら「→ プレミアム」を2行目に置く）
  final bool oneLine;

  static const EdgeInsets _chipPadding =
      EdgeInsets.symmetric(horizontal: 8, vertical: 4);
  static const double _labelGap = 5;
  static const double _groupGap = 6;
  static const double _arrowSize = 14;
  static const double _arrowGap = 6;
  static const double _checkSize = 13;
  static const double _checkGap = 3;

  static const TextStyle _freeLabelStyle =
      TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, height: 1.3);
  static const TextStyle _freeValueStyle =
      TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, height: 1.3);
  static const TextStyle _premiumStyle =
      TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.3);

  /// 1行に並べた時に必要な幅
  static double oneLineWidth(
    BuildContext context, {
    required String freeLabel,
    required String freeValue,
    required String premiumValue,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final base = DefaultTextStyle.of(context).style;
    double textWidth(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: base.merge(style)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final freeChip = _chipPadding.horizontal +
        textWidth(freeLabel, _freeLabelStyle) +
        _labelGap +
        textWidth(freeValue, _freeValueStyle);
    final premiumChip = _chipPadding.horizontal +
        paywallIconSize(context, _checkSize) +
        _checkGap +
        textWidth(premiumValue, _premiumStyle);
    return freeChip +
        _groupGap +
        paywallIconSize(context, _arrowSize) +
        _arrowGap +
        premiumChip;
  }

  @override
  Widget build(BuildContext context) {
    // 無料プランでの状態
    final freeChip = Container(
      padding: _chipPadding,
      decoration: BoxDecoration(
        color: palette.chip,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            freeLabel,
            style: _freeLabelStyle.copyWith(color: palette.chipInk),
          ),
          const SizedBox(width: _labelGap),
          Flexible(
            child: Text(
              freeValue,
              style: _freeValueStyle.copyWith(color: palette.chipInk),
            ),
          ),
        ],
      ),
    );
    final arrow = Icon(
      Icons.arrow_forward_rounded,
      size: paywallIconSize(context, _arrowSize),
      color: palette.muted,
    );
    // プレミアムでの状態
    final premiumChip = Container(
      padding: _chipPadding,
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_rounded,
            size: paywallIconSize(context, _checkSize),
            color: palette.onAccent,
          ),
          const SizedBox(width: _checkGap),
          Flexible(
            child: Text(
              premiumValue,
              style: _premiumStyle.copyWith(color: palette.onAccent),
            ),
          ),
        ],
      ),
    );

    // 読み上げでは「無料 3作品まで 無制限」をひとまとまりで伝える
    if (oneLine) {
      // 幅の見積もりとわずかにずれても折り返さないよう、収まらない分は縮める
      return MergeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              freeChip,
              const SizedBox(width: _groupGap),
              arrow,
              const SizedBox(width: _arrowGap),
              premiumChip,
            ],
          ),
        ),
      );
    }
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          freeChip,
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              arrow,
              const SizedBox(width: _arrowGap),
              Flexible(child: premiumChip),
            ],
          ),
        ],
      ),
    );
  }
}

/// 特典のイラストを載せる小さなパネル
class _IllustrationPanel extends StatelessWidget {
  const _IllustrationPanel({required this.palette, required this.child});

  final PaywallPalette palette;
  final Widget child;

  static const double width = 92;
  static const double height = 76;
  static const Size size = Size(width, height);

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// 「作品の保存が無制限」: 重なっていた作品カードが扇状に広がり、∞ が付く
class PaywallProjectsIllustration extends StatelessWidget {
  const PaywallProjectsIllustration({
    super.key,
    required this.palette,
    required this.progress,
  });

  final PaywallPalette palette;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return _IllustrationPanel(
      palette: palette,
      child: CustomPaint(
        size: _IllustrationPanel.size,
        painter: _ProjectsPainter(progress),
      ),
    );
  }
}

class _ProjectsPainter extends CustomPainter {
  _ProjectsPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  // 作品ごとの毛糸の色
  static const List<Color> _yarnColors = [
    Color(0xFF7CB342),
    _yarnOrange,
    Color(0xFFEC407A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value.clamp(0.0, 1.0);
    final spread = Curves.easeOutBack.transform((t / 0.6).clamp(0.0, 1.0));
    const pivot = Offset(44, 74);

    // 左・右・中央の順に描く（中央のカードが一番上）
    for (final index in const [-1, 1, 0]) {
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(index * 0.30 * spread);
      canvas.translate(-pivot.dx, -pivot.dy);
      final card = RRect.fromRectAndRadius(
        const Rect.fromLTWH(27, 17, 34, 46),
        const Radius.circular(7),
      );
      canvas.drawRRect(
        card.shift(const Offset(0, 1.5)),
        Paint()..color = _illustrationShadow,
      );
      canvas.drawRRect(card, Paint()..color = Colors.white);
      canvas.drawRRect(
        card,
        Paint()
          ..color = _illustrationLine
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      // 毛糸玉と作品名の行
      canvas.drawCircle(
        const Offset(37, 28),
        5,
        Paint()..color = _yarnColors[index + 1],
      );
      final line = Paint()
        ..color = _illustrationLine
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(33, 41), const Offset(55, 41), line);
      canvas.drawLine(const Offset(33, 49), const Offset(49, 49), line);
      canvas.restore();
    }

    // 「無制限」のバッジ
    final pop = Curves.easeOutBack.transform(((t - 0.5) / 0.5).clamp(0.0, 1.0));
    if (pop <= 0) return;
    const center = Offset(73, 18);
    canvas.drawCircle(center, 11.5 * pop, Paint()..color = Colors.white);
    canvas.drawCircle(center, 10 * pop, Paint()..color = _illustrationAccent);
    // ∞ の形（レムニスケート）
    const a = 6.6;
    final infinity = Path();
    for (var i = 0; i <= 48; i++) {
      final angle = 2 * math.pi * i / 48;
      final denominator = 1 + math.sin(angle) * math.sin(angle);
      final x = center.dx + a * pop * math.cos(angle) / denominator;
      final y = center.dy +
          a * pop * 1.35 * math.sin(angle) * math.cos(angle) / denominator;
      if (i == 0) {
        infinity.moveTo(x, y);
      } else {
        infinity.lineTo(x, y);
      }
    }
    canvas.drawPath(
      infinity,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ProjectsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 「編み方ボタンをカスタマイズ」: 実際の編み目記号が1つずつ並んでいく
class PaywallStitchesIllustration extends StatelessWidget {
  const PaywallStitchesIllustration({
    super.key,
    required this.palette,
    required this.progress,
  });

  final PaywallPalette palette;
  final Animation<double> progress;

  /// イラストに使う画像（上段・下段の順）
  static const List<String> assets = [
    'assets/images/細編み.png',
    'assets/images/長編み.png',
    'assets/images/magic_ring.png',
    'assets/images/dc_front_post.png',
    'assets/images/picot_slip.png',
    'assets/images/dc_5_shell.png',
  ];

  static const int _columns = 3;

  @override
  Widget build(BuildContext context) {
    Widget tile(int index) => ScaleTransition(
          scale: paywallInterval(progress, index * 0.11, 0.42,
              curve: Curves.easeOutBack),
          child: _StitchTile(asset: assets[index], size: 24),
        );

    return _IllustrationPanel(
      palette: palette,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var row = 0; row < assets.length ~/ _columns; row++) ...[
            if (row > 0) const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var column = 0; column < _columns; column++) ...[
                  if (column > 0) const SizedBox(width: 5),
                  tile(row * _columns + column),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 「広告なし」: 画面下の広告が消えて、すっきりした画面になる
class PaywallNoAdsIllustration extends StatelessWidget {
  const PaywallNoAdsIllustration({
    super.key,
    required this.palette,
    required this.progress,
  });

  final PaywallPalette palette;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final textStyle = DefaultTextStyle.of(context).style;
    return _IllustrationPanel(
      palette: palette,
      child: CustomPaint(
        size: _IllustrationPanel.size,
        painter: _NoAdsPainter(
          progress,
          fontFamily: textStyle.fontFamily,
          fontFamilyFallback: textStyle.fontFamilyFallback,
        ),
      ),
    );
  }
}

class _NoAdsPainter extends CustomPainter {
  _NoAdsPainter(this.progress, {this.fontFamily, this.fontFamilyFallback})
      : super(repaint: progress);

  final Animation<double> progress;
  final String? fontFamily;
  final List<String>? fontFamilyFallback;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value.clamp(0.0, 1.0);

    // スマートフォン
    final phone = RRect.fromRectAndRadius(
      const Rect.fromLTWH(27, 7, 38, 62),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      phone.shift(const Offset(0, 2)),
      Paint()..color = _illustrationShadow,
    );
    canvas.drawRRect(phone, Paint()..color = Colors.white);

    // 画面の中身（段数の表示と編み方ボタン）
    canvas.drawLine(
      const Offset(35, 18),
      const Offset(50, 18),
      Paint()
        ..color = _illustrationLine
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );
    for (var row = 0; row < 2; row++) {
      for (var column = 0; column < 3; column++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(33.5 + column * 9, 26.0 + row * 9, 7, 7),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFFF7D9E2),
        );
      }
    }

    // 広告バナー: 下へ滑り落ちて消える
    final leave =
        Curves.easeInCubic.transform(((t - 0.12) / 0.45).clamp(0.0, 1.0));
    if (leave < 1) {
      canvas.save();
      canvas.clipRRect(phone);
      final banner = RRect.fromRectAndRadius(
        Rect.fromLTWH(31, 52 + 18 * leave, 30, 12),
        const Radius.circular(3),
      );
      canvas.drawRRect(banner, Paint()..color = _yarnOrange);
      final label = TextPainter(
        text: TextSpan(
          text: 'AD',
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            height: 1,
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        banner.center - Offset(label.width / 2, label.height / 2),
      );
      label.dispose();
      canvas.restore();
    }

    // 本体の枠は広告より手前に描く
    canvas.drawRRect(
      phone,
      Paint()
        ..color = _illustrationInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // 広告が消えたあとのチェック
    final check =
        Curves.easeOutBack.transform(((t - 0.55) / 0.45).clamp(0.0, 1.0));
    if (check <= 0) return;
    const center = Offset(67, 56);
    canvas.drawCircle(center, 12.5 * check, Paint()..color = Colors.white);
    canvas.drawCircle(
        center, 11 * check, Paint()..color = const Color(0xFF43A047));
    final mark = Path()
      ..moveTo(center.dx - 5 * check, center.dy + 0.5 * check)
      ..lineTo(center.dx - 1.5 * check, center.dy + 4 * check)
      ..lineTo(center.dx + 5 * check, center.dy - 3.5 * check);
    canvas.drawPath(
      mark,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_NoAdsPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.fontFamily != fontFamily;
}

/// プランの選択状態を示す丸印。選ぶとチェックがぽんと現れる
class PaywallSelectionMark extends StatelessWidget {
  const PaywallSelectionMark({
    super.key,
    required this.palette,
    required this.selected,
  });

  final PaywallPalette palette;
  final bool selected;

  static const Duration _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _duration,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? palette.accent : palette.accent.withValues(alpha: 0),
        border: Border.all(
          color: selected ? palette.accent : palette.muted,
          width: 2,
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: _duration,
        curve: Curves.easeOutBack,
        child: Icon(Icons.check_rounded, size: 16, color: palette.onAccent),
      ),
    );
  }
}

/// ボタンの上を光が一度だけ横切る演出。
///
/// 押せるようになった時と、[trigger]（選択中のプラン）が変わった時に再生する。
class PaywallShine extends StatefulWidget {
  const PaywallShine({
    super.key,
    required this.child,
    required this.borderRadius,
    required this.enabled,
    this.trigger,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final bool enabled;
  final Object? trigger;

  @override
  State<PaywallShine> createState() => _PaywallShineState();
}

class _PaywallShineState extends State<PaywallShine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  bool _reduceMotion = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_started) return;
    _started = true;
    _play();
  }

  @override
  void didUpdateWidget(PaywallShine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled ||
        widget.trigger != oldWidget.trigger) {
      _play();
    }
  }

  void _play() {
    if (widget.enabled && !_reduceMotion) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: CustomPaint(painter: _ShinePainter(_controller)),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShinePainter extends CustomPainter {
  _ShinePainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final value = progress.value;
    if (value <= 0 || value >= 1) return;
    final t = Curves.easeInOut.transform(value);
    final band = size.width * 0.3;
    final x = -band + (size.width + band * 2) * t;
    final rect = Rect.fromLTWH(-band / 2, -4, band, size.height + 8);
    canvas.save();
    canvas.translate(x, 0);
    canvas.skew(-0.4, 0);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.34),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// プラン読み込み中の仮表示。読み込み中だけツリーに置く（終わったら親が外す）
class PaywallPlanSkeleton extends StatefulWidget {
  const PaywallPlanSkeleton({super.key, required this.palette, this.count = 2});

  final PaywallPalette palette;

  /// 仮表示するプランの数
  final int count;

  @override
  State<PaywallPlanSkeleton> createState() => _PaywallPlanSkeletonState();
}

class _PaywallPlanSkeletonState extends State<PaywallPlanSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  late final Animation<double> _opacity = Tween<double>(begin: 1, end: 0.5)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: widget.palette.border,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: _opacity,
        child: Column(
          children: [
            for (var i = 0; i < widget.count; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: palette.border, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.border, width: 2),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _bar(84, 12),
                          const SizedBox(height: 10),
                          _bar(128, 20),
                          const SizedBox(height: 10),
                          _bar(168, 10),
                        ],
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
}
