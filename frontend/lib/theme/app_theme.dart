/// app_theme.dart
///
/// Cellar Sage design system — "The Sage" palette.
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
  /// Main scaffold background — charcoal-grape, AMOLED-safe
  static const bgDeep     = Color(0xFF0F0F14);
  /// Raised card / surface
  static const bgSurface  = Color(0xFF16161E);
  /// Top-layer overlays, bottom sheets
  static const bgElevated = Color(0xFF1E1E2C);

  // ── Accent — Electric Violet ─────────────────────────────────────────────
  /// Primary CTA, price hero, active states — 9.2:1 on bgDeep (WCAG AAA)
  static const violet      = Color(0xFFC3A5FF);
  /// Muted violet for secondary use (currency prefix, inactive)
  static const violetMuted = Color(0xFF7B6FA3);
  /// Very faint violet tint for selected-card overlays
  static const violetTint  = Color(0x14C3A5FF);  // violet @ 8%

  // ── Accent — Sage Rose ───────────────────────────────────────────────────
  /// Complementary accent — used sparingly
  static const rose       = Color(0xFF7D3E5E);

  // ── Text ─────────────────────────────────────────────────────────────────
  /// Primary text — pure white, 19.1:1 on bgDeep (WCAG AAA)
  static const textPrimary   = Color(0xFFFFFFFF);
  /// Secondary text — cool grey, 6.8:1 on bgDeep (WCAG AA)
  static const textSecondary = Color(0xFF9499B8);
  /// Disabled / placeholder
  static const textDisabled  = Color(0xFF5A5860);

  // ── Borders & dividers ───────────────────────────────────────────────────
  static const borderSubtle = Color(0xFF252535);
  static const borderMedium = Color(0xFF323248);

  // ── Tier colours ────────────────────────────────────────────────────────
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

  /// Sage wit / quote lines — serif italic
  static TextStyle witQuote({Color? color}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 1.5,
        color: color ?? WwColors.violet,
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

  /// Price hero — large bold violet
  static TextStyle priceHero({Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color ?? WwColors.violet,
        letterSpacing: -0.5,
      );

  /// Currency prefix beside priceHero
  static TextStyle priceCurrency({Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color ?? WwColors.violetMuted,
        letterSpacing: 0.5,
      );

  /// Persona tag — small italic label above wine name
  static TextStyle personaTag({Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: 11,
        fontStyle: FontStyle.italic,
        color: color ?? WwColors.violetMuted,
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

  /// Sage wit/quote callout — dark glass treatment
  static BoxDecoration witCallout() => BoxDecoration(
        color: const Color(0xFF0F0F20).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: WwColors.violet, width: 3),
        ),
      );

  /// Violet-glowing CTA button shadow
  static List<BoxShadow> violetGlow() => const [
        BoxShadow(
          color: Color(0x33C3A5FF),
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
        primary:              WwColors.violet,
        onPrimary:            Color(0xFF0F0F14),      // dark text on violet — 9.2:1 (WCAG AAA)
        primaryContainer:     WwColors.bgElevated,
        onPrimaryContainer:   WwColors.textPrimary,
        secondary:            WwColors.rose,
        onSecondary:          WwColors.textPrimary,
        secondaryContainer:   WwColors.bgSurface,
        onSecondaryContainer: WwColors.textSecondary,
        surface:              WwColors.bgSurface,
        onSurface:            WwColors.textPrimary,
        onSurfaceVariant:     WwColors.textSecondary,
        surfaceContainerHighest: Color(0xFF1E1E2C),
        error:                WwColors.error,
        onError:              Colors.white,
        outline:              WwColors.borderSubtle,
        outlineVariant:       WwColors.borderMedium,
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
          backgroundColor: WwColors.violet,
          foregroundColor: const Color(0xFF0F0F14),  // dark text — 9.2:1 on violet (WCAG AAA)
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: WwText.labelLarge(color: const Color(0xFF0F0F14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WwColors.violet,
          side: const BorderSide(color: WwColors.violet),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: WwText.labelLarge(color: WwColors.violet),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: WwColors.violet,
          textStyle: WwText.bodyMedium(color: WwColors.violet),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: WwColors.borderSubtle,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor:      WwColors.bgElevated,
        modalBackgroundColor: WwColors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: WwColors.violet,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: WwColors.bgSurface,
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
              ? const Color(0xFF0F0F14)
              : WwColors.textDisabled,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? WwColors.violet
              : WwColors.borderSubtle,
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: WwText.bodyMedium(color: WwColors.textPrimary)
            .copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: WwText.bodySmall(),
        iconColor: WwColors.violet,
      ),
    );
  }
}
