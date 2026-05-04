import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's palate quiz answers between app sessions.
class PalatePrefs {
  static const _kCrispness   = 'palate_crispness';
  static const _kWeight      = 'palate_weight';
  static const _kTexture     = 'palate_texture';
  static const _kFlavor      = 'palate_flavor';
  static const _kFoodPairing = 'palate_food_pairing';
  static const _kBudgetIndex = 'palate_budget_index';
  static const _kPrefDry     = 'palate_pref_dry';

  static Future<PalateSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_kCrispness)) return null;
    return PalateSnapshot(
      crispness:   prefs.getInt(_kCrispness)    ?? 3,
      weight:      prefs.getInt(_kWeight)        ?? 3,
      texture:     prefs.getInt(_kTexture)       ?? 3,
      flavor:      prefs.getInt(_kFlavor)        ?? 3,
      foodPairing: prefs.getString(_kFoodPairing) ?? 'none',
      budgetIndex: prefs.getInt(_kBudgetIndex)   ?? 1,
      prefDry:     prefs.getBool(_kPrefDry)      ?? false,
    );
  }

  static Future<void> save({
    required int crispness,
    required int weight,
    required int texture,
    required int flavor,
    required String foodPairing,
    required int budgetIndex,
    required bool prefDry,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCrispness, crispness);
    await prefs.setInt(_kWeight, weight);
    await prefs.setInt(_kTexture, texture);
    await prefs.setInt(_kFlavor, flavor);
    await prefs.setString(_kFoodPairing, foodPairing);
    await prefs.setInt(_kBudgetIndex, budgetIndex);
    await prefs.setBool(_kPrefDry, prefDry);
  }
}

class PalateSnapshot {
  final int crispness;
  final int weight;
  final int texture;
  final int flavor;
  final String foodPairing;
  final int budgetIndex;
  final bool prefDry;

  const PalateSnapshot({
    required this.crispness,
    required this.weight,
    required this.texture,
    required this.flavor,
    required this.foodPairing,
    required this.budgetIndex,
    required this.prefDry,
  });
}
