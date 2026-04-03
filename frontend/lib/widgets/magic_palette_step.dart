/// magic_palette_step.dart
///
/// Magical card-based palate selector. Shows a large animated hero card for
/// the selected level, 5 tap-to-select thumbnail cards below, a wand-swirl
/// sparkle overlay on selection, and a Web Audio arpeggio chime.
library;

import 'dart:math' as math;

import 'package:wine_wizard/stubs/chime_stub.dart'
    if (dart.library.html) 'package:wine_wizard/stubs/chime_web.dart';

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Cartoon data for each attribute
// ---------------------------------------------------------------------------

class _Card {
  final String emoji;
  final String label;
  final String flavour;

  const _Card(this.emoji, this.label, this.flavour);
}

const _crispness = [
  _Card('🧈', 'Dead Flat', 'Buttery and round. Zero freshness, all richness'),
  _Card('🍐', 'Mellow Fresh', 'Soft pear-drop gentleness on the tongue'),
  _Card('🥂', 'Citrus Bright', 'Balanced and celebratory. The sweet spot'),
  _Card('🍋', 'Electric Zing!', 'Lemon-sharp and mouth-watering. It crackles!'),
  _Card('🍋‍🟩', 'Lightning Bolt!', 'Razor-sharp lime. Eye-wateringly crisp'),
];

const _weight = [
  _Card('🕯️', 'Feather Light', 'Delicate as a taper flame. Barely there on the palate'),
  _Card('☁️', 'Cloud Soft', 'Graceful and floaty. Easy-drinking and gentle'),
  _Card('🌊', 'Flowing Wave', 'Balanced and present. The classic medium-bodied sweet spot'),
  _Card('🧥', 'Full & Huggable', 'Rich and substantial. Warming and deeply satisfying'),
  _Card('💪', 'Mighty Boulder!', 'A true heavyweight. Big, bold and built to last'),
];

const _texture = [
  _Card('🥚', 'Pure Silk', 'Egg-white smooth. The winemaker\'s trick for ultra-soft tannins'),
  _Card('🍦', 'Velvet Hug', 'Creamy and gentle. Like soft-serve on the palate'),
  _Card('🍫', 'Light Grip', 'Dark chocolate. Pleasant, present, easy to enjoy'),
  _Card('🌰', 'Firm Grip', 'Chestnut dry. Noticeably grippy and chewy'),
  _Card('🫖', 'Desert Dry!', 'Over-steeped tea. The sommelier\'s descriptor for maximum tannin'),
];

const _flavor = [
  _Card('💧', 'Whisper Quiet', 'Barely there. A neutral, almost water-like presence'),
  _Card('🌿', 'Gently Speaks', 'Subtle herb and mineral. Quietly charming'),
  _Card('🌹', 'In Full Bloom', 'Expressive and aromatic. Beautiful and complex'),
  _Card('🍒', 'Star Power!', 'Vibrant and fruity. Bold, exciting, the spotlight is yours'),
  _Card('🌶️', 'Flavour Bomb!', 'Intense and powerful. Spice, concentration, off the charts'),
];

List<_Card> _cardsFor(String title) {
  if (title.contains('Crisp') || title.contains('Acidity')) return _crispness;
  if (title.contains('Weight') || title.contains('Body')) return _weight;
  if (title.contains('Texture') || title.contains('Tannin')) return _texture;
  return _flavor;
}

// ---------------------------------------------------------------------------
// Wand-swirl sparkle colours (used by the overlay painter)
// ---------------------------------------------------------------------------

const _sparkleEmojis = ['✨', '⭐', '💫', '🌟', '✨', '💫', '⭐', '🌟'];

// Fixed angles for particles so they fan out evenly
final _particleAngles = List.generate(8, (i) => i * (2 * math.pi / 8) + 0.3);

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

class MagicPaletteStep extends StatefulWidget {
  final String title;
  final String description;
  final int value; // 1–5
  final ValueChanged<int> onChanged;

