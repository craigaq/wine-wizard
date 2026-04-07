/// app_theme.dart
///
/// Wine Wizard design system — "The Cellar" palette.
///
/// Single source of truth for all colors, text styles, and the MaterialApp
/// ThemeData factory. Import this file wherever colors or styles are needed.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// Color palette
// ---------------------------------------------------------------------------

abstract final class WwColors {
  // ── Backgrounds ─────────────────────────────────────────────────────────
  /// Main scaffold background — near-black with purple undertone, AMOLED-safe
  static const bgDeep     = Color(0xFF0C0810);
  /// Raised card / surface
  static const bgSurface  = Color(0xFF160F1E);
  /// Top-layer overlays, bottom sheets
  static const bgElevated = Color(0xFF1E1530);

  // ── Accent — Cognac Gold ─────────────────────────────────────────────────
  /// Primary CTA, price hero, active states
  static const gold       = Color(0xFFC4965A);
  /// Muted gold for secondary use (currency prefix, inactive)
  static const goldMuted  = Color(0xFF7A5A34);
  /// Very faint gold tint for selected-card overlays
  static const goldTint   = Color(0x14C4965A);  // gold @ 8%

  // ── Accent — Wine Rose ───────────────────────────────────────────────────
  /// Complementary accent — dusty wine-rose, used sparingly
  static const rose       = Color(0xFF7D3E5E);

  // ── Text ─────────────────────────────────────────────────────────────────
  /// Primary text — warm off-white (not stark white)
  static const textPrimary   = Color(0xFFF5EFE8);
  /// Secondary text — warm grey for metadata, subtext
  static const textSecondary = Color(0xFF9A8E85);
  /// Disabled / placeholder
  static const textDisabled  = Color(0xFF5A5250);

  // ── Borders & dividers ───────────────────────────────────────────────────
  static const borderSubtle = Color(0xFF2E2040);
  static const borderMedium = Color(0xFF3D2F55);

  // ── Tier colours (richer/deeper versions of the originals) ───────────────
  static const tierLocal    = Color(0xFF1A6B4A);  // Local Hero — deep emerald
  static const tierNational = Color(0xFF1A4C8A);  // National Rival — rich blue
  static const tierGlobal   = Color(0xFF5C2E8A);  // Global Icon — deep purple

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const error   = Color(0xFFCF6679);
  static const warning = Color(0xFFD4863A);
  static const success = Color(0xFF4CAF82);
}

// ---------------------------------------------------------------------------
// Text styles
// ---------------------------------------------------------------------------

abstract final class WwText {
  // ── Display — Cormorant Garamond (editorial / wine names) ────────────────

  /// Hero screen titles — large, elegant
  static TextStyle displayLarge({Color? color}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: 36,
        fontWeight: FontWeight.w300,
        letterSpacing: -0.5,
        height: 1.15,
        color: color ?? WwColors.textPrimary,
      );

  /// Section headings, card wine names
  static TextStyle headlineLarge({Color? color}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        height: 1.2,
        color: color ?? WwColors.textPrimary,
      );

  /// Wine name on result card
  static TextStyle headlineMedium({Color? color}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        height: 1.2,
        color: color ?? WwColors.textPrimary,
      );

  /// Wizard wit / quote lines — serif italic
  static TextStyle witQuote({Color? color}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 1.5,
        color: color ?? WwColors.gold,
      );

  // ── UI — DM Sans (all controls, body, labels) ────────────────────────────

