import 'package:flutter/material.dart';

class AgeGateScreen extends StatelessWidget {
  final VoidCallback onConfirmed;
  const AgeGateScreen({super.key, required this.onConfirmed});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0030), Color(0xFF3D0066)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Crest / visual
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.amber.shade300,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.shade300.withValues(alpha: 0.25),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🍷', style: TextStyle(fontSize: 48)),
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  'Welcome to\nWine Wizard',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade200,
                    height: 1.25,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'The cellar is reserved for adults.\nPlease confirm your age before entering.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.5,
                  ),
                ),

                const Spacer(flex: 2),

                // Confirm CTA
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
                    onPressed: onConfirmed,
                    child: const Text('Yes, I\'m of Legal Drinking Age'),
                  ),
                ),

                const SizedBox(height: 14),

                // Decline — leads nowhere, as expected for a compliance gate
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _showUnderageDialog(context),
                    child: const Text('No, I\'m Under Age'),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Legal drinking age varies by country.\nDrink responsibly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.35),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUnderageDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Come Back Later'),
        content: const Text(
          'The Wine Wizard will be here when you\'re ready. '
          'Until then, stay curious! 🧙‍♂️',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
