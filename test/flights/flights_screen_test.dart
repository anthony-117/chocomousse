import 'dart:async';

import 'package:chocomousse/app/theme/app_theme.dart';
import 'package:chocomousse/core/links/link_opener.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/destination/data/models.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/flights/application/flight_providers.dart';
import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:chocomousse/features/flights/data/flight_repository.dart';
import 'package:chocomousse/features/flights/presentation/flights_screen.dart';
import 'package:chocomousse/features/flights/presentation/widgets/fare_tile.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../destination/fakes.dart';
import '../helpers.dart';
import 'fakes.dart';

const _romeId = '3169070';

/// Opens links in a list, and fails when told to.
class _Links {
  final opened = <String>[];
  bool works = true;

  Future<bool> open(String url) async {
    opened.add(url);
    return works;
  }
}

Widget _host(FakeFlightRepository flights, {_Links? links, bool withCity = true}) => ProviderScope(
  retry: noRetry,
  overrides: [
    destinationRepositoryProvider.overrideWithValue(FakeDestinationRepository()),
    flightRepositoryProvider.overrideWithValue(flights),
    linkOpenerProvider.overrideWithValue((links ?? _Links()).open),
    if (withCity) departureCityProvider.overrideWith(_ParisChosen.new),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: const Scaffold(body: FlightsScreen(id: _romeId)),
  ),
);

class _ParisChosen extends DepartureCityNotifier {
  @override
  DestinationSummary? build() => rome;
}

FlightResults _results({
  List<Map<String, Object?>>? items,
  String? message,
  String? searchUrl,
  List<String> warnings = const [],
  Map<String, Object?>? origin,
}) => FlightResults.fromJson(
  origin == null
      ? resultsJson(items: items, message: message, searchUrl: searchUrl, warnings: warnings)
      : resultsJson(items: items, message: message, searchUrl: searchUrl, warnings: warnings, origin: origin),
);

