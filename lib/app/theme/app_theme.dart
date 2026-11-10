import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Material themes built from the v1.0 tokens, in light and dark.
///
/// The text slots keep the sizes the v0.2 screens were laid out with, in v1 colours, so the screens that aren't
/// redesigned yet (Explore, My plans, the profile) read correctly in both modes (spec 008 FR-009). The v1 screens use
/// [AppText] directly.
abstract final class AppTheme {
  static const String fontFamily = AppText.sans;

  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final textTheme = TextTheme(
      displaySmall: TextStyle(fontSize: 32, height: 40 / 32, fontWeight: FontWeight.w800, color: p.textPrimary),
      headlineSmall: TextStyle(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w700, color: p.textPrimary),
      titleLarge: TextStyle(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w700, color: p.textPrimary),
      titleMedium: TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600, color: p.textPrimary),
      bodyLarge: TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400, color: p.textPrimary),
      bodyMedium: TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400, color: p.textPrimary),
      labelLarge: TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w600, color: p.textPrimary),
      bodySmall: TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500, color: p.textSecondary),
      labelSmall: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600, color: p.textSecondary),
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: p.brandPrimary,
      brightness: brightness,
      primary: p.brandPrimary,
      onPrimary: p.brandOnPrimary,
      primaryContainer: p.brandPrimarySoft,
      secondary: p.brandAccent,
      surface: p.bgSurface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerHighest: p.bgSubtle,
      error: p.statusDanger,
      outline: p.borderDefault,
      outlineVariant: p.borderDefault,
    );

    final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full));
    const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.bgApp,
      canvasColor: p.bgApp,
      dividerColor: p.borderDefault,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: p.textPrimary),
      extensions: [p],
      appBarTheme: AppBarTheme(
        backgroundColor: p.bgApp,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.brandPrimary,
          foregroundColor: p.brandOnPrimary,
          shape: pill,
          padding: buttonPadding,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          backgroundColor: p.bgSurface,
          side: BorderSide(color: p.borderDefault),
          shape: pill,
          padding: buttonPadding,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: p.brandPrimary)),
      chipTheme: ChipThemeData(
        backgroundColor: p.bgSubtle,
        selectedColor: p.brandPrimarySoft,
        labelStyle: textTheme.labelSmall?.copyWith(color: p.textPrimary),
        side: BorderSide(color: p.borderDefault),
        shape: pill,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.bgSurface,
        hintStyle: textTheme.bodyLarge?.copyWith(color: p.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: BorderSide(color: p.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: BorderSide(color: p.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: BorderSide(color: p.brandPrimary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: p.bgSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: p.borderDefault),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: p.bgSurface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.bgSurface, surfaceTintColor: Colors.transparent),
      drawerTheme: DrawerThemeData(backgroundColor: p.bgSidebar, surfaceTintColor: Colors.transparent),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.bgApp),
        behavior: SnackBarBehavior.floating,
      ),
      menuTheme: MenuThemeData(style: MenuStyle(backgroundColor: WidgetStatePropertyAll(p.bgSurface))),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.brandPrimary),
    );
  }
}
