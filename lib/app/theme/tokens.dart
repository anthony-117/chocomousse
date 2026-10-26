import 'package:flutter/painting.dart';

/// Colour tokens, mirroring the "Color" variable collection in the Figma design system (v0.2).
abstract final class AppColors {
  static const primary = Color(0xFF4338CA);
  static const primarySoft = Color(0xFFEEF0FF);
  static const accent = Color(0xFFFF7A59);
  static const canvas = Color(0xFFF7F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF14142B);
  static const muted = Color(0xFF6B6B85);
  static const onPrimary = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4E4EE);
  static const success = Color(0xFF1F9D6B);
  static const warning = Color(0xFFE8A317);
  static const danger = Color(0xFFD64545);
}

/// Spacing tokens ("Dimension / space/*" in Figma).
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Corner radius tokens ("Dimension / radius/*" in Figma).
abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 20.0;
  static const full = 999.0;
}

/// Width at which layouts switch from the mobile design to the web/desktop design.
const double kWideLayoutBreakpoint = 900;

/// Soft indigo shadow used by floating surfaces (nav, plan dock).
const List<BoxShadow> kSoftShadow = [BoxShadow(color: Color(0x1A4338CA), blurRadius: 20, offset: Offset(0, 6))];