void main() {
  testWidgets('without a departure city it asks for one and searches nothing', (tester) async {
    usePhoneSize(tester);
    final flights = FakeFlightRepository();

    await tester.pumpWidget(_host(flights, withCity: false));
    await tester.pumpAndSettle();

    expect(find.text('Flights to Rome'), findsOneWidget);
    expect(find.text('Choose a city'), findsOneWidget);
    expect(find.text('Where are you flying from?'), findsOneWidget);
    expect(flights.queries, isEmpty);
  });

  testWidgets('choosing a city from the picker searches for it', (tester) async {
    usePhoneSize(tester);
    final flights = FakeFlightRepository();

    await tester.pumpWidget(_host(flights, withCity: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a city'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ro');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rome').last);
    await tester.pumpAndSettle();

    expect(flights.queries.single.originId, rome.id);
    expect(flights.queries.single.destinationId, _romeId);
    expect(flights.queries.single.tripType, FlightTripType.roundTrip);
    expect(flights.queries.single.directOnly, isFalse);
    expect(find.byType(FareTile), findsOneWidget);
  });

  testWidgets('a fare shows its details and the price note, but no airline or flight number', (tester) async {
    usePhoneSize(tester);

    await tester.pumpWidget(_host(FakeFlightRepository()));
    await tester.pumpAndSettle();

    expect(find.text('ORY → FCO'), findsOneWidget);
    expect(find.text('Sat 10 Apr · 09:25 · Direct'), findsOneWidget);
    expect(find.text('Wed 14 Apr · 18:10 · Direct'), findsOneWidget);
    expect(find.text('4h 20m flying in total'), findsOneWidget);
    expect(find.textContaining(r'$82'), findsOneWidget);
    expect(find.text(priceNote), findsOneWidget);
    expect(find.textContaining('ITA'), findsNothing);
    expect(find.textContaining('AZ319'), findsNothing);
    expect(find.textContaining('Passport'), findsNothing);
  });

  testWidgets('fares stay in the order the API gave', (tester) async {
    usePhoneSize(tester, height: 2000);
    final flights = FakeFlightRepository(
      results: _results(
        items: [
          fareJson(id: 'a'),
          fareJson(id: 'b', amount: 97),
          fareJson(id: 'c', amount: 118),
        ],
      ),
    );

    await tester.pumpWidget(_host(flights));
    await tester.pumpAndSettle();

    final tiles = tester.widgetList<FareTile>(find.byType(FareTile)).map((t) => t.fare.id);
    expect(tiles, ['a', 'b', 'c']);
  });

  testWidgets('a missing duration leaves no gap, and stops are counted', (tester) async {
    usePhoneSize(tester);
    final flights = FakeFlightRepository(
      results: _results(items: [fareJson(durationMinutes: null, stops: 1, returnStops: 2)]),
    );

    await tester.pumpWidget(_host(flights));
    await tester.pumpAndSettle();

    expect(find.textContaining('flying'), findsNothing);
    expect(find.text('Sat 10 Apr · 09:25 · 1 stop'), findsOneWidget);
    expect(find.text('Wed 14 Apr · 18:10 · 2 stops'), findsOneWidget);
  });

  testWidgets('fares on other dates carry a label, and the message is visible', (tester) async {
    usePhoneSize(tester);
    final flights = FakeFlightRepository(
      results: _results(
        items: [fareJson(dateMatch: 'nearby')],
        message: 'The closest we found.',
      ),
    );

    await tester.pumpWidget(_host(flights));
    await tester.pumpAndSettle();

    expect(find.text('Nearby dates'), findsOneWidget);
    expect(find.text('The closest we found.'), findsOneWidget);
  });

  testWidgets('a city without an airport says which one is used', (tester) async {
    usePhoneSize(tester);
    final flights = FakeFlightRepository(
      results: _results(
        origin: {
          'id': '1',
          'name': 'Byblos',
          'flightCity': 'Beirut',
          'code': 'BEY',
          'isNearby': true,
          'distanceKm': 38,
        },
      ),
    );

    await tester.pumpWidget(_host(flights));
    await tester.pumpAndSettle();

    expect(find.text('Byblos has no airport, so we use Beirut (38 km away).'), findsOneWidget);
  });

  testWidgets('tapping a fare opens its link unchanged', (tester) async {
    usePhoneSize(tester);
    final links = _Links();

    await tester.pumpWidget(_host(FakeFlightRepository(), links: links));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FareTile));
    await tester.pump();

    expect(links.opened, ['https://www.aviasales.com/search/1?marker=1']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a link that will not open says so, and the screen stays', (tester) async {
    usePhoneSize(tester);
    final links = _Links()..works = false;

    await tester.pumpWidget(_host(FakeFlightRepository(), links: links));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FareTile));
    await tester.pump();
    await tester.pump();

    expect(find.text('Could not open the booking site.'), findsOneWidget);
    expect(find.byType(FareTile), findsOneWidget);
  });

  testWidgets('no fares shows the message and opens the search link', (tester) async {
    usePhoneSize(tester);
    final links = _Links();
    final flights = FakeFlightRepository(
      results: _results(items: [], message: 'No recent fares.', searchUrl: 'https://book/search'),
    );

    await tester.pumpWidget(_host(flights, links: links));
    await tester.pumpAndSettle();

    expect(find.text('No recent prices for this trip'), findsOneWidget);
    expect(find.text('No recent fares.'), findsOneWidget);
    expect(find.text(priceNote), findsNothing);

    await tester.tap(find.text('Search live prices'));
    await tester.pump();
    expect(links.opened, ['https://book/search']);
  });

  testWidgets('a source that is down shows its warning, and the search controls still work', (tester) async {
    usePhoneSize(tester);
    final flights = FakeFlightRepository(
      results: _results(items: [], warnings: ['Flights is unavailable right now.']),
    );

    await tester.pumpWidget(_host(flights));
    await tester.pumpAndSettle();

    expect(find.text('Flights is unavailable right now.'), findsOneWidget);
    expect(find.text('No recent prices for this trip'), findsNothing);
    expect(find.text('Round trip'), findsOneWidget);
  });

  testWidgets('while loading it keeps the layout with placeholder boxes', (tester) async {
    usePhoneSize(tester);
    final gate = Completer<void>();

    await tester.pumpWidget(_host(FakeFlightRepository()..gate = gate));
    await tester.pump();

    expect(find.byType(FareTilePlaceholders), findsOneWidget);
    expect(find.text('Flying from'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(FareTile), findsOneWidget);
  });

  testWidgets('a failure shows at once with placeholders, and Try again searches again', (tester) async {
    usePhoneSize(tester);
    final flights = FakeFlightRepository(error: DioException(requestOptions: RequestOptions()));

    await tester.pumpWidget(_host(flights));
    await tester.pump();
    await tester.pump();

    expect(find.byType(ErrorRetry), findsOneWidget);
    expect(find.byType(FareTilePlaceholders), findsOneWidget);
    expect(flights.queries, hasLength(1));

    flights.error = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(flights.queries, hasLength(2));
    expect(find.byType(FareTile), findsOneWidget);
    expect(find.byType(ErrorRetry), findsNothing);
  });

  testWidgets('the same flight city asks for a different one, without Try again', (tester) async {
    usePhoneSize(tester);
    final options = RequestOptions();
    final flights = FakeFlightRepository(
      error: DioException(
        requestOptions: options,
        response: Response<Object?>(
          requestOptions: options,
          statusCode: 400,
          data: <String, dynamic>{
            'errors': <String, dynamic>{
              'origin': ['Same city.'],
            },
          },
        ),
      ),
    );

    await tester.pumpWidget(_host(flights));
    await tester.pumpAndSettle();

    expect(find.text('This city uses the same airports as your destination. Choose a different one.'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Flying from'), findsOneWidget);
  });

  testWidgets('one way and direct only change the next search', (tester) async {
    usePhoneSize(tester);
    final flights = FakeFlightRepository();

    await tester.pumpWidget(_host(flights));
    await tester.pumpAndSettle();
    expect(flights.queries.last.tripType, FlightTripType.roundTrip);

    flights.results = _results(items: [fareJson(returnAt: null, returnStops: null)]);
    await tester.tap(find.text('One way'));
    await tester.pumpAndSettle();
    expect(flights.queries.last.tripType, FlightTripType.oneWay);
    expect(find.textContaining('one way'), findsOneWidget);
    expect(find.textContaining('Wed 14 Apr'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(flights.queries.last.directOnly, isTrue);
  });

  testWidgets('wide screens put the search beside the fares', (tester) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(FakeFlightRepository()));
    await tester.pumpAndSettle();

    final field = tester.getTopLeft(find.text('Flying from'));
    final fare = tester.getTopLeft(find.byType(FareTile));
    expect(fare.dx, greaterThan(field.dx + 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone screen has no overflow', (tester) async {
    usePhoneSize(tester, height: 844);

    await tester.pumpWidget(_host(FakeFlightRepository()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
