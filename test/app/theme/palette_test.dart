import 'dart:math' as math;

import 'package:chocomousse/app/theme/app_theme.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Color> _colours(AppPalette p) => {
  'bgApp': p.bgApp,
  'bgSidebar': p.bgSidebar,
  'bgSurface': p.bgSurface,
  'bgSubtle': p.bgSubtle,
  'bgHover': p.bgHover,
  'borderDefault': p.borderDefault,
  'textPrimary': p.textPrimary,
  'textSecondary': p.textSecondary,
  'textTertiary': p.textTertiary,
  'brandPrimary': p.brandPrimary,
  'brandPrimarySoft': p.brandPrimarySoft,
  'brandOnPrimary': p.brandOnPrimary,
  'brandAccent': p.brandAccent,
  'brandAccentSoft': p.brandAccentSoft,
  'statusSuccess': p.statusSuccess,
  'statusSuccessSoft': p.statusSuccessSoft,
  'statusWarning': p.statusWarning,
  'statusWarningSoft': p.statusWarningSoft,
  'statusDanger': p.statusDanger,
  'statusDangerSoft': p.statusDangerSoft,
};

const _names = [
  'bgApp', 'bgSidebar', 'bgSurface', 'bgSubtle', 'bgHover', 'borderDefault', 'textPrimary', 'textSecondary', //
  'textTertiary', 'brandPrimary', 'brandPrimarySoft', 'brandOnPrimary', 'brandAccent', 'brandAccentSoft',
  'statusSuccess', 'statusSuccessSoft', 'statusWarning', 'statusWarningSoft', 'statusDanger', 'statusDangerSoft',
];

/// The values of spec 008 task T005, in field order.
const _light = [
  0xFFFAF9F6, 0xFFF2F0EA, 0xFFFFFFFF, 0xFFEFEDE6, 0xFFE8E5DD, 0xFFE5E2DA, 0xFF1D1C1A, 0xFF6F6B63, 0xFF9A968D, //
  0xFF4338CA, 0xFFECEBFA, 0xFFFFFFFF, 0xFFFF7A59, 0xFFFFEFE9, 0xFF1F9D6B, 0xFFE3F4EC, 0xFFB7791F, 0xFFFBF1DE,
  0xFFD64545, 0xFFFBE7E7,
];
const _dark = [
  0xFF1F1E1C, 0xFF181816, 0xFF2A2926, 0xFF33312D, 0xFF3A3834, 0xFF3B3935, 0xFFF3F1EC, 0xFFA9A59D, 0xFF7D7973, //
  0xFF8E88F2, 0xFF2D2A50, 0xFF14132B, 0xFFFF8F73, 0xFF45291F, 0xFF3CC48E, 0xFF1D3A2E, 0xFFE8B04B, 0xFF3F3220,
  0xFFF07A7A, 0xFF3D2222,
];

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final (name, palette, expected) in [('light', AppPalette.light, _light), ('dark', AppPalette.dark, _dark)]) {
    group('$name palette', () {
      test('every value matches the design', () {
        final colours = _colours(palette);
        for (var i = 0; i < _names.length; i++) {
          expect(colours[_names[i]]!.toARGB32(), expected[i], reason: _names[i]);
        }
        expect(palette.raisedShadow, hasLength(2));
        expect(palette.raisedShadow.first.color.toARGB32(), 0x0F1C1A14);
        expect(palette.raisedShadow.first.blurRadius, 16);
      });

      test('text and brand colours reach 4.5:1 on the app and surface backgrounds (SC-007)', () {
        for (final fg in [palette.textPrimary, palette.textSecondary, palette.brandPrimary]) {
          for (final bg in [palette.bgApp, palette.bgSurface]) {
            expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '$fg on $bg');
          }
        }
      });
    });
  }

  test('lerp returns each end at 0 and 1', () {
    final atStart = AppPalette.light.lerp(AppPalette.dark, 0);
    final atEnd = AppPalette.light.lerp(AppPalette.dark, 1);
    expect(_colours(atStart), _colours(AppPalette.light));
    expect(_colours(atEnd), _colours(AppPalette.dark));
  });

  test('copyWith changes only the given field', () {
    final copy = AppPalette.light.copyWith(bgApp: const Color(0xFF000000));
    expect(copy.bgApp, const Color(0xFF000000));
    expect(copy.textPrimary, AppPalette.light.textPrimary);
  });

  test('the themes carry their palette', () {
    expect(AppTheme.light().extension<AppPalette>(), AppPalette.light);
    expect(AppTheme.dark().extension<AppPalette>(), AppPalette.dark);
    expect(AppTheme.dark().scaffoldBackgroundColor, AppPalette.dark.bgApp);
  });
}
