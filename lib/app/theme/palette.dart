import 'package:flutter/material.dart';

/// Colour tokens of design v1.0, mirroring the Figma variables (file `s52ShmznT28QgNN6u6Wddu`, page "v1.0 — Design
/// system (approved)"), in light and dark. `statusDanger` and `statusDangerSoft` are not in the v1 file yet: they keep
/// v0.2's red, with a lighter red for dark mode (spec 008 research R-3, owner decision 2026-11-10).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bgApp,
    required this.bgSidebar,
    required this.bgSurface,
    required this.bgSubtle,
    required this.bgHover,
    required this.borderDefault,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.brandPrimary,
    required this.brandPrimarySoft,
    required this.brandOnPrimary,
    required this.brandAccent,
    required this.brandAccentSoft,
    required this.statusSuccess,
    required this.statusSuccessSoft,
    required this.statusWarning,
    required this.statusWarningSoft,
    required this.statusDanger,
    required this.statusDangerSoft,
    required this.raisedShadow,
  });

  final Color bgApp;
  final Color bgSidebar;
  final Color bgSurface;
  final Color bgSubtle;
  final Color bgHover;
  final Color borderDefault;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color brandPrimary;
  final Color brandPrimarySoft;
  final Color brandOnPrimary;
  final Color brandAccent;
  final Color brandAccentSoft;
  final Color statusSuccess;
  final Color statusSuccessSoft;
  final Color statusWarning;
  final Color statusWarningSoft;
  final Color statusDanger;
  final Color statusDangerSoft;

  /// "Shadow raised" in Figma: cards and floating surfaces.
  final List<BoxShadow> raisedShadow;

  static const _shadow = [
    BoxShadow(color: Color(0x0F1C1A14), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0D1C1A14), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const light = AppPalette(
    bgApp: Color(0xFFFAF9F6),
    bgSidebar: Color(0xFFF2F0EA),
    bgSurface: Color(0xFFFFFFFF),
    bgSubtle: Color(0xFFEFEDE6),
    bgHover: Color(0xFFE8E5DD),
    borderDefault: Color(0xFFE5E2DA),
    textPrimary: Color(0xFF1D1C1A),
    textSecondary: Color(0xFF6F6B63),
    textTertiary: Color(0xFF9A968D),
    brandPrimary: Color(0xFF4338CA),
    brandPrimarySoft: Color(0xFFECEBFA),
    brandOnPrimary: Color(0xFFFFFFFF),
    brandAccent: Color(0xFFFF7A59),
    brandAccentSoft: Color(0xFFFFEFE9),
    statusSuccess: Color(0xFF1F9D6B),
    statusSuccessSoft: Color(0xFFE3F4EC),
    statusWarning: Color(0xFFB7791F),
    statusWarningSoft: Color(0xFFFBF1DE),
    statusDanger: Color(0xFFD64545),
    statusDangerSoft: Color(0xFFFBE7E7),
    raisedShadow: _shadow,
  );

  static const dark = AppPalette(
    bgApp: Color(0xFF1F1E1C),
    bgSidebar: Color(0xFF181816),
    bgSurface: Color(0xFF2A2926),
    bgSubtle: Color(0xFF33312D),
    bgHover: Color(0xFF3A3834),
    borderDefault: Color(0xFF3B3935),
    textPrimary: Color(0xFFF3F1EC),
    textSecondary: Color(0xFFA9A59D),
    textTertiary: Color(0xFF7D7973),
    brandPrimary: Color(0xFF8E88F2),
    brandPrimarySoft: Color(0xFF2D2A50),
    brandOnPrimary: Color(0xFF14132B),
    brandAccent: Color(0xFFFF8F73),
    brandAccentSoft: Color(0xFF45291F),
    statusSuccess: Color(0xFF3CC48E),
    statusSuccessSoft: Color(0xFF1D3A2E),
    statusWarning: Color(0xFFE8B04B),
    statusWarningSoft: Color(0xFF3F3220),
    statusDanger: Color(0xFFF07A7A),
    statusDangerSoft: Color(0xFF3D2222),
    raisedShadow: _shadow,
  );

  @override
  AppPalette copyWith({
    Color? bgApp,
    Color? bgSidebar,
    Color? bgSurface,
    Color? bgSubtle,
    Color? bgHover,
    Color? borderDefault,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? brandPrimary,
    Color? brandPrimarySoft,
    Color? brandOnPrimary,
    Color? brandAccent,
    Color? brandAccentSoft,
    Color? statusSuccess,
    Color? statusSuccessSoft,
    Color? statusWarning,
    Color? statusWarningSoft,
    Color? statusDanger,
    Color? statusDangerSoft,
    List<BoxShadow>? raisedShadow,
  }) => AppPalette(
    bgApp: bgApp ?? this.bgApp,
    bgSidebar: bgSidebar ?? this.bgSidebar,
    bgSurface: bgSurface ?? this.bgSurface,
    bgSubtle: bgSubtle ?? this.bgSubtle,
    bgHover: bgHover ?? this.bgHover,
    borderDefault: borderDefault ?? this.borderDefault,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    brandPrimary: brandPrimary ?? this.brandPrimary,
    brandPrimarySoft: brandPrimarySoft ?? this.brandPrimarySoft,
    brandOnPrimary: brandOnPrimary ?? this.brandOnPrimary,
    brandAccent: brandAccent ?? this.brandAccent,
    brandAccentSoft: brandAccentSoft ?? this.brandAccentSoft,
    statusSuccess: statusSuccess ?? this.statusSuccess,
    statusSuccessSoft: statusSuccessSoft ?? this.statusSuccessSoft,
    statusWarning: statusWarning ?? this.statusWarning,
    statusWarningSoft: statusWarningSoft ?? this.statusWarningSoft,
    statusDanger: statusDanger ?? this.statusDanger,
    statusDangerSoft: statusDangerSoft ?? this.statusDangerSoft,
    raisedShadow: raisedShadow ?? this.raisedShadow,
  );

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      bgApp: c(bgApp, other.bgApp),
      bgSidebar: c(bgSidebar, other.bgSidebar),
      bgSurface: c(bgSurface, other.bgSurface),
      bgSubtle: c(bgSubtle, other.bgSubtle),
      bgHover: c(bgHover, other.bgHover),
      borderDefault: c(borderDefault, other.borderDefault),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      brandPrimary: c(brandPrimary, other.brandPrimary),
      brandPrimarySoft: c(brandPrimarySoft, other.brandPrimarySoft),
      brandOnPrimary: c(brandOnPrimary, other.brandOnPrimary),
      brandAccent: c(brandAccent, other.brandAccent),
      brandAccentSoft: c(brandAccentSoft, other.brandAccentSoft),
      statusSuccess: c(statusSuccess, other.statusSuccess),
      statusSuccessSoft: c(statusSuccessSoft, other.statusSuccessSoft),
      statusWarning: c(statusWarning, other.statusWarning),
      statusWarningSoft: c(statusWarningSoft, other.statusWarningSoft),
      statusDanger: c(statusDanger, other.statusDanger),
      statusDangerSoft: c(statusDangerSoft, other.statusDangerSoft),
      raisedShadow: t < 0.5 ? raisedShadow : other.raisedShadow,
    );
  }
}

/// The current mode's colour tokens: `context.palette.textPrimary`.
extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
