import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/destination/data/models.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../destination/fakes.dart';
import '../helpers.dart';

/// End-to-end flows through the real app (router, shell, providers, screens) with the API replaced by a fake.
Widget _app(FakeDestinationRepository repo) => ProviderScope(
  overrides: [
    destinationRepositoryProvider.overrideWithValue(repo),
    pingProvider.overrideWith(
      (ref) async => PingInfo(name: 'pamplemousse', version: '1.0.0', environment: 'Test', utcNow: DateTime.utc(2026)),
    ),
  ],
  child: const TravelGenieApp(),
);

FakeDestinationRepository _repoWithPlaces() => FakeDestinationRepository(
  attractions: PlacesResult(
    items: [place(description: 'The largest ancient amphitheatre ever built.')],
    warnings: [],
  ),
  details: place(description: 'The largest ancient amphitheatre ever built.'),
);

void main() {
  testWidgets('Discover → Rome overview → all attractions → Colosseum → back', (tester) async {
    usePhoneSize(tester, height: 2000);
    await tester.pumpWidget(_app(_repoWithPlaces()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rome'));
    await tester.pumpAndSettle();
    expect(find.text('Visa required'), findsOneWidget);
    expect(find.text('Level 2'), findsOneWidget);

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(find.text('Rome · Places'), findsOneWidget);

    await tester.tap(find.text('Colosseum'));
    await tester.pumpAndSettle();
    expect(find.text('The largest ancient amphitheatre ever built.'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Rome · Places'), findsOneWidget);
  });

  testWidgets('Discover → search "ro" → Rome overview', (tester) async {
    usePhoneSize(tester, height: 2000);
    final repo = _repoWithPlaces();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Where to next?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ro');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rome'));
    await tester.pumpAndSettle();

    expect(find.text('Visa required'), findsOneWidget);
    expect(repo.overviewCalls.single, (passport: 'LB', currency: 'USD'));
  });

  testWidgets('overview that fails shows a retry, and the nav still works', (tester) async {
    usePhoneSize(tester, height: 2000);
    await tester.pumpWidget(_app(FakeDestinationRepository(overviewError: StateError('down'))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rome'));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Connected to pamplemousse 1.0.0 (Test)'), findsOneWidget);
  });
}
