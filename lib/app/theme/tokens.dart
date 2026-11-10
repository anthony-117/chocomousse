/// Spacing tokens ("Dimension / space/*" in Figma).
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Corner radius tokens ("Dimension / radius/*" in Figma). Colours are in `palette.dart` (design v1.0, light and dark).
abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const xl = 16.0;
  static const lg = 20.0;
  static const full = 999.0;
}

/// Width at which layouts switch from the mobile design to the web/desktop design.
const double kWideLayoutBreakpoint = 900;
