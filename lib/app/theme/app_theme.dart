import 'package:flutter/material.dart';

import 'tokens.dart';

/// Material theme built from the Figma tokens.
///
/// Figma text style → Material text theme slot:
/// Display → displaySmall · Title/L → headlineSmall · Title/M → titleLarge · Title/S → titleMedium ·
/// Body → bodyLarge · Body/Strong → labelLarge · Caption → bodySmall · Label → labelSmall.
abstract final class AppTheme {
  static const fontFamily = 'PlusJakartaSans';

  static ThemeData light() {
    const textTheme = TextTheme(
      displaySmall: TextStyle(fontSize: 32, height: 40 / 32, fontWeight: FontWeight.w800, color: AppColors.text),
      headlineSmall: TextStyle(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w700, color: AppColors.text),
      titleLarge: TextStyle(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w700, color: AppColors.text),
      titleMedium: TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600, color: AppColors.text),
      bodyLarge: TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400, color: AppColors.text),
      bodyMedium: TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400, color: AppColors.text),
      labelLarge: TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w600, color: AppColors.text),
      bodySmall: TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500, color: AppColors.muted),
      labelSmall: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600, color: AppColors.muted),
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.danger,
      outline: AppColors.border,
    );

    final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full));
    const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md);

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: pill,
          padding: buttonPadding,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border),
          shape: pill,
          padding: buttonPadding,
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primarySoft,
        labelStyle: textTheme.labelSmall?.copyWith(color: AppColors.primary),
        side: BorderSide.none,
        shape: pill,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.canvas,
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.canvas,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
    );
  }
}
