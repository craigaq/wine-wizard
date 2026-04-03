import 'package:flutter/material.dart';

import '../models/wine_recommendation.dart';
import '../screens/nearby_screen.dart';
import '../services/api_service.dart';
import '../services/currency_service.dart';
import '../widgets/conflict_alert.dart';
import '../widgets/magic_palette_step.dart';
import '../widgets/palate_dial.dart';

class QuizScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const QuizScreen({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  // --- Quiz state ---
  int _crispness = 3;
  int _weight = 3;
  int _texture = 3;
  int _flavor = 3;
  String _foodPairing = 'none'; // stores the backend ID
  int _budgetIndex = 1; // index into CurrencyService.getBrackets()
  String _currencyCode = 'AUD'; // resolved from GPS in initState
  bool _prefDry = false;
  String _overrideMode = 'use_pairing_logic';

  // --- Results state ---
  List<WineRecommendation>? _results;
  bool _loading = false;
  String? _error;
  ConflictAlert? _conflictAlert;

  static const int _totalPages = 10;

  /// Each entry: label = UI text, id = backend key, emoji = grid icon,
  /// comment = Wizard's in-step commentary shown when the item is selected.
  static const List<Map<String, String>> _foodOptions = [
    {
      'label': 'Steak, Lamb, or Burgers',
      'id': 'red_meat',
      'emoji': '🥩',
      'comment':
          "Steak nights are the best! We'll hunt for a wine with enough 'grip' (Tannin) to handle all that richness.",
    },
    {
      'label': 'Chicken, Turkey, or Pork',
      'id': 'poultry',
      'emoji': '🍗',
      'comment':
          "Chicken or pork? A versatile choice! Let's find a wine that's supportive but still brings its own personality to the party.",
    },
    {
      'label': 'White Fish or Shellfish',
      'id': 'white_fish',
      'emoji': '🐟',
      'comment':
          "Delicate flavors! We'll keep things light and 'crisp' (Acidity) so the wine doesn't drown out the fish.",
    },
    {
      'label': 'Salmon or Tuna',
      'id': 'rich_fish',
      'emoji': '🍣',
      'comment':
          "Salmon has some weight to it! We need a wine with enough 'zing' (Acidity) to cut through the richness.",
    },
    {
      'label': 'Spicy Curry or Tacos',
      'id': 'spicy_food',
      'emoji': '🌶️',
      'comment':
          "Ooh, a spicy one! We'll look for something 'fruity' (Aromatics) to act like a fire extinguisher for your tongue.",
    },
    {
      'label': 'Tomato Pasta or Pizza',
      'id': 'tomato_sauce',
      'emoji': '🍕',
      'comment':
          "Zesty tomato sauce! We need a wine with enough 'punch' (Acidity) to keep up with that tangy energy.",
    },
    {
      'label': 'Creamy or Cheesy Pasta',
      'id': 'creamy_sauce',
      'emoji': '🧀',
      'comment':
          "Rich and buttery? We'll find a 'heavyweight' (Full-bodied) wine that feels just as luxurious as the sauce.",
    },
    {
      'label': 'Salads or Green Veggies',
      'id': 'greens',
      'emoji': '🥗',
      'comment':
          "Fresh and light! Let's pick a 'crisp' (Acidity) wine that tastes like a summer garden in a glass.",
    },
    {
      'label': 'Cheese & Charcuterie',
      'id': 'charcuterie',
      'emoji': '🍖',
      'comment':
          "The ultimate snack pack! We'll find a crowd-pleaser that can handle everything from creamy brie to salty salami.",
    },
    {
      'label': 'Just sipping (No food)',
      'id': 'none',
      'emoji': '🍷',
      'comment':
          "Just a glass and some good vibes? Perfection. Let's find a wine that's a star all on its own.",
    },
  ];

  static const List<String> _attrOrder = [
    'Crispness (Acidity)',
    'Weight (Body)',
    'Texture (Tannin)',
    'Flavor Intensity (Aromatics)',
  ];

  BudgetBracket get _selectedBracket =>
      CurrencyService.getBrackets(_currencyCode)[_budgetIndex];

  String get _foodLabel =>
      _foodOptions.firstWhere((f) => f['id'] == _foodPairing)['label'] ??
      _foodPairing;

  String? get _foodComment => _foodOptions.firstWhere(
    (f) => f['id'] == _foodPairing,
    orElse: () => {},
  )['comment'];

  Map<String, int> get _userPrefs => {
    'Crispness (Acidity)': _crispness,
    'Weight (Body)': _weight,
    'Texture (Tannin)': _texture,
    'Flavor Intensity (Aromatics)': _flavor,
  };

  bool get _hasConflict => _weight <= 2 && _texture >= 4;

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  Future<void> _goNext() async {
    // Food page (5) → check for gastro clash before advancing
    if (_currentPage == 5 && _foodPairing != 'none') {
      await _checkAndHandlePairingClash();
    }
    if (_currentPage == 8) {
      _fetchResults();
    }
    if (_currentPage < _totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Calls the lightweight GET /check-pairing endpoint and surfaces:
  ///   • Gastro-Clash alert  — food/palate attribute mismatch
  ///   • Palate Paradox sheet — dry preference vs sweet-pairing food
  Future<void> _checkAndHandlePairingClash() async {
    try {
      final result = await ApiService().checkPairing(
        foodType: _foodPairing,
        crispnessAcidity: _crispness,
        weightBody: _weight,
        textureTannin: _texture,
        flavorIntensity: _flavor,
        prefDry: _prefDry,
      );
      if (!mounted) return;
      if (result.gastroClash != null) {
        await showGastroClashAlert(
          context,
          result.gastroClash!,
          _applyGastroAdjustment,
        );
      }
      if (!mounted) return;
      if (result.palateParadox != null) {
        await showPalateParadoxSheet(
          context,
          result.palateParadox!,
          (action) => setState(() => _overrideMode = action),
        );
      }
    } catch (_) {
      // Non-critical — proceed without blocking navigation
    }
  }

  void _goBack() {
    if (_currentPage > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _startOver() {
    setState(() {
      _crispness = 3;
      _weight = 3;
      _texture = 3;
      _flavor = 3;
      _foodPairing = 'none';
      _budgetIndex = 1;
      _prefDry = false;
      _overrideMode = 'use_pairing_logic';
      _results = null;
      _loading = false;
      _error = null;
      _conflictAlert = null;
    });
    _controller.animateToPage(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _fetchResults() async {
    setState(() {
      _loading = true;
      _error = null;
      _results = null;
      _conflictAlert = null;
    });
    try {
      final result = await ApiService().recommend(
        crispnessAcidity: _crispness,
        weightBody: _weight,
        textureTannin: _texture,
        flavorIntensity: _flavor,
        foodPairing: _foodPairing,
        prefDry: _prefDry,
        overrideMode: _overrideMode,
      );
      setState(() {
        _results = result.recommendations;
        _conflictAlert = result.alert;
        _loading = false;
      });
      // Palate conflict alert (shown after results load)
      if (result.alert != null && mounted) {
        await showWizardConflictAlert(
          context,
          result.alert!,
          _applyConflictAdjustment,
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Updates palate dial state from a Gastro-Clash override.
  /// Does NOT fetch results — the search runs later when the quiz completes.
  void _applyGastroAdjustment(Map<String, int> newValues) {
    setState(() {
      for (final entry in newValues.entries) {
        switch (entry.key) {
          case 'texture_tannin':
            _texture = entry.value;
          case 'weight_body':
            _weight = entry.value;
          case 'crispness_acidity':
            _crispness = entry.value;
          case 'flavor_intensity':
            _flavor = entry.value;
        }
      }
    });
  }

  void _applyConflictAdjustment(int value) {
    setState(() {
      switch (_conflictAlert?.field) {
        case 'texture_tannin':
          _texture = value;
        case 'weight_body':
          _weight = value;
        case 'crispness_acidity':
          _crispness = value;
        case 'flavor_intensity':
          _flavor = value;
      }
    });
    _fetchResults();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    CurrencyService.detectCodeFromGps().then((code) {
      if (mounted) setState(() => _currencyCode = code);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wine Wizard'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentPage + 1) / _totalPages,
            backgroundColor: Colors.deepPurple.shade100,
          ),
        ),
      ),
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (p) => setState(() => _currentPage = p),
        children: [
          _buildWelcome(),
          _buildAttributeStep(
            title: 'Crispness (Acidity)',
            description:
                'How much do you enjoy a fresh, zesty bite in your wine?',
            value: _crispness,
            onChanged: (v) => setState(() => _crispness = v),
          ),
          _buildAttributeStep(
            title: 'Weight (Body)',
            description:
                'Do you prefer a light, delicate sip or a rich, full-bodied experience?',
            value: _weight,
            onChanged: (v) => setState(() => _weight = v),
          ),
          _buildAttributeStep(
            title: 'Texture (Tannin)',
            description:
                'How do you feel about that dry, grippy sensation common in red wines?',
            value: _texture,
            onChanged: (v) => setState(() => _texture = v),
          ),
          _buildAttributeStep(
            title: 'Flavor Intensity (Aromatics)',
            description:
                'Do you prefer subtle, understated flavors or bold, expressive ones?',
            value: _flavor,
            onChanged: (v) => setState(() => _flavor = v),
          ),
          _buildFoodPairingStep(),
          _buildBudgetStep(),
          _buildPalateDialStep(),
          _buildSummaryStep(),
          _buildResultsStep(),
        ],
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  // ---------------------------------------------------------------------------
  // Nav bar
  // ---------------------------------------------------------------------------

  Widget _buildNavBar() {
    final isFirst = _currentPage == 0;
    final isLast = _currentPage == _totalPages - 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!isFirst)
              OutlinedButton.icon(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              )
            else
              const SizedBox.shrink(),
            if (isLast)
              TextButton.icon(
                onPressed: _startOver,
                icon: const Icon(Icons.refresh),
                label: const Text('Start Over'),
              )
            else
              FilledButton.icon(
                onPressed: _goNext,
                label: Text(_currentPage == 8 ? 'Find My Wine!' : 'Next'),
                icon: const Icon(Icons.arrow_forward),
                iconAlignment: IconAlignment.end,
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 0 — Welcome
  // ---------------------------------------------------------------------------

  Widget _buildWelcome() {
    return _stepShell(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🍷', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 24),
          Text(
            'Welcome to Wine Wizard',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Answer 8 quick questions about your palate and we\'ll find wines that actually match how you think.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _goNext,
            label: const Text('Let\'s Begin'),
            icon: const Icon(Icons.wine_bar),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Steps 1–4 — Attribute selectors
  // ---------------------------------------------------------------------------

  Widget _buildAttributeStep({
    required String title,
    required String description,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return _stepShell(
      child: MagicPaletteStep(
        title: title,
        description: description,
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 5 — Food Pairing
  // ---------------------------------------------------------------------------

  Widget _buildFoodPairingStep() {
    // "Just sipping" sits below the dry toggle; remaining options fill the grid.
    final soloOption = _foodOptions.last;
    final gridOptions = _foodOptions.sublist(0, _foodOptions.length - 1);

    return _stepShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Food Pairing',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "What's on the table tonight? The Wizard will fine-tune your match.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          // Dry preference toggle — activates Palate Paradox detection
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              dense: true,
              secondary: const Text('🍷', style: TextStyle(fontSize: 20)),
              title: const Text('I prefer dry wines'),
              subtitle: const Text(
                'The Wizard will flag sweet-pairing conflicts',
              ),
              value: _prefDry,
              onChanged: (v) => setState(() {
                _prefDry = v;
                // Reset any previously chosen override when preference changes
                _overrideMode = 'use_pairing_logic';
              }),
            ),
          ),
          const SizedBox(height: 12),

          // "Just sipping" sits directly below the dry-wine toggle
          _FoodCard(
            option: soloOption,
            selected: _foodPairing == soloOption['id'],
            onTap: () => setState(() => _foodPairing = soloOption['id']!),
            fullWidth: true,
          ),

          const SizedBox(height: 20),

          // 2-column icon grid for food items
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: gridOptions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            itemBuilder: (context, i) => _FoodCard(
              option: gridOptions[i],
              selected: _foodPairing == gridOptions[i]['id'],
              onTap: () => setState(() => _foodPairing = gridOptions[i]['id']!),
            ),
          ),

          const SizedBox(height: 16),

          // Wizard commentary — fades in/out as the selection changes
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: _foodComment != null
                ? _WizardComment(
                    key: ValueKey(_foodPairing),
                    text: _foodComment!,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 6 — Budget
  // ---------------------------------------------------------------------------

  Widget _buildBudgetStep() {
    return _stepShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Budget (per bottle)',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'The Wizard respects all budgets. Even the modest ones.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Column(
            children: CurrencyService.getBrackets(_currencyCode)
                .asMap()
                .entries
                .map((entry) {
                  final index = entry.key;
                  final bracket = entry.value;
                  final label = bracket.label;
                  final selected = _budgetIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _budgetIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 16,
                            ),
                          ),
                          if (selected)
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  );
                })
                .toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 7 — Palate Dial
  // ---------------------------------------------------------------------------

  Widget _buildPalateDialStep() {
    return _stepShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Your Palate Dial',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Here\'s a snapshot of your palate. Looking good.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          PalateDial(
            crispness: _crispness,
            weight: _weight,
            flavorIntensity: _flavor,
            texture: _texture,
          ),
          if (_hasConflict) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: const Row(
                children: [
                  Text('🧙‍♂️'),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Hmm. Light Weight with High Texture — the Wizard has thoughts. Tap Next.',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 8 — Summary
  // ---------------------------------------------------------------------------

  Widget _buildSummaryStep() {
    final rows = [
      ('Crispness (Acidity)', _crispness),
      ('Weight (Body)', _weight),
      ('Texture (Tannin)', _texture),
      ('Flavor Intensity (Aromatics)', _flavor),
    ];
    return _stepShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Profile',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Looking good. Hit "Find My Wine!" when you\'re ready.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...rows.map(
                    (r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            r.$1,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          _ScoreDots(value: r.$2),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Food Pairing',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _foodLabel,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Budget (per bottle)',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _selectedBracket.label,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 9 — Results
  // ---------------------------------------------------------------------------

  Widget _buildResultsStep() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Consulting the cellar...'),
          ],
        ),
      );
    }
    if (_error != null) {
      return _stepShell(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😬', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Something went wrong:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _fetchResults,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
    if (_results == null) {
      return const Center(child: Text('No results yet.'));
    }
    return _stepShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Recommendations',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a card to see how each wine matches your palate.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ..._results!.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final wine = entry.value;
            return _WineResultCard(
              rank: rank,
              wine: wine,
              userPrefs: _userPrefs,
              attrOrder: _attrOrder,
              budgetMin: _selectedBracket.min,
              budgetMax: _selectedBracket.max,
              currencyCode: _currencyCode,
            );
          }),
        ],
      ),
    );
  }

  Widget _stepShell({required Widget child}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Expandable wine result card
// ---------------------------------------------------------------------------

class _WineResultCard extends StatefulWidget {
  final int rank;
  final WineRecommendation wine;
  final Map<String, int> userPrefs;
  final List<String> attrOrder;
  final double budgetMin;
  final double budgetMax;
  final String currencyCode;

  const _WineResultCard({
    required this.rank,
    required this.wine,
    required this.userPrefs,
    required this.attrOrder,
    required this.budgetMin,
    required this.budgetMax,
    this.currencyCode = 'AUD',
  });

  @override
  State<_WineResultCard> createState() => _WineResultCardState();
}

class _WineResultCardState extends State<_WineResultCard> {
  bool _expanded = false;

  Color _rankColor() {
    return switch (widget.rank) {
      1 => Colors.amber.shade300,
      2 => Colors.grey.shade400,
      3 => Colors.brown.shade300,
      _ => Colors.grey.shade200,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: widget.rank == 1
            ? BorderSide(color: color, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header row ---
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _rankColor(),
                    child: Text(
                      '${widget.rank}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.wine.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (widget.rank == 1)
                              const Text('🍷', style: TextStyle(fontSize: 18)),
                          ],
                        ),
                        Text(
                          'Match: ${(widget.wine.score * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),

              // --- Expanded: attribute comparison + Find Nearby ---
              if (_expanded) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                // Column headers
                Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    Text(
                      'You',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Wine',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...widget.attrOrder.map((attr) {
                  final userVal = widget.userPrefs[attr] ?? 3;
                  final wineVal = (widget.wine.wineProfile[attr] ?? 0)
                      .round()
                      .clamp(1, 5);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            attr,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _ScoreDots(value: userVal, color: Colors.grey.shade400),
                        const SizedBox(width: 8),
                        _ScoreDots(value: wineVal, color: color),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NearbyScreen(
                          wineName: widget.wine.name,
                          budgetMin: widget.budgetMin,
                          budgetMax: widget.budgetMax,
                          currencyCode: widget.currencyCode,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.place, size: 16),
                    label: const Text('Find Nearby'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wizard commentary bubble (food pairing step)
// ---------------------------------------------------------------------------

class _WizardComment extends StatelessWidget {
  final String text;
  const _WizardComment({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🧙‍♂️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.deepPurple.shade800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Food selection card
// ---------------------------------------------------------------------------

class _FoodCard extends StatelessWidget {
  final Map<String, String> option;
  final bool selected;
  final VoidCallback onTap;
  final bool fullWidth;

  const _FoodCard({
    required this.option,
    required this.selected,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final label = option['label']!;
    final emoji = option['emoji']!;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: fullWidth ? 20 : 12,
          vertical: 14,
        ),
        child: fullWidth
            // Full-width layout: emoji + label side by side
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              )
            // Grid cell layout: emoji on top, label below
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Score dot indicator
// ---------------------------------------------------------------------------

class _ScoreDots extends StatelessWidget {
  final int value;
  final Color? color;
  const _ScoreDots({required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final dotColor = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Container(
          margin: const EdgeInsets.only(left: 3),
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < value ? dotColor : Colors.grey.shade300,
          ),
        );
      }),
    );
  }
}
