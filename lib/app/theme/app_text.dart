import 'package:flutter/painting.dart';

/// Text styles of design v1.0 (Figma text styles "v1/…"). They carry no colour: the theme's text theme and the widgets
/// add it from the palette.
abstract final class AppText {
  static const sans = 'PlusJakartaSans';
  static const serif = 'Newsreader';

  /// "v1/Greeting": the home's "Where to next, Fares?" on wide screens (W1).
  static const greeting = TextStyle(
    fontFamily: serif,
    fontSize: 40,
    height: 48 / 40,
    fontWeight: FontWeight.w400,
    letterSpacing: -1,
  );

  /// "v1/Greeting mobile" (M1).
  static const greetingMobile = TextStyle(
    fontFamily: serif,
    fontSize: 30,
    height: 36 / 30,
    fontWeight: FontWeight.w400,
    letterSpacing: -1,
  );

  /// "v1/Serif title": chat and plan titles.
  static const serifTitle = TextStyle(
    fontFamily: serif,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.5,
  );

  static const title = TextStyle(fontFamily: sans, fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontFamily: sans, fontSize: 15, height: 24 / 15, fontWeight: FontWeight.w400);
  static const bodyStrong = TextStyle(fontFamily: sans, fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w600);
  static const small = TextStyle(fontFamily: sans, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400);
  static const smallStrong = TextStyle(fontFamily: sans, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600);

  /// "v1/Micro": the upper-case labels above card groups ("BEST FLIGHT FOR YOU").
  static const micro = TextStyle(
    fontFamily: sans,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2,
  );
}
