import 'dart:math';
import 'package:flutter/material.dart';

/// Geometric low-poly Sage Fox — Cellar Sage mascot.
///
/// Filled-facet sitting fox in brand palette:
///   Midnight Grape  #1A1B26 — body base
///   Deep Violet     #7C54CD — upper back / tail highlight
///   Electric Violet #C3A5FF — chest, muzzle, inner ear (Digital Mentor glow)
///
/// Idle animation: gentle float + ambient sparkle pulse.
class SageFoxWidget extends StatefulWidget {
  final Duration delay;
  const SageFoxWidget({super.key, this.delay = Duration.zero});

  @override
  State<SageFoxWidget> createState() => _SageFoxWidgetState();
}

class _SageFoxWidgetState extends State<SageFoxWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _idle.repeat();
    });
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _idle,
      builder: (_, _) {
        final t = _idle.value;
        return SizedBox(
          width: 200,
          height: 220,
          child: CustomPaint(
            size: const Size(200, 220),
            painter: _FoxPainter(
              floatDy: sin(t * 2 * pi) * 5.0,
              glowPhase: t,
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _FoxPainter extends CustomPainter {
  final double floatDy;
  final double glowPhase;

  _FoxPainter({required this.floatDy, required this.glowPhase});

  static const _midnight = Color(0xFF1A1B26); // body base
  static const _violet   = Color(0xFF7C54CD); // upper back / highlights
  static const _electric = Color(0xFFC3A5FF); // chest / muzzle glow
  static const _ink      = Color(0xFF0F0F14); // pupils / shadow

  Paint _fill(Color c, [double a = 1.0]) => Paint()
    ..color = a < 1.0 ? c.withValues(alpha: a) : c
    ..style = PaintingStyle.fill;

  Paint _edge([double a = 0.24]) => Paint()
    ..color = _electric.withValues(alpha: a)
    ..strokeWidth = 0.9
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _poly(Canvas c, List<Offset> pts, Paint fill, [Paint? stroke]) {
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) { path.lineTo(pts[i].dx, pts[i].dy); }
    path.close();
    c.drawPath(path, fill);
    if (stroke != null) c.drawPath(path, stroke);
  }

  // Applies the float-bob offset to every point in a list.
  List<Offset> _s(List<Offset> pts) =>
      pts.map((p) => Offset(p.dx, p.dy + floatDy)).toList();

  @override
  void paint(Canvas canvas, Size size) {
    _drawTail(canvas);
    _drawBody(canvas);
    _drawHead(canvas);
    _drawEars(canvas);
    _drawFace(canvas);
    _drawPaws(canvas);
    _drawSparkles(canvas);
  }

  // ── Tail ─────────────────────────────────────────────────────────────────
  // Curls up the right side of the body; drawn first (behind body).

  void _drawTail(Canvas canvas) {
    // Main tail — Midnight Grape
    _poly(canvas, _s(const [
      Offset(124, 153), Offset(150, 133), Offset(160, 106),
      Offset(153, 82),  Offset(145, 87),  Offset(149, 110),
      Offset(139, 134), Offset(121, 151),
    ]), _fill(_midnight), _edge());

    // Upper tail facet — Deep Violet (depth highlight)
    _poly(canvas, _s(const [
      Offset(153, 82), Offset(160, 106), Offset(149, 110), Offset(145, 87),
    ]), _fill(_violet), _edge(0.30));

    // Tail tip — Electric Violet glow
    _poly(canvas, _s(const [
      Offset(147, 75), Offset(157, 80), Offset(153, 89), Offset(143, 84),
    ]), _fill(_electric, 0.82), _edge(0.16));
  }

  // ── Body ─────────────────────────────────────────────────────────────────

  void _drawBody(Canvas canvas) {
    // Far-left sliver — Midnight Grape (outer left flank)
    _poly(canvas, _s(const [
      Offset(48, 132), Offset(68, 92), Offset(62, 142), Offset(48, 170),
    ]), _fill(_midnight), _edge());

    // Chest / belly upper — Electric Violet (Digital Mentor glow)
    _poly(canvas, _s(const [
      Offset(68, 92),  Offset(96, 92),  Offset(90, 121),
      Offset(80, 136), Offset(62, 142),
    ]), _fill(_electric, 0.78), _edge(0.32));

    // Chest lower — Electric Violet, softer fade
    _poly(canvas, _s(const [
      Offset(62, 142), Offset(80, 136), Offset(80, 170), Offset(58, 173),
    ]), _fill(_electric, 0.46), _edge(0.18));

    // Upper back / shoulder — Deep Violet highlight
    _poly(canvas, _s(const [
      Offset(96, 92),  Offset(122, 88), Offset(132, 116),
      Offset(112, 127), Offset(90, 121),
    ]), _fill(_violet), _edge(0.28));

    // Mid-right body — Midnight Grape
    _poly(canvas, _s(const [
      Offset(112, 127), Offset(132, 116), Offset(138, 152),
      Offset(120, 164), Offset(92, 154), Offset(80, 136),
    ]), _fill(_midnight), _edge());

    // Lower body base — Midnight Grape
    _poly(canvas, _s(const [
      Offset(58, 173), Offset(80, 170), Offset(92, 154),
      Offset(120, 164), Offset(116, 178), Offset(60, 178),
    ]), _fill(_midnight), _edge());
  }

  // ── Head ─────────────────────────────────────────────────────────────────

  void _drawHead(Canvas canvas) {
    // Upper skull / back of head — Deep Violet (upper light catch)
    _poly(canvas, _s(const [
      Offset(82, 42), Offset(112, 40), Offset(122, 60),
      Offset(102, 68), Offset(84, 62),
    ]), _fill(_violet), _edge(0.28));

    // Face / jaw — Midnight Grape
    _poly(canvas, _s(const [
      Offset(68, 52), Offset(82, 42), Offset(84, 62), Offset(102, 68),
      Offset(96, 92), Offset(68, 92), Offset(60, 72),
    ]), _fill(_midnight), _edge());

    // Muzzle / chin — Electric Violet glow
    _poly(canvas, _s(const [
      Offset(70, 80), Offset(96, 83), Offset(96, 92),
      Offset(68, 92), Offset(60, 83),
    ]), _fill(_electric, 0.72), _edge(0.30));
  }

  // ── Ears ──────────────────────────────────────────────────────────────────

  void _drawEars(Canvas canvas) {
    // Left ear outer — Midnight Grape
    _poly(canvas, _s(const [
      Offset(70, 44), Offset(56, 18), Offset(84, 42),
    ]), _fill(_midnight), _edge());

    // Left ear inner — Electric Violet
    _poly(canvas, _s(const [
      Offset(72, 44), Offset(60, 22), Offset(82, 43),
    ]), _fill(_electric, 0.68), _edge(0.18));

    // Right ear outer — Deep Violet
    _poly(canvas, _s(const [
      Offset(108, 40), Offset(127, 10), Offset(118, 44),
    ]), _fill(_violet), _edge(0.28));

    // Right ear inner — Electric Violet
    _poly(canvas, _s(const [
      Offset(110, 41), Offset(124, 15), Offset(116, 44),
    ]), _fill(_electric, 0.68), _edge(0.18));
  }

  // ── Face ──────────────────────────────────────────────────────────────────

  void _drawFace(Canvas canvas) {
    final d = floatDy;

    // Left eye — geometric almond, Electric Violet iris
    final eyePath = Path()
      ..moveTo(72, 62 + d)
      ..lineTo(79, 57 + d)
      ..lineTo(88, 60 + d)
      ..lineTo(82, 67 + d)
      ..close();
    canvas.drawPath(eyePath, _fill(_electric));
    canvas.drawCircle(Offset(81, 62 + d), 3.2, _fill(_ink));
    canvas.drawCircle(Offset(82.5, 60.5 + d), 1.0,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.88)
          ..style = PaintingStyle.fill);

    // Nose — small inverted triangle in Electric Violet
    final nose = Path()
      ..moveTo(84, 77 + d)
      ..lineTo(92, 77 + d)
      ..lineTo(88, 81 + d)
      ..close();
    canvas.drawPath(nose, _fill(_electric));
  }

  // ── Paws ──────────────────────────────────────────────────────────────────

  void _drawPaws(Canvas canvas) {
    // Left paw — Midnight Grape
    _poly(canvas, _s(const [
      Offset(48, 170), Offset(46, 195), Offset(72, 195),
      Offset(74, 176), Offset(58, 173),
    ]), _fill(_midnight), _edge());

    // Right paw — Midnight Grape
    _poly(canvas, _s(const [
      Offset(80, 172), Offset(78, 195), Offset(104, 195), Offset(106, 175),
    ]), _fill(_midnight), _edge());

    // Toe lines — subtle Electric Violet
    for (final x in [55.0, 61.0, 67.0]) {
      canvas.drawLine(Offset(x, 178 + floatDy), Offset(x, 192 + floatDy), _edge(0.20));
    }
    for (final x in [86.0, 92.0, 98.0]) {
      canvas.drawLine(Offset(x, 177 + floatDy), Offset(x, 191 + floatDy), _edge(0.20));
    }
  }

  // ── Ambient sparkles ──────────────────────────────────────────────────────

  void _drawSparkles(Canvas canvas) {
    const pts = [
      Offset(30,  55),
      Offset(170, 38),
      Offset(172, 148),
      Offset(26,  150),
      Offset(42,  200),
      Offset(160, 200),
    ];
    for (int i = 0; i < pts.length; i++) {
      final phase = (glowPhase + i / pts.length) % 1.0;
      final a = (sin(phase * 2 * pi) * 0.5 + 0.5) * 0.45;
      final r = (2.0 + sin(phase * 2 * pi + i) * 0.8).clamp(1.0, 4.0);
      canvas.drawCircle(
        Offset(pts[i].dx, pts[i].dy + floatDy),
        r,
        Paint()
          ..color = _electric.withValues(alpha: a)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_FoxPainter old) =>
      old.floatDy != floatDy || old.glowPhase != glowPhase;
}
