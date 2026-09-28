import 'package:flutter/material.dart';

class AppTokens {
  // Spacing
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;

  // Radius
  static const double r8 = 8.0;
  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double r20 = 20.0;
}

class AppColors {
  // Analytical Dark Palette
  static const Color backgroundDark = Color(0xFF121316);
  static const Color surfaceDark = Color(0xFF1E1F24);
  static const Color cardDark = Color(0xFF262830);
  static const Color cardBorder = Color(0xFF363945);

  // Status Indicators
  static const Color safeEmerald = Color(0xFF2D6A4F);
  static const Color safeEmeraldAccent = Color(0xFF40916C);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color alertBrickRed = Color(0xFFDC2626);

  // Typography & UI Elements
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color accentCyan = Color(0xFF0EA5E9);
  static const Color dividerColor = Color(0xFF2E313C);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.safeEmeraldAccent,
        onPrimary: AppColors.backgroundDark,
        secondary: AppColors.warningAmber,
        error: AppColors.alertBrickRed,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardDark,
        disabledColor: AppColors.cardDark.withAlpha(128),
        selectedColor: AppColors.safeEmerald.withAlpha(77),
        secondarySelectedColor: AppColors.warningAmber.withAlpha(77),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        labelStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
        ),
        brightness: Brightness.dark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        modalBackgroundColor: AppColors.surfaceDark,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.textMuted,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerColor,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
