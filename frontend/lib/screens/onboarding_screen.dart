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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (p) => setState(() => _currentPage = p),
            children: const [
              _CardIntroduction(),
              _CardPalatePromise(),
              _CardLocalLegend(),
            ],
          ),

          // Page dots + button anchored at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
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
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card 1 — The Introduction
// ---------------------------------------------------------------------------

class _CardIntroduction extends StatefulWidget {
  const _CardIntroduction();

  @override
  State<_CardIntroduction> createState() => _CardIntroductionState();
}

class _CardIntroductionState extends State<_CardIntroduction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.08).animate(
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0030), Color(0xFF3D0066)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 48, 32, 140),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated wizard
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.shade400.withValues(alpha: 0.3),
                        blurRadius: 32,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🧙‍♂️', style: TextStyle(fontSize: 72)),
                  ),
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
          padding: const EdgeInsets.fromLTRB(32, 48, 32, 140),
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
          padding: const EdgeInsets.fromLTRB(32, 48, 32, 140),
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
