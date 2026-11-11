import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/features/shell/app_drawer.dart';
import 'package:chocomousse/features/shell/sidebar.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account/fakes.dart';
import 'helpers.dart';

Widget _app() => ProviderScope(
  overrides: [
    ...signedIn(),
    pingProvider.overrideWith(
      (ref) async => PingInfo(name: 'pamplemousse', version: '1.0.0', environment: 'Test', utcNow: DateTime.utc(2026)),
    ),
  ],
  child: const TravelGenieApp(),
);

void _size(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('phone layout opens on the home, with the top bar and the drawer', (tester) async {
    _size(tester, phone);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(Sidebar), findsNothing);
    expect(find.text('TravelGenie'), findsOneWidget);
    expect(find.byTooltip('New trip chat'), findsOneWidget);

    await openShellPlace(tester, 'Explore');
    expect(find.text('Explore'), findsOneWidget, reason: 'the top bar names the place');
    expect(find.byType(AppDrawer), findsNothing, reason: 'the drawer closes after a choice');

    await openShellPlace(tester, 'My plans');
    expect(find.text('My plans'), findsWidgets);

    await openProfileFromMenu(tester);
    expect(find.text('Connected to pamplemousse 1.0.0 (Test)'), findsOneWidget);
  });

  testWidgets('wide layout shows the sidebar beside the page', (tester) async {
    _size(tester, desktop);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(Sidebar), findsOneWidget);
    expect(find.byTooltip('Open menu'), findsNothing);

    await openShellPlace(tester, 'Explore');
    expect(find.text('Where to next?'), findsWidgets);

    await openShellPlace(tester, 'My plans');
    expect(find.text('My plans'), findsWidgets);
  });
}
