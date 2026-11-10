import 'package:chocomousse/app/theme/app_theme.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'destination/fakes.dart';

/// A phone surface (iPhone 14 size) and a desktop window, for layout tests.
const phone = Size(390, 844);
const desktop = Size(1440, 900);

/// Hosts one screen with the app theme and a fake repository.
Widget host(Widget screen, FakeDestinationRepository repo) => ProviderScope(
  overrides: [destinationRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: screen),
  ),
);

/// Sets a phone-sized surface (390 wide) for the current test.
void usePhoneSize(WidgetTester tester, {double height = 1400}) {
  tester.view
    ..physicalSize = Size(390, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Pumps [widget] in a [MaterialApp] with both v1 themes, at [size] and in [mode].
Future<void> pumpApp(
  WidgetTester tester,
  Widget widget, {
  Size size = phone,
  ThemeMode mode = ThemeMode.light,
  List<Override> overrides = const [],
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: Scaffold(body: widget),
      ),
    ),
  );
}

/// Runs the same widget test in light and in dark mode.
void forBothModes(String description, Future<void> Function(WidgetTester tester, ThemeMode mode) body) {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('$description (${mode.name})', (tester) => body(tester, mode));
  }
}

/// Opens a shell place ("Explore", "My plans", "Saved", "New trip chat") the way a traveller does: through the drawer
/// on phones, the sidebar on wide screens.
Future<void> openShellPlace(WidgetTester tester, String label) async {
  final menu = find.byTooltip('Open menu');
  if (menu.evaluate().isNotEmpty) {
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.bySemanticsLabel(label)));
  } else {
    await tester.tap(find.bySemanticsLabel(label).first);
  }
  await tester.pumpAndSettle();
}

/// Opens Preferences and account from the account menu (in the drawer on phones).
Future<void> openProfileFromMenu(WidgetTester tester) async {
  final menu = find.byTooltip('Open menu');
  if (menu.evaluate().isNotEmpty) {
    await tester.tap(menu);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.bySemanticsLabel(RegExp('^Account')).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Preferences and account'));
  await tester.pumpAndSettle();
}
