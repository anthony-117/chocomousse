import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app() => ProviderScope(
  overrides: [
    pingProvider.overrideWith(
      (ref) async => PingInfo(name: 'pamplemousse', version: '1.0.0', environment: 'Test', utcNow: DateTime.utc(2026)),
    ),
  ],
  child: const TravelGenieApp(),
);

void main() {
  testWidgets('phone layout opens on Discover and switches tabs with the floating nav', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Discover'), findsOneWidget);

    await tester.tap(find.byTooltip('Plans'));
    await tester.pumpAndSettle();
    expect(find.text('My plans'), findsOneWidget);

    await tester.tap(find.byTooltip('Assistant'));
    await tester.pumpAndSettle();
    expect(find.text('Your travel assistant'), findsOneWidget);

    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Connected to pamplemousse 1.0.0 (Test)'), findsOneWidget);
  });

  testWidgets('wide layout shows the web header with text links', (tester) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // "Discover" appears twice: header link + page title.
    expect(find.text('Discover'), findsNWidgets(2));

    await tester.tap(find.text('Plans'));
    await tester.pumpAndSettle();
    expect(find.text('My plans'), findsOneWidget);
  });
}
