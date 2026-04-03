import 'dart:math';
import 'package:flutter/material.dart';

/// A magical wand circles twice leaving a stardust trail, then vanishes in a
/// puff of smoke as a wine bottle appears.
///
/// Timeline (5 s total):
///   t 0.00–0.48  circle 1 — no glow
///   t 0.48–0.90  circle 2 — wand tip glow builds
///   t 0.90–0.96  flash spike
///   t 0.96       wand disappears; smoke + bottle burst instantly
///   t 0.96–1.00  smoke fades, bottle settles
///   Idle loop    bottle floats, sparkles pulse
class WizardHeroWidget extends StatefulWidget {
  final Duration delay;
  const WizardHeroWidget({super.key, this.delay = Duration.zero});

  @override
  State<WizardHeroWidget> createState() => _WizardHeroWidgetState();
}

class _WizardHeroWidgetState extends State<WizardHeroWidget>
    with TickerProviderStateMixin {
  late final AnimationController _seq;
  late final AnimationController _idle;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _seq  = AnimationController(vsync: this, duration: const Duration(milliseconds: 5000));
    _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
    _seq.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _done = true);
        _idle.repeat();
      }
    });
    Future.delayed(widget.delay, () { if (mounted) _seq.forward(); });
  }

  @override
  void dispose() { _seq.dispose(); _idle.dispose(); super.dispose(); }

  static double _c01(double v) => v.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_seq, _idle]),
      builder: (_, _) {
        final t    = _seq.value;
        final idleT = _idle.value;

        // Wand spins on its own centre axis — like the Earth on its axial tilt.
        // Resting tilt: 15° left of vertical = -π/2 - π/12.
        // Two full clockwise rotations from that base, then disappears.
        const baseTilt = -pi / 2 - pi / 12;
        double wandAngle = baseTilt;
        double wandOpacity = 0;
        if (!_done) {
          if (t < 0.96) {
            wandOpacity = 1.0;
            wandAngle = t < 0.48
                ? baseTilt + (t / 0.48) * 2 * pi             // spin 1
                : baseTilt + 2 * pi + ((t - 0.48) / 0.48) * 2 * pi; // spin 2
          } else {
            // Wand fades out rapidly at t=0.96
            wandOpacity = _c01(1.0 - (t - 0.96) / 0.02);
            wandAngle = baseTilt + 4 * pi;
          }
        }

        // Glow: builds during circle 2, spikes at flash
        double glow = 0;
        if (!_done && t >= 0.48 && t < 0.96) {
          glow = t < 0.90
              ? _c01((t - 0.48) / 0.42)           // 0 → 1 over circle 2
              : 1.0 + _c01((t - 0.90) / 0.06) * 2.5; // 1 → 3.5 spike
        }

        // White flash (t 0.91–0.96)
        final flash = (!_done && t > 0.91 && t < 0.96)
            ? _c01((t - 0.91) / 0.05) * 0.80
            : 0.0;

        // Bottle & smoke at t=0.96
        final bottleOpacity = _done ? 1.0 : _c01((t - 0.96) / 0.04);
        final smokeOpacity  = _done ? 0.0
            : (t < 0.96 ? 0.0 : _c01(1.0 - (t - 0.96) / 0.06));

        // Idle float offset for bottle
        final floatDy = _done ? sin(idleT * 2 * pi) * 6.0 : 0.0;

        // Idle sparkle pulse
        final sparkPulse = _done ? sin(idleT * 2 * pi) * 0.5 + 0.5 : 0.0;

        return SizedBox(
          width: 200,
          height: 220,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: const Size(200, 220),
                painter: _ScenePainter(
                  wandAngle: wandAngle,
                  wandOpacity: wandOpacity,
                  glowIntensity: glow,
                  smokeOpacity: smokeOpacity,
                  bottleOpacity: bottleOpacity,
                  floatDy: floatDy,
                  sparkPulse: sparkPulse,
                ),
              ),
              if (flash > 0)
                Positioned.fill(
                  child: Opacity(
                    opacity: flash,
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _ScenePainter extends CustomPainter {
  final double wandAngle;
  final double wandOpacity;
  final double glowIntensity;
  final double smokeOpacity;
  final double bottleOpacity;
  final double floatDy;
  final double sparkPulse;

  const _ScenePainter({
    required this.wandAngle,
    required this.wandOpacity,
    required this.glowIntensity,
    required this.smokeOpacity,
    required this.bottleOpacity,
    required this.floatDy,
    required this.sparkPulse,
  });

  // Wand spins on its own centre axis — fixed position on canvas.
  static const _wandCentre = Offset(100, 95);
  static const _halfLen    = 46.0; // half the wand length each side
  static const _gold       = Color(0xFFFFD700);
  static const _wand       = Color(0xFF5C2A06);

  @override
  void paint(Canvas canvas, Size size) {
    if (wandOpacity > 0) _drawWand(canvas);
    if (smokeOpacity > 0) _drawSmoke(canvas, size);
    if (bottleOpacity > 0) _drawBottle(canvas, size);
  }

  void _drawWand(Canvas canvas) {
    // Wand spins on its own centre — tip and butt extend from _wandCentre.
    final tip = Offset(
      _wandCentre.dx + _halfLen * cos(wandAngle),
      _wandCentre.dy + _halfLen * sin(wandAngle),
    );
    final butt = Offset(
      _wandCentre.dx - _halfLen * cos(wandAngle),
      _wandCentre.dy - _halfLen * sin(wandAngle),
    );

    // Glow halo at tip
    if (glowIntensity > 0) {
      final gr = (10.0 + glowIntensity * 34).clamp(0.0, 90.0);
      final ga = (glowIntensity * 0.72).clamp(0.0, 1.0);
      canvas.drawCircle(
        tip, gr,
        Paint()..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: ga),
            _gold.withValues(alpha: ga * 0.55),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: tip, radius: gr)),
      );
    }

    // Stardust trail — 14 fading dots swept from the tip's recent positions
    for (int i = 14; i >= 1; i--) {
      final a = wandAngle - i * 0.11;
      final tp = Offset(
        _wandCentre.dx + _halfLen * cos(a),
        _wandCentre.dy + _halfLen * sin(a),
      );
      final fade = 1.0 - i / 15.0;
      final alpha = (fade * (0.35 + glowIntensity * 0.60)).clamp(0.0, 1.0);
      // Alternate gold and white dust particles
      final dustColor = i.isEven
          ? _gold.withValues(alpha: alpha)
          : Colors.white.withValues(alpha: alpha * 0.80);
      canvas.drawCircle(tp, (3.8 * fade).clamp(0.5, 4.0), Paint()..color = dustColor);
    }

    // Extra sparkle stars scattered in the trail
    for (int i = 4; i >= 1; i--) {
      final a = wandAngle - i * 0.32;
      final tp = Offset(
        _wandCentre.dx + _halfLen * cos(a),
        _wandCentre.dy + _halfLen * sin(a),
      );
      final fade = 1.0 - i / 5.0;
      final alpha = (fade * (0.40 + glowIntensity * 0.55)).clamp(0.0, 1.0);
      _drawStar(canvas, tp, 3.5 * fade, _gold.withValues(alpha: alpha));
    }

    // Wand stick
    canvas.drawLine(
      butt, tip,
      Paint()
        ..color = _wand.withValues(alpha: wandOpacity)
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Wand handle knob
    canvas.drawCircle(butt, 5, Paint()..color = const Color(0xFF7A3B0E).withValues(alpha: wandOpacity));

    // Glowing star at tip
    final starSz = (8.0 + glowIntensity * 7.0).clamp(0.0, 22.0);
    _drawStar(canvas, tip, starSz, _gold.withValues(alpha: wandOpacity));

    // Inner bright white core of star when glowing
    if (glowIntensity > 0.30) {
      _drawStar(canvas, tip, starSz * 0.45,
          Colors.white.withValues(alpha: (glowIntensity * wandOpacity).clamp(0.0, 1.0)));
    }

    // 4-point sparkle burst when glowing strongly
    if (glowIntensity > 0.20) {
      _drawSparkle(canvas, tip, starSz * 2.8,
          Colors.white.withValues(alpha: (glowIntensity * 0.90 * wandOpacity).clamp(0.0, 1.0)));
    }
  }

  void _drawSmoke(Canvas canvas, Size size) {
    // Smoke radiates outward from the bottle centre
    final centre = Offset(size.width * 0.50, size.height * 0.38 + floatDy);
    final puffs = [
      (Offset(centre.dx,      centre.dy - 10), 30.0),
      (Offset(centre.dx - 22, centre.dy - 20), 24.0),
      (Offset(centre.dx + 24, centre.dy - 18), 22.0),
      (Offset(centre.dx - 14, centre.dy - 38), 19.0),
      (Offset(centre.dx + 16, centre.dy - 42), 17.0),
      (Offset(centre.dx,      centre.dy - 54), 14.0),
      (Offset(centre.dx - 8,  centre.dy - 66), 10.0),
    ];
    final a = smokeOpacity;
    for (final (pos, r) in puffs) {
      // Outer puff: soft purple
      canvas.drawCircle(pos, r * (0.5 + a * 0.5),
          Paint()..color = Color.fromRGBO(178, 128, 228, a * 0.65));
      // Inner bright core
      canvas.drawCircle(pos, r * 0.38 * a,
          Paint()..color = Color.fromRGBO(220, 180, 255, a * 0.80));
    }
    // Gold sparkles bursting out of the smoke
    if (a > 0.40) {
      final sparks = [
        Offset(centre.dx - 30, centre.dy - 28),
        Offset(centre.dx + 32, centre.dy - 24),
        Offset(centre.dx - 12, centre.dy - 58),
        Offset(centre.dx + 18, centre.dy - 52),
      ];
      for (final sp in sparks) {
        _drawStar(canvas, sp, 5.0 * a, _gold.withValues(alpha: a));
      }
    }
  }

  void _drawBottle(Canvas canvas, Size size) {
    final a = bottleOpacity.clamp(0.0, 1.0);
    final cx = size.width * 0.50;
    final cy = size.height * 0.48 + floatDy;

    // Idle sparkle stars floating around bottle
    if (sparkPulse > 0) {
      final sparkA = (sparkPulse * 0.85 * a).clamp(0.0, 1.0);
      final sparks = [
        Offset(cx - 34, cy - 30),
        Offset(cx + 36, cy - 22),
        Offset(cx - 28, cy + 10),
        Offset(cx + 30, cy + 14),
      ];
      for (int i = 0; i < sparks.length; i++) {
        final sz = 4.0 + sin(sparkPulse * 2 * pi + i) * 1.5;
        _drawStar(canvas, sparks[i], sz.abs(), _gold.withValues(alpha: sparkA));
      }
    }

    // Bottle body
    final bodyRect = Rect.fromCenter(
        center: Offset(cx, cy), width: 24, height: 56);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(6)),
      Paint()..color = Color.fromRGBO(16, 88, 16, a),
    );

    // Shoulder taper
    final shoulder = Path()
      ..moveTo(cx - 12, cy - 28)
      ..lineTo(cx - 6,  cy - 40)
      ..lineTo(cx + 6,  cy - 40)
      ..lineTo(cx + 12, cy - 28)
      ..close();
    canvas.drawPath(shoulder, Paint()..color = Color.fromRGBO(16, 88, 16, a));

    // Neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 48), width: 12, height: 18),
        const Radius.circular(3)),
      Paint()..color = Color.fromRGBO(16, 88, 16, a),
    );

    // Cork
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 58), width: 10, height: 10),
        const Radius.circular(3)),
      Paint()..color = Color.fromRGBO(136, 96, 52, a),
    );

    // Label
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 4), width: 17, height: 24),
        const Radius.circular(3)),
      Paint()..color = Color.fromRGBO(238, 215, 148, a * 0.95),
    );

    // Label text line hints
    for (final dy in [-5.0, 0.0, 5.0]) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, cy + 4 + dy), width: 11, height: 1.5),
        Paint()..color = Color.fromRGBO(160, 130, 60, a * 0.70),
      );
    }

    // Bottle shine
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 10, cy - 26, 4, 30),
        const Radius.circular(2)),
      Paint()..color = Color.fromRGBO(255, 255, 255, a * 0.18),
    );
  }

  void _drawStar(Canvas canvas, Offset c, double size, Color color) {
    if (size <= 0) return;
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final oa = i * 2 * pi / 5 - pi / 2;
      final ia = oa + pi / 5;
      final op = Offset(c.dx + size * cos(oa), c.dy + size * sin(oa));
      final ip = Offset(c.dx + size * 0.40 * cos(ia), c.dy + size * 0.40 * sin(ia));
      if (i == 0) { path.moveTo(op.dx, op.dy); } else { path.lineTo(op.dx, op.dy); }
      path.lineTo(ip.dx, ip.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawSparkle(Canvas canvas, Offset c, double size, Color color) {
    if (size <= 0) return;
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(c.dx, c.dy - size), Offset(c.dx, c.dy + size), p);
    canvas.drawLine(Offset(c.dx - size, c.dy), Offset(c.dx + size, c.dy), p);
    final d = size * 0.65;
    p.color = color.withValues(alpha: color.a * 0.55);
    canvas.drawLine(Offset(c.dx - d, c.dy - d), Offset(c.dx + d, c.dy + d), p);
    canvas.drawLine(Offset(c.dx + d, c.dy - d), Offset(c.dx - d, c.dy + d), p);
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.wandAngle != wandAngle ||
      old.wandOpacity != wandOpacity ||
      old.glowIntensity != glowIntensity ||
      old.smokeOpacity != smokeOpacity ||
      old.bottleOpacity != bottleOpacity ||
      old.floatDy != floatDy ||
      old.sparkPulse != sparkPulse;
}
