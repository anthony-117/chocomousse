import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/core/links/link_opener.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/flights/data/flight_repository.dart';
import 'package:chocomousse/features/flights/presentation/widgets/fare_tile.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../destination/fakes.dart';
import '../flights/fakes.dart';
import '../helpers.dart';

void main() {
  testWidgets('Rome overview → flights → choose a city → open a fare → back, and the city is remembered', (
    tester,
  ) async {
    usePhoneSize(tester, height: 2200);
    final flights = FakeFlightRepository();
    final opened = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          destinationRepositoryProvider.overrideWithValue(FakeDestinationRepository()),
          flightRepositoryProvider.overrideWithValue(flights),
          linkOpenerProvider.overrideWithValue((url) async {
            opened.add(url);
            return true;
          }),
          pingProvider.overrideWith(
            (ref) async =>
                PingInfo(name: 'pamplemousse', version: '1.0.0', environment: 'Test', utcNow: DateTime.utc(2026)),
          ),
        ],
        child: const TravelGenieApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rome'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your departure city'), findsOneWidget);
    expect(flights.queries, isEmpty);

    await tester.tap(find.text('See flights to Rome'));
    await tester.pumpAndSettle();
    expect(find.text('Flights to Rome'), findsOneWidget);
    expect(flights.queries, isEmpty);

    await tester.tap(find.text('Choose a city'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ro');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rome').last);
    await tester.pumpAndSettle();
    expect(flights.queries, hasLength(1));

    await tester.tap(find.byType(FareTile));
    await tester.pump();
    expect(opened, hasLength(1));

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.textContaining('From Rome'), findsOneWidget);
  });
}
