import 'dart:async';

import 'package:chocomousse/app/theme/app_theme.dart';
import 'package:chocomousse/core/links/link_opener.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:chocomousse/features/cars/data/car_repository.dart';
import 'package:chocomousse/features/cars/presentation/car_details_screen.dart';
import 'package:chocomousse/features/cars/presentation/cars_screen.dart';
import 'package:chocomousse/features/cars/presentation/widgets/car_card.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../destination/fakes.dart';
import '../helpers.dart';
import 'fakes.dart';

/// Opens links in a list, and fails when told to.
class _Links {
  final opened = <String>[];
  bool works = true;

  Future<bool> open(String url) async {
    opened.add(url);
    return works;
  }
}

const _list = '/discover/destination/3169070/cars';

Widget _host(FakeCarRepository cars, {_Links? links, String start = _list}) {
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: '/discover/destination/:id/cars',
        builder: (context, state) => Scaffold(body: CarsScreen(id: state.pathParameters['id']!)),
        routes: [
          GoRoute(
            path: ':carId',
            redirect: (context, state) =>
                state.extra is CarDetailsArgs ? null : '/discover/destination/${state.pathParameters['id']}/cars',
            builder: (context, state) => Scaffold(body: CarDetailsScreen(args: state.extra! as CarDetailsArgs)),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    retry: noRetry,
    overrides: [
      destinationRepositoryProvider.overrideWithValue(FakeDestinationRepository()),
      carRepositoryProvider.overrideWithValue(cars),
      linkOpenerProvider.overrideWithValue((links ?? _Links()).open),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

CarResults _results({
  List<Map<String, Object?>>? items,
  int page = 1,
  int totalPages = 3,
  bool isSavedPrice = false,
  bool mayHaveMore = false,
  String? driverNote,
  String? message,
  String? searchUrl = carSearchUrl,
  List<String> warnings = const [],
}) => CarResults.fromJson(
  carResultsJson(
    items: items,
    page: page,
    totalPages: totalPages,
    isSavedPrice: isSavedPrice,
    mayHaveMore: mayHaveMore,
    driverNote: driverNote,
    message: message,
    searchUrl: searchUrl,
    warnings: warnings,
  ),
);

Finder _sheetScroll() => find.byType(Scrollable).last;

void main() {
  group('list', () {
    testWidgets('searches at once from the city centre, for the trip and a driver of 30', (tester) async {
      usePhoneSize(tester);
      final cars = FakeCarRepository();

      await tester.pumpWidget(_host(cars));
      await tester.pumpAndSettle();

      expect(find.text('Cars in Rome'), findsOneWidget);
      expect(find.text('City centre'), findsOneWidget);
      expect(find.text('Driver 30'), findsOneWidget);
      expect(find.textContaining('Passport'), findsNothing);
      expect(find.textContaining('adults'), findsNothing);
      final query = cars.queries.single;
      expect(
        (query.destinationId, query.place, query.driverAge, query.currency, query.page),
        ('3169070', 'centre', 30, 'USD', 1),
      );
      expect(query.filters, const CarFilters());
      expect(cars.placeRequests, 0); // airports load only when the pick-up sheet opens
    });

    testWidgets('a card shows the car, company, pick-up and price as designed', (tester) async {
      usePhoneSize(tester, height: 2000);
      final cars = FakeCarRepository(
        results: _results(
          items: [
            carJson(),
            carJson(id: 'bk:car:2', model: 'Jeep Avenger', sponsored: true, payNow: false, freeCancellation: null),
          ],
        ),
      );

      await tester.pumpWidget(_host(cars));
      await tester.pumpAndSettle();

      expect(find.text('Fiat 600 or similar'), findsOneWidget);
      expect(find.text('Intermediate · Automatic · 5 seats · 3 bags · A/C'), findsNWidgets(2));
      expect(find.text('Budget · 372 reviews'), findsNWidgets(2));
      expect(find.text('via Sardegna · Downtown · 0.9 km from centre'), findsNWidgets(2));
      expect(find.text('Free cancellation'), findsOneWidget);
      expect(find.text(r'$77  total'), findsNWidgets(2));
      expect(find.textContaining(r'4 days · $19 a day · pay now'), findsOneWidget);
      expect(find.textContaining('pay at pick-up'), findsOneWidget);
      expect(find.text('Ad'), findsOneWidget);
      expect(find.textContaining('for pick-up and return at 10:00'), findsOneWidget);
    });

    testWidgets('while searching it says it takes up to 30 seconds, then shows the cars', (tester) async {
      usePhoneSize(tester);
      final cars = FakeCarRepository()..gate = Completer<void>();

      await tester.pumpWidget(_host(cars));
      await tester.pump();
      expect(find.byType(CarSearching), findsOneWidget);
      expect(find.textContaining('up to 30 seconds'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      cars.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CarCard), findsOneWidget);
      expect(find.byType(CarSearching), findsNothing);
    });

    testWidgets('an unreachable server shows the error, and Try again searches again', (tester) async {
      usePhoneSize(tester);
      final cars = FakeCarRepository(
        error: DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError),
      );

      await tester.pumpWidget(_host(cars));
      await tester.pumpAndSettle();
      expect(find.text('Cannot reach the TravelGenie server.'), findsOneWidget);
      expect(find.byType(CarCardPlaceholders), findsOneWidget);

      cars.error = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(CarCard), findsOneWidget);
      expect(cars.queries, hasLength(2));
    });

    testWidgets("a refused search shows the API's reason", (tester) async {
      usePhoneSize(tester);
      final cars = FakeCarRepository(
        error: DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(),
            statusCode: 400,
            data: {
              'errors': {
                'driverAge': ['The driver must be between 18 and 99.'],
              },
            },
          ),
        ),
      );

      await tester.pumpWidget(_host(cars));
      await tester.pumpAndSettle();

      expect(find.text('The driver must be between 18 and 99.'), findsOneWidget);
    });

    testWidgets('warnings, the driver note and saved prices are shown', (tester) async {
      usePhoneSize(tester, height: 2000);
      final cars = FakeCarRepository(
        results: _results(
          isSavedPrice: true,
          driverNote: 'Drivers under 25 may pay a young driver fee.',
          warnings: ['Booking.com could not be reached. These prices were saved earlier.'],
        ),
      );

      await tester.pumpWidget(_host(cars));
      await tester.pumpAndSettle();

      expect(find.text('Drivers under 25 may pay a young driver fee.'), findsOneWidget);
      expect(find.textContaining('could not be reached'), findsOneWidget);
      expect(find.textContaining('Prices from Booking.com, saved'), findsOneWidget);
    });

    testWidgets('when Booking.com may have more cars, See all opens its search', (tester) async {
      usePhoneSize(tester, height: 2000);
      final links = _Links();
      final cars = FakeCarRepository(results: _results(mayHaveMore: true, totalPages: 1));

      await tester.pumpWidget(_host(cars, links: links));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See all'));
      await tester.pump();

      expect(find.text('Booking.com has more cars than shown here.'), findsOneWidget);
      expect(links.opened, [carSearchUrl]);
    });

    testWidgets('no cars: the message and the Booking.com search', (tester) async {
      usePhoneSize(tester);
      final links = _Links();
      final cars = FakeCarRepository(
        results: _results(items: [], totalPages: 0, message: 'Booking.com has no cars here for these dates.'),
      );

      await tester.pumpWidget(_host(cars, links: links));
      await tester.pumpAndSettle();

      expect(find.text('No rental cars here for these dates'), findsOneWidget);
      expect(find.text('Booking.com has no cars here for these dates.'), findsOneWidget);
      expect(find.text('Clear filters'), findsNothing);
      await tester.tap(find.text('Search on Booking.com'));
      await tester.pump();
      expect(links.opened, [carSearchUrl]);
    });

    testWidgets('when Booking.com fails with nothing saved, it says so and Try again searches again', (tester) async {
      usePhoneSize(tester);
      final cars = FakeCarRepository(
        results: CarResults.fromJson(
          carResultsJson(
            items: [],
            totalPages: 0,
            sizes: [],
            companies: [],
            pickUpTypes: [],
            message: 'No rental cars are available here for these dates.',
            warnings: ['Car prices could not be refreshed. No saved cars for this search yet.'],
          ),
        ),
      );

      await tester.pumpWidget(_host(cars));
      await tester.pumpAndSettle();

      expect(find.text('Cars could not be searched'), findsOneWidget);
      expect(find.text('No rental cars here for these dates'), findsNothing);
      expect(find.text('No rental cars are available here for these dates.'), findsNothing);
      expect(find.text('Search on Booking.com'), findsOneWidget);

      cars.results = _results();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(cars.queries, hasLength(2));
      expect(find.byType(CarCard), findsOneWidget);
    });

    testWidgets('Next asks for the next page, and sorting goes back to page 1', (tester) async {
      usePhoneSize(tester, height: 2400);
      final cars = FakeCarRepository();

      await tester.pumpWidget(_host(cars));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(cars.queries.last.page, 2);

      await tester.tap(find.byTooltip('Sort cars'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lowest price').last);
      await tester.pumpAndSettle();
      expect((cars.queries.last.filters.sort, cars.queries.last.page), (CarSort.price, 1));
    });

    testWidgets('filters use the search values, are sent only on Show cars, and are counted', (tester) async {
      usePhoneSize(tester, height: 1000);
      final cars = FakeCarRepository();

      await tester.pumpWidget(_host(cars));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Small'));
      await tester.tap(find.text('Automatic'));
      await tester.tap(find.text('5+'));
      await tester.enterText(find.widgetWithText(TextField, 'Max'), '400');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Train station'), 100, scrollable: _sheetScroll());
      await tester.tap(find.text('Train station'));
      await tester.scrollUntilVisible(find.text('Hertz'), 100, scrollable: _sheetScroll());
      await tester.tap(find.text('Hertz'));
      await tester.scrollUntilVisible(find.text('Free cancellation only'), 100, scrollable: _sheetScroll());
      await tester.tap(find.text('Free cancellation only'));
      await tester.pumpAndSettle();
      expect(cars.queries, hasLength(1));
      expect(find.textContaining('Filters cover all 415 cars'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Show cars'), 100, scrollable: _sheetScroll());
      await tester.tap(find.text('Show cars'));
      await tester.pumpAndSettle();

      final filters = cars.queries.last.filters;
      expect(
        (filters.gearbox, filters.minSeats, filters.maxPrice, filters.freeCancellation),
        (Gearbox.automatic, 5, 400, true),
      );
      expect(filters.sizes, ['Small']);
      expect(filters.pickUpTypes, [PickUpType.trainStation]);
      expect(filters.companies, ['Hertz']);
      expect(find.text('Filters · 7'), findsOneWidget);
    });

    testWidgets('a maximum of 0 is refused', (tester) async {
      usePhoneSize(tester, height: 1000);
      final cars = FakeCarRepository();

      await tester.pumpWidget(_host(cars));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Max'), '0');
      await tester.pumpAndSettle();

      expect(find.text('The maximum must be more than 0.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Show cars'), 100, scrollable: _sheetScroll());
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Show cars')).onPressed, isNull);
    });

    testWidgets('no match: Clear filters keeps the sort and shows the cars again', (tester) async {
      usePhoneSize(tester, height: 1000);
      final cars = FakeCarRepository();

      await tester.pumpWidget(_host(cars));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lowest price'));
      await tester.tap(find.text('Manual'));
      cars.results = _results(items: [], totalPages: 0, message: 'No cars match these filters.');
      await tester.scrollUntilVisible(find.text('Show cars'), 100, scrollable: _sheetScroll());
      await tester.tap(find.text('Show cars'));
      await tester.pumpAndSettle();

      expect(find.text('No cars match these filters'), findsOneWidget);
      expect(find.text('Search on Booking.com'), findsOneWidget);

      cars.results = _results();
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(cars.queries.last.filters, const CarFilters(sort: CarSort.price));
      expect(find.byType(CarCard), findsOneWidget);
    });

    testWidgets('the pick-up sheet offers airports, and its choice searches again with the new driver', (tester) async {
      usePhoneSize(tester, height: 1000);
      final cars = FakeCarRepository();

      await tester.pumpWidget(_host(cars));
      await tester.pumpAndSettle();
      await tester.tap(find.text('City centre'));
      await tester.pumpAndSettle();

      expect(find.text('Pick-up and driver'), findsOneWidget);
      expect(find.text('Fiumicino Airport · FCO'), findsOneWidget);
      expect(find.text('Ciampino Airport · CIA'), findsOneWidget);
      await tester.tap(find.text('Fiumicino Airport · FCO'));
      await tester.enterText(find.widgetWithText(TextField, 'Age (18–99)'), '23');
      await tester.pumpAndSettle();
      expect(find.textContaining('young driver fee'), findsOneWidget);

      await tester.tap(find.text('Show cars'));
      await tester.pumpAndSettle();

      expect((cars.queries.last.place, cars.queries.last.driverAge, cars.queries.last.page), ('FCO', 23, 1));
      expect(find.text('Fiumicino Airport · FCO'), findsOneWidget);
      expect(find.text('Driver 23'), findsOneWidget);
    });

    testWidgets('an age outside 18 to 99 cannot be applied', (tester) async {
      usePhoneSize(tester, height: 1000);
      final cars = FakeCarRepository();

      await tester.pumpWidget(_host(cars));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Driver 30'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Age (18–99)'), '16');
      await tester.pumpAndSettle();

      expect(find.text('Enter an age from 18 to 99.'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Show cars')).onPressed, isNull);
    });

    testWidgets('when airports fail, the centre is still offered', (tester) async {
      usePhoneSize(tester, height: 1000);
      final cars = FakeCarRepository(
        placesError: DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError),
      );

      await tester.pumpWidget(_host(cars));
      await tester.pumpAndSettle();
      await tester.tap(find.text('City centre'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Airports could not be loaded'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'City centre'), findsOneWidget);
    });

    testWidgets('wide screens keep the filters in a side panel and cars in two columns', (tester) async {
      tester.view
        ..physicalSize = const Size(1440, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cars = FakeCarRepository(
        results: _results(
          items: [
            carJson(),
            carJson(id: 'bk:car:2', model: 'Jeep Avenger'),
          ],
        ),
      );

      await tester.pumpWidget(_host(cars));
      await tester.pumpAndSettle();

      expect(find.text('Filters'), findsNothing);
      expect(find.text('Show cars'), findsOneWidget);
      final cards = find.byType(CarCard);
      expect(tester.getTopLeft(cards.at(0)).dy, tester.getTopLeft(cards.at(1)).dy);

      await tester.ensureVisible(find.text('7+'));
      await tester.tap(find.text('7+'));
      await tester.ensureVisible(find.text('Show cars'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show cars'));
      await tester.pumpAndSettle();
      expect(cars.queries.last.filters.minSeats, 7);
    });
  });

  group('details', () {
    Future<void> openCar(WidgetTester tester, FakeCarRepository cars, {_Links? links}) async {
      usePhoneSize(tester, height: 2400);
      await tester.pumpWidget(_host(cars, links: links));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CarCard));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a car shows it from the search, with no new request', (tester) async {
      final cars = FakeCarRepository();

      await openCar(tester, cars);

      expect(find.byType(CarDetailsScreen), findsOneWidget);
      expect(cars.queries, hasLength(1));
      expect(find.text('Fiat 600 or similar'), findsOneWidget);
      expect(find.text('Via Sardegna 50, 00187 Rome · 0.9 km from centre'), findsOneWidget);
      expect(find.text('Sat 10 Apr, 10:00'), findsOneWidget);
      expect(find.text('Wed 14 Apr, 10:00'), findsOneWidget);
      expect(find.text('3 checked bags'), findsOneWidget);
      expect(find.text('5 doors'), findsOneWidget);
      expect(find.text('Air conditioning'), findsOneWidget);
      expect(find.text('Unlimited km'), findsOneWidget);
      expect(find.textContaining('€300'), findsOneWidget);
      expect(find.textContaining('€1,200'), findsOneWidget);
      expect(find.text('return as you found it'), findsOneWidget);
      expect(find.text('Pay now on Booking.com'), findsOneWidget);
    });

    testWidgets('missing details are left out, never shown as 0', (tester) async {
      final cars = FakeCarRepository(
        results: _results(
          items: [
            carJson(
              doors: null,
              bags: null,
              airCon: null,
              deposit: null,
              damageExcess: null,
              fuelPolicy: null,
              mileage: null,
              unlimitedMileage: null,
              payNow: false,
            ),
          ],
        ),
      );

      await openCar(tester, cars);

      expect(find.textContaining('doors'), findsNothing);
      expect(find.textContaining('checked bag'), findsNothing);
      expect(find.text('Deposit'), findsNothing);
      expect(find.text('Damage excess'), findsNothing);
      expect(find.text('Fuel'), findsNothing);
      expect(find.text('Pay at pick-up'), findsOneWidget);
    });

    testWidgets('Search on Booking.com opens the link unchanged', (tester) async {
      final links = _Links();

      await openCar(tester, FakeCarRepository(), links: links);
      await tester.tap(find.text('Search on Booking.com'));
      await tester.pump();

      expect(links.opened, [carSearchUrl]);
    });

    testWidgets('a link that will not open says so and stays', (tester) async {
      final links = _Links()..works = false;

      await openCar(tester, FakeCarRepository(), links: links);
      await tester.tap(find.text('Search on Booking.com'));
      await tester.pumpAndSettle();

      expect(find.text('Could not open Booking.com.'), findsOneWidget);
      expect(find.byType(CarDetailsScreen), findsOneWidget);
    });

    testWidgets('opened without a search, it goes to the list', (tester) async {
      usePhoneSize(tester);
      final cars = FakeCarRepository();

      await tester.pumpWidget(_host(cars, start: '$_list/bk%3Acar%3A1'));
      await tester.pumpAndSettle();

      expect(find.byType(CarDetailsScreen), findsNothing);
      expect(find.text('Cars in Rome'), findsOneWidget);
    });

    testWidgets('Back returns to the list without searching again', (tester) async {
      final cars = FakeCarRepository();

      await openCar(tester, cars);
      await tester.tap(find.byTooltip('Back').first);
      await tester.pumpAndSettle();

      expect(find.text('Cars in Rome'), findsOneWidget);
      expect(cars.queries, hasLength(1));
    });
  });
}
