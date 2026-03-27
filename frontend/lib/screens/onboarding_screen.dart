import 'dart:math' show cos, sin, pi;

import 'package:flutter/material.dart';
import '../widgets/palate_dial.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  void _next() {
    if (_currentPage < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  @override
  void initState() {
    super.initState();
    // Backup listener — ensures _currentPage always reflects the real page
    // even if onPageChanged fires late due to frame jank.
    _controller.addListener(() {
      final p = _controller.page?.round() ?? 0;
      if (p != _currentPage) setState(() => _currentPage = p);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Match the dark-purple card backgrounds so the button row blends in.
      backgroundColor: const Color(0xFF1A0030),
      body: Column(
        children: [
          // Pages fill all available vertical space above the button row.
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: 3,
              onPageChanged: (p) => setState(() => _currentPage = p),
              itemBuilder: (context, index) => switch (index) {
                0 => const _CardIntroduction(),
                1 => const _CardPalatePromise(),
                _ => const _CardLocalLegend(),
              },
            ),
          ),

          // Button row lives OUTSIDE the PageView — no Positioned/SafeArea
          // ambiguity with Android 16 edge-to-edge insets.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 12, 32, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.amber.shade400
                              : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 20),

                  // CTA button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber.shade600,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _next,
                      child: Text(
                        _currentPage == 2 ? "Let's Get Started!" : 'Next',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card 1 — The Introduction  (smoke-materialisation entrance)
// ---------------------------------------------------------------------------

class _PuffConfig {
  final double angleDeg;
  final double maxDist;
  final double maxRadius;
  final double delay;   // stagger: 0.0–0.15
  final Color  color;
  const _PuffConfig(this.angleDeg, this.maxDist, this.maxRadius, this.delay, this.color);
}

const _puffs = [
  _PuffConfig(  0, 62, 30, 0.00, Color(0xFF8B44BE)),
  _PuffConfig( 45, 56, 23, 0.06, Color(0xFFAA6FD0)),
  _PuffConfig( 90, 60, 27, 0.03, Color(0xFF7230A0)),
  _PuffConfig(135, 54, 21, 0.09, Color(0xFF9955C0)),
  _PuffConfig(180, 58, 26, 0.02, Color(0xFF6A2090)),
  _PuffConfig(225, 52, 22, 0.07, Color(0xFFBB88E0)),
  _PuffConfig(270, 60, 28, 0.00, Color(0xFF7B35B0)),
  _PuffConfig(315, 50, 20, 0.05, Color(0xFF9940BB)),
];

class _SmokePuffs extends StatelessWidget {
  final double progress; // 0 → 1

  const _SmokePuffs({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: _puffs.map((cfg) {
        final p = cfg.delay >= 1.0
            ? 0.0
            : ((progress - cfg.delay) / (1.0 - cfg.delay)).clamp(0.0, 1.0);
        if (p <= 0) return const SizedBox.shrink();

        // Opacity: rises to peak at 40%, fades to zero by 100%
        final opacity = (p < 0.40
            ? p / 0.40
            : (1.0 - p) / 0.60).clamp(0.0, 0.85);

        final rad    = cfg.angleDeg * pi / 180.0;
        final dist   = cfg.maxDist * p;
        final radius = cfg.maxRadius * (0.35 + p * 0.65);

        return Transform.translate(
          offset: Offset(cos(rad) * dist, sin(rad) * dist),
          child: Opacity(
            opacity: opacity,
            child: Container(
              width:  radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    cfg.color.withValues(alpha: 0.95),
                    cfg.color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CardIntroduction extends StatefulWidget {
  const _CardIntroduction();

  @override
  State<_CardIntroduction> createState() => _CardIntroductionState();
}

class _CardIntroductionState extends State<_CardIntroduction>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _floatCtrl;

  // Entrance animations
  late final Animation<double> _smokeProgress;
  late final Animation<double> _wizardScale;
  late final Animation<double> _wizardOpacity;

  // Post-entrance float
  late final Animation<double> _floatScale;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Smoke expands across the full entrance
    _smokeProgress = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOut,
    );

    // Wizard pops in with an elastic bounce — starts at 15% of entrance
    _wizardScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.15, 0.88, curve: Curves.elasticOut),
      ),
    );

    // Wizard fades in over the first half of the entrance
    _wizardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.15, 0.55, curve: Curves.easeIn),
      ),
    );

    // Gentle float once materialised
    _floatScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // Play entrance once, then start the infinite float
    _entranceCtrl.forward().whenComplete(() {
      if (mounted) _floatCtrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0030), Color(0xFF3D0066)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Wizard materialisation ──────────────────────────────────
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Smoke puffs layer
                    AnimatedBuilder(
                      animation: _smokeProgress,
                      builder: (_, __) => _SmokePuffs(
                        progress: _smokeProgress.value,
                      ),
                    ),

                    // Wizard emoji layer
                    AnimatedBuilder(
                      animation: Listenable.merge([_entranceCtrl, _floatCtrl]),
                      builder: (_, __) {
                        final scale = _entranceCtrl.isCompleted
                            ? _floatScale.value
                            : _wizardScale.value;
                        return Opacity(
                          opacity: _wizardOpacity.value.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.shade400
                                        .withValues(alpha: 0.3),
                                    blurRadius: 32,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text('🧙‍♂️',
                                    style: TextStyle(fontSize: 72)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              Text(
                'Welcome to the Inner Circle.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade200,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                "I'm the Wine Wizard, and I'm here to make sure you never drink a boring bottle again.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card 2 — The Palate Promise
// ---------------------------------------------------------------------------

class _CardPalatePromise extends StatelessWidget {
  const _CardPalatePromise();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B003A), Color(0xFF2E004F)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Live Palate Dial preview at neutral settings
              SizedBox(
                width: 220,
                height: 220,
                child: PalateDial(
                  crispness: 3,
                  weight: 3,
                  flavorIntensity: 4,
                  texture: 2,
                ),
              ),

              const SizedBox(height: 36),

              Text(
                "I'll help you speak 'Wine' like a pro.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade200,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 16),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.6,
                  ),
                  children: const [
                    TextSpan(text: 'Whether you like it '),
                    TextSpan(
                      text: 'Zingy (High Acidity)',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.amberAccent,
                      ),
                    ),
                    TextSpan(text: ' or '),
                    TextSpan(
                      text: 'Grippy (High Tannin)',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.amberAccent,
                      ),
                    ),
                    TextSpan(text: ", we'll find your perfect match."),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card 3 — The Local Legend
// ---------------------------------------------------------------------------

class _CardLocalLegend extends StatefulWidget {
  const _CardLocalLegend();

  @override
  State<_CardLocalLegend> createState() => _CardLocalLegendState();
}

class _CardLocalLegendState extends State<_CardLocalLegend>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.2, end: 0.7).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1A0030), Color(0xFF3D0066)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glowing map pin
              AnimatedBuilder(
                animation: _glow,
                builder: (context, child) => Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent
                            .withValues(alpha: _glow.value),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: const Center(
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 80,
                    color: Colors.greenAccent,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Text(
                'Best of all?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade200,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                "I'll show you exactly which shop down the street is holding your bottle.\n\nReady to begin your quest?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
