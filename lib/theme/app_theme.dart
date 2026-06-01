import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Pocket Score — "Cricket Pro" Design System
/// Primary   : Emerald green  (cricket pitch / turf)
/// Scoreboard: Deep blue      (stadium LED board)
/// Accent    : Amber/gold     (trophy / highlights)
/// Ball      : Crimson red    (cricket ball)
/// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  // ── Backgrounds ────────────────────────────────────────────
  static const Color bg           = Color(0xFFF2F5FA);
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFEEF2F7);
  static const Color surfaceGreen = Color(0xFFECFDF5);
  static const Color card         = Color(0xFFFFFFFF);

  // ── Primary : Cricket Green ─────────────────────────────────
  static const Color primary      = Color(0xFF047857);
  static const Color primaryLight = Color(0xFF10B981);
  static const Color primaryDark  = Color(0xFF064E3B);

  // ── Accent : Gold / Amber ───────────────────────────────────
  static const Color accent       = Color(0xFFD97706);
  static const Color accentLight  = Color(0xFFFCD34D);

  // ── Scoreboard Blue ─────────────────────────────────────────
  static const Color scoreBlue    = Color(0xFF1E3A8A);
  static const Color scoreBlueLight = Color(0xFF1D4ED8);

  // ── Semantic ────────────────────────────────────────────────
  static const Color success      = Color(0xFF16A34A);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color danger       = Color(0xFFDC2626);
  static const Color info         = Color(0xFF2563EB);

  // ── Scoring ─────────────────────────────────────────────────
  static const Color four         = Color(0xFF2563EB);
  static const Color six          = Color(0xFF16A34A);
  static const Color wicket       = Color(0xFFDC2626);
  static const Color wide         = Color(0xFFF97316);
  static const Color noBall       = Color(0xFF9333EA);
  static const Color dot          = Color(0xFFCBD5E1);

  // ── Text ────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF374151);
  static const Color textMuted     = Color(0xFF9CA3AF);

  // ── Borders ─────────────────────────────────────────────────
  static const Color border      = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);

  // ── Gradients ───────────────────────────────────────────────
  /// Deep cricket-pitch green — used in headers
  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF064E3B), Color(0xFF065F46), Color(0xFF047857)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Lighter green — buttons, cards
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF047857), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dark blue — live scoreboard panel
  static const LinearGradient scoreGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gold — trophies, MoM, leaderboard podium
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFB45309), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF15803D), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFB91C1C), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ── Decoration helpers ────────────────────────────────────────
class AppDecorations {
  /// Standard white card with soft shadow
  static BoxDecoration card({double radius = 16}) => BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(radius),
    border: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
    boxShadow: const [
      BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 3)),
    ],
  );

  /// Gradient card (header, scoreboard, etc.)
  static BoxDecoration gradientCard(LinearGradient gradient, {double radius = 20}) => BoxDecoration(
    gradient: gradient,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: gradient.colors.first.withValues(alpha: 0.35),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );

  /// Tinted card with colored left border accent
  static BoxDecoration tintedCard(Color color, {double radius = 14}) => BoxDecoration(
    color: color.withValues(alpha: 0.07),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: color.withValues(alpha: 0.2)),
  );

  /// Ghost card — just a border, no fill
  static BoxDecoration ghostCard({Color? borderColor, double radius = 14}) => BoxDecoration(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? AppColors.border, width: 1.5),
  );

  // Keep old name for compat
  static BoxDecoration glassCard({double opacity = 0.08}) => card();
}

// ── Theme ─────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 0.3,
      ),
      iconTheme: IconThemeData(color: AppColors.textSecondary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      prefixIconColor: AppColors.textMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      contentTextStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
      elevation: 4,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceLight,
      selectedColor: AppColors.primary,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );

  static ThemeData get dark => light;
}
