import 'package:flutter/material.dart';
import '../models/wine_recommendation.dart';

// ---------------------------------------------------------------------------
// Palate conflict alert (attribute-level mismatch)
// ---------------------------------------------------------------------------

Future<void> showWizardConflictAlert(
  BuildContext context,
  ConflictAlert alert,
  void Function(int) onAdjust,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          alert.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧙‍♂️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 15),
            Text(
              alert.message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("No, I'm Stubborn"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[800]),
            onPressed: () {
              onAdjust(alert.suggestedValue);
              Navigator.of(context).pop();
            },
            child: const Text(
              'Trust the Wizard',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Gastro-clash alert (food + palate mismatch) — bottom sheet
// ---------------------------------------------------------------------------

Future<void> showGastroClashAlert(
  BuildContext context,
  GastroClash clash,
  void Function(Map<String, int>) onApply,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.indigo[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              clash.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              clash.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      "I'll risk it!",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700],
                    ),
                    onPressed: () {
                      onApply(clash.newValues);
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Trust the Wizard',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