  /// Button labels, prominent UI text
  static TextStyle labelLarge({Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: color ?? WwColors.textPrimary,
      );

  /// Tier badge strips, allcaps metadata
  static TextStyle badgeLabel({Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
        color: color ?? Colors.white,
      );

  /// Card title (brand/merchant name)
  static TextStyle titleLarge({Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color ?? WwColors.textPrimary,
      );

  static TextStyle titleMedium({Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: color ?? WwColors.textPrimary,
      );

  /// Standard body copy
  static TextStyle bodyLarge({Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: color ?? WwColors.textPrimary,
      );

  static TextStyle bodyMedium({Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.55,
        color: color ?? WwColors.textSecondary,
      );

  static TextStyle bodySmall({Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color ?? WwColors.textSecondary,
      );

  /// Price hero — large bold gold
  static TextStyle priceHero({Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color ?? WwColors.gold,
        letterSpacing: -0.5,
      );

  /// Currency prefix beside priceHero
  static TextStyle priceCurrency({Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color ?? WwColors.goldMuted,
        letterSpacing: 0.5,
      );

  /// Persona tag — small italic label above wine name
  static TextStyle personaTag({Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: 11,
        fontStyle: FontStyle.italic,
        color: color ?? WwColors.goldMuted,
        letterSpacing: 0.2,
      );
}

// ---------------------------------------------------------------------------
// Shared decoration helpers
// ---------------------------------------------------------------------------

abstract final class WwDecorations {
  /// Standard card decoration — dark surface with subtle border and shadow
  static BoxDecoration card({Color? borderColor, double radius = 14}) =>
      BoxDecoration(
        color: WwColors.bgSurface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? WwColors.borderSubtle,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 20,
            spreadRadius: -4,
            offset: Offset(0, 4),
          ),
        ],
      );

  /// Tier header gradient strip
  static BoxDecoration tierHeader(Color tierColor) => BoxDecoration(
        gradient: LinearGradient(
          colors: [tierColor, tierColor.withValues(alpha: 0.75)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      );

  /// Wit/quote callout — dark glass treatment
  static BoxDecoration witCallout() => BoxDecoration(
        color: const Color(0xFF1A0C00).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: WwColors.gold, width: 3),
        ),
      );

  /// Gold-glowing CTA button shadow
  static List<BoxShadow> goldGlow() => const [
        BoxShadow(
          color: Color(0x33C4965A),
          blurRadius: 24,
          spreadRadius: 0,
          offset: Offset(0, 4),
        ),
      ];
}

// ---------------------------------------------------------------------------
// MaterialApp ThemeData factory
// ---------------------------------------------------------------------------

abstract final class WwTheme {
  static ThemeData dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: WwColors.bgDeep,
      colorScheme: const ColorScheme.dark(
        primary:             WwColors.gold,
        onPrimary:           Colors.black,
        primaryContainer:    WwColors.bgElevated,   // used by Card, SegmentedButton etc
        onPrimaryContainer:  WwColors.textPrimary,
        secondary:           WwColors.rose,
        onSecondary:         WwColors.textPrimary,
        secondaryContainer:  WwColors.bgSurface,
        onSecondaryContainer: WwColors.textSecondary,
        surface:             WwColors.bgSurface,
        onSurface:           WwColors.textPrimary,
        onSurfaceVariant:    WwColors.textSecondary,
        surfaceContainerHighest: Color(0xFF241A30), // thumbnail unselected bg
        error:               WwColors.error,
        onError:             Colors.white,
        outline:             WwColors.borderSubtle,
        outlineVariant:      WwColors.borderMedium,
      ),
      useMaterial3: true,
    );

    final dmSansBase = GoogleFonts.dmSansTextTheme(base.textTheme).apply(
      bodyColor:    WwColors.textPrimary,
      displayColor: WwColors.textPrimary,
    );

    return base.copyWith(
      textTheme: dmSansBase,
      appBarTheme: AppBarTheme(
        backgroundColor:  Colors.transparent,
        elevation:        0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        centerTitle:      true,
        titleTextStyle:   WwText.headlineMedium(),
        iconTheme: const IconThemeData(color: WwColors.textPrimary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor:  WwColors.gold,
          foregroundColor:  Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: WwText.labelLarge(color: Colors.black),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WwColors.gold,
          side: const BorderSide(color: WwColors.gold),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: WwText.labelLarge(color: WwColors.gold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: WwColors.gold,
          textStyle: WwText.bodyMedium(color: WwColors.gold),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: WwColors.borderSubtle,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor:   WwColors.bgElevated,
        modalBackgroundColor: WwColors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: WwColors.gold,
      ),
      chipTheme: ChipThemeData(
        backgroundColor:  WwColors.bgSurface,
        side: const BorderSide(color: WwColors.borderSubtle),
        labelStyle: WwText.bodySmall(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      cardTheme: CardThemeData(
        color: WwColors.bgSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: WwColors.borderSubtle),
        ),
        margin: EdgeInsets.zero,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.black
              : WwColors.textDisabled,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? WwColors.gold
              : WwColors.borderSubtle,
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: WwText.bodyMedium(color: WwColors.textPrimary)
            .copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: WwText.bodySmall(),
        iconColor: WwColors.gold,
      ),
    );
  }

}