  const MagicPaletteStep({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  State<MagicPaletteStep> createState() => _MagicPaletteStepState();
}

class _MagicPaletteStepState extends State<MagicPaletteStep>
    with TickerProviderStateMixin {
  // Hero card bounce
  late final AnimationController _heroCtrl;
  late final Animation<double> _heroScale;

  // Wand swirl
  late final AnimationController _wandCtrl;
  late final Animation<double> _wandAngle;
  late final Animation<double> _particleDist;
  late final Animation<double> _overlayFade;

  @override
  void initState() {
    super.initState();

    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _heroScale = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.elasticOut));

    _wandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Wand completes 2 full orbits
    _wandAngle = Tween<double>(
      begin: 0.0,
      end: 4 * math.pi,
    ).animate(CurvedAnimation(parent: _wandCtrl, curve: Curves.easeInOut));

    // Particles travel outward then the fade kills them
    _particleDist = CurvedAnimation(
      parent: _wandCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    // Whole overlay: quick fade-in, hold, slow fade-out
    _overlayFade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 37),
    ]).animate(_wandCtrl);
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _wandCtrl.dispose();
    super.dispose();
  }

  // ── interaction ──────────────────────────────────────────────────────────

  void _select(int v) {
    widget.onChanged(v);
    _heroCtrl.forward(from: 0);
    _wandCtrl.forward(from: 0);
    _playChime();
  }

  void _playChime() {
    try {
      playMagicChime();
    } catch (_) {
      // Web Audio not available — fail silently
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cards = _cardsFor(widget.title);
    final selected = cards[widget.value - 1];
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          widget.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(widget.description, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 32),

        // ── Hero card ────────────────────────────────────────────────────
        Center(
          child: ScaleTransition(
            scale: _heroScale,
            child: SizedBox(
              width: 240,
              height: 210,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Card background
                  Container(
                    width: 240,
                    height: 210,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [cs.primaryContainer, cs.secondaryContainer],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.35),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Big cartoon emoji — swaps on value change
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Text(
                            selected.emoji,
                            key: ValueKey(widget.value),
                            style: const TextStyle(fontSize: 72),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Label
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            selected.label,
                            key: ValueKey(widget.value),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Flavour text
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              selected.flavour,
                              key: ValueKey(widget.value),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: cs.onPrimaryContainer.withValues(
                                  alpha: 0.70,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Wand swirl overlay ──────────────────────────────────
                  AnimatedBuilder(
                    animation: _wandCtrl,
                    builder: (context, _) {
                      if (_overlayFade.value < 0.01) {
                        return const SizedBox.shrink();
                      }
                      return Opacity(
                        opacity: _overlayFade.value,
                        child: SizedBox(
                          width: 240,
                          height: 210,
                          child: Stack(
                            children: [
                              // Orbiting wand
                              Positioned(
                                left:
                                    120 + math.cos(_wandAngle.value) * 88 - 14,
                                top: 105 + math.sin(_wandAngle.value) * 72 - 14,
                                child: const Text(
                                  '🪄',
                                  style: TextStyle(fontSize: 28),
                                ),
                              ),

                              // Sparkle particles
                              for (var i = 0; i < 8; i++)
                                Positioned(
                                  left:
                                      120 +
                                      math.cos(_particleAngles[i]) *
                                          (_particleDist.value * 100) -
                                      10,
                                  top:
                                      105 +
                                      math.sin(_particleAngles[i]) *
                                          (_particleDist.value * 80) -
                                      10,
                                  child: Opacity(
                                    opacity: (1.0 - _particleDist.value).clamp(
                                      0.0,
                                      1.0,
                                    ),
                                    child: Text(
                                      _sparkleEmojis[i],
                                      style: TextStyle(
                                        fontSize:
                                            10 +
                                            (1.0 - _particleDist.value) * 10,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // ── 5 thumbnail selector tiles ───────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (i) {
            final v = i + 1;
            final card = cards[i];
            final sel = widget.value == v;

            return GestureDetector(
              onTap: () => _select(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: sel ? 64 : 54,
                height: sel ? 84 : 72,
                decoration: BoxDecoration(
                  color: sel ? cs.primary : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.55),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(card.emoji, style: TextStyle(fontSize: sel ? 28 : 22)),
                    const SizedBox(height: 3),
                    Text(
                      '$v',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: sel ? Colors.white : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
