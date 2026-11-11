import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/hotels/data/hotel_repository.dart';
import 'package:chocomousse/features/shell/sidebar.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../account/fakes.dart';
import '../destination/fakes.dart';
import '../helpers.dart';
import '../hotels/fakes.dart';

Widget _app() => ProviderScope(
  overrides: [
    ...signedIn(),
    destinationRepositoryProvider.overrideWithValue(FakeDestinationRepository()),
    hotelRepositoryProvider.overrideWithValue(FakeHotelRepository()),
    pingProvider.overrideWith(
      (ref) async => PingInfo(name: 'pamplemousse', version: '1.0.0', environment: 'Test', utcNow: DateTime.utc(2026)),
    ),
  ],
  child: const TravelGenieApp(),
);

GoRouter _router(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TravelGenieApp))).read(routerProvider);

String _at(WidgetTester tester) => _router(tester).routerDelegate.currentConfiguration.uri.path;

void main() {
  for (final (name, size) in [('phone', phone), ('desktop', desktop)]) {
    testWidgets('$name: home → Explore → Rome → hotels → My plans → profile, all inside the shell', (tester) async {
      tester.view
        ..physicalSize = Size(size.width, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(_at(tester), AppPaths.home);

      await openShellPlace(tester, 'Explore');
      expect(_at(tester), AppPaths.explore);
      await tester.tap(find.text('Rome'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See hotels in Rome'));
      await tester.pumpAndSettle();
      expect(find.text('Hotels in Rome'), findsOneWidget);

      if (size == phone) {
        // Deeper screens keep their own Back header on phones; go back to a top-level place for the menu.
        await tester.tap(find.byTooltip('Back').first);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Back').first);
        await tester.pumpAndSettle();
      }
      await openShellPlace(tester, 'My plans');
      expect(_at(tester), AppPaths.plans);

      await openProfileFromMenu(tester);
      expect(_at(tester), AppPaths.profile);
      expect(find.text('Connected to pamplemousse 1.0.0 (Test)'), findsOneWidget);
    });
  }

  testWidgets('a deep link to a city hotels page still renders inside the shell', (tester) async {
    tester.view
      ..physicalSize = desktop
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    _router(tester).go('/discover/destination/3169070/hotels');
    await tester.pumpAndSettle();
    expect(find.text('Hotels in Rome'), findsOneWidget);
    expect(find.byType(Sidebar), findsOneWidget);
  });
}
