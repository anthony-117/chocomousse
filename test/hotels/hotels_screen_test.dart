import 'dart:async';

import 'package:chocomousse/app/theme/app_theme.dart';
import 'package:chocomousse/core/links/link_opener.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/hotels/data/hotel_models.dart';
import 'package:chocomousse/features/hotels/data/hotel_repository.dart';
import 'package:chocomousse/features/hotels/presentation/hotel_details_screen.dart';
import 'package:chocomousse/features/hotels/presentation/hotels_screen.dart';
import 'package:chocomousse/features/hotels/presentation/widgets/hotel_card.dart';
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

Widget _host(FakeHotelRepository hotels, {_Links? links, String start = '/discover/destination/3169070/hotels'}) {
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: '/discover/destination/:id/hotels',
        builder: (context, state) => Scaffold(body: HotelsScreen(id: state.pathParameters['id']!)),
        routes: [
          GoRoute(
            path: ':hotelId',
            builder: (context, state) => Scaffold(body: HotelDetailsScreen(hotelId: state.pathParameters['hotelId']!)),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    retry: noRetry,
    overrides: [
      destinationRepositoryProvider.overrideWithValue(FakeDestinationRepository()),
      hotelRepositoryProvider.overrideWithValue(hotels),
      linkOpenerProvider.overrideWithValue((links ?? _Links()).open),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

HotelResults _results({
  List<Map<String, Object?>>? items,
  String? sourceName,
  int page = 1,
  int totalPages = 3,
  bool isSavedPrice = false,
  int? filtersCheckedOn,
  String? message,
  String? searchUrl,
  List<String> warnings = const [],
}) => HotelResults.fromJson(
  hotelResultsJson(
    items: items,
    sourceName: sourceName,
    page: page,
    totalPages: totalPages,
    isSavedPrice: isSavedPrice,
    filtersCheckedOn: filtersCheckedOn,
    message: message,
    searchUrl: searchUrl,
    warnings: warnings,
  ),
);

DioException _status(int code, [Object? data]) => DioException(
  requestOptions: RequestOptions(),
  type: DioExceptionType.badResponse,
  response: Response(requestOptions: RequestOptions(), statusCode: code, data: data),
);

void main() {
  group('list', () {
    testWidgets('searches at once for the trip, two adults and the first page', (tester) async {
      usePhoneSize(tester);
      final hotels = FakeHotelRepository();

      await tester.pumpWidget(_host(hotels));
      await tester.pumpAndSettle();

      expect(find.text('Hotels in Rome'), findsOneWidget);
      expect(find.text('2 adults · 1 room'), findsOneWidget);
      expect(find.textContaining('Passport'), findsNothing);
      final query = hotels.queries.single;
      expect((query.destinationId, query.adults, query.currency, query.page), ('3169070', 2, 'USD', 1));
      expect(query.filters, const HotelFilters());
    });

    testWidgets('a card shows every field it has, in the order returned', (tester) async {
      usePhoneSize(tester, height: 2400);
      final hotels = FakeHotelRepository(
        results: _results(
          items: [
            hotelJson(),
            hotelJson(id: 'bk:2', name: 'Casa Monti', stars: null, freeCancellation: null, total: 644, perNight: 161),
          ],
        ),
      );

      await tester.pumpWidget(_host(hotels));
      await tester.pumpAndSettle();

      final names = tester.widgetList<HotelCard>(find.byType(HotelCard)).map((c) => c.hotel.name);
      expect(names, ['Hotel Artemide', 'Casa Monti']);
      expect(find.byWidgetPredicate((w) => w is HotelStars && w.count == 4), findsOneWidget);
      expect(find.text('8.9'), findsNWidgets(2));
      expect(find.text('3,214 reviews'), findsNWidgets(2));
      expect(find.text('1.1 km from centre'), findsNWidgets(2));
      expect(find.text('Free cancellation'), findsOneWidget);
      expect(find.textContaining(r'$812'), findsOneWidget);
      expect(find.text(r'4 nights · $203 a night'), findsOneWidget);
      expect(find.text(r'4 nights · $161 a night'), findsOneWidget);
      expect(find.textContaining('Prices from Booking.com, checked'), findsOneWidget);
    });

    testWidgets('missing stars and reviews are hidden, never 0', (tester) async {
      usePhoneSize(tester);
      final hotels = FakeHotelRepository(
        results: _results(items: [hotelJson(stars: null, reviewScore: null, reviewCount: null)]),
      );

      await tester.pumpWidget(_host(hotels));
      await tester.pumpAndSettle();

      expect(find.byType(HotelStars), findsNothing);
      expect(find.byType(ReviewScore), findsNothing);
      expect(find.textContaining('reviews'), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('a far hotel is marked, and the searched city is named', (tester) async {
      usePhoneSize(tester);
      final hotels = FakeHotelRepository(
        results: _results(items: [hotelJson(nearCity: true, distanceKm: 14.3)], sourceName: 'Roma'),
      );

      await tester.pumpWidget(_host(hotels));
      await tester.pumpAndSettle();

      expect(find.text('14 km from Rome'), findsOneWidget);
      expect(find.text('Booking.com searched Roma for Rome.'), findsOneWidget);
    });

    testWidgets('saved prices show the warning and say they were saved', (tester) async {
      usePhoneSize(tester);
      const warning = 'Hotel prices could not be refreshed; showing prices from 2027-03-01 09:40 UTC.';
      final hotels = FakeHotelRepository(results: _results(isSavedPrice: true, warnings: [warning]));

      await tester.pumpWidget(_host(hotels));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(HotelWarning, warning), findsOneWidget);
      expect(find.textContaining('Prices from Booking.com, saved'), findsOneWidget);
      expect(find.byType(HotelCard), findsOneWidget);
    });

    testWidgets('no hotels: the message and the Booking.com search', (tester) async {
      usePhoneSize(tester);
      final links = _Links();
      const url = 'https://www.booking.com/searchresults.html?ss=Rome';
      final hotels = FakeHotelRepository(
        results: _results(items: [], totalPages: 1, message: 'No hotels are available.', searchUrl: url),
      );

      await tester.pumpWidget(_host(hotels, links: links));
      await tester.pumpAndSettle();

      expect(find.text('No hotels for these dates'), findsOneWidget);
      expect(find.text('No hotels are available.'), findsOneWidget);
      expect(find.text('Clear filters'), findsNothing);
      expect(find.textContaining('Prices from'), findsNothing);
      await tester.tap(find.text('Search on Booking.com'));
      await tester.pump();
      expect(links.opened, [url]);
    });

    testWidgets('loading shows placeholder cards, then the hotels', (tester) async {
      usePhoneSize(tester);
      final hotels = FakeHotelRepository()..gate = Completer<void>();

      await tester.pumpWidget(_host(hotels));
      await tester.pump();
      expect(find.byType(HotelCardPlaceholders), findsOneWidget);
      expect(find.text('Hotels in Rome'), findsOneWidget);

      hotels.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(HotelCard), findsOneWidget);
    });

    testWidgets('an unreachable server shows the error at once, and Try again searches again', (tester) async {
      usePhoneSize(tester);
      final hotels = FakeHotelRepository(
        error: DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError),
      );

      await tester.pumpWidget(_host(hotels));
      await tester.pumpAndSettle();
      expect(find.text('Cannot reach the TravelGenie server.'), findsOneWidget);
      expect(find.byType(HotelCardPlaceholders), findsOneWidget);
      expect(hotels.queries, hasLength(1));

      hotels.error = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(HotelCard), findsOneWidget);
      expect(hotels.queries, hasLength(2));
    });

    testWidgets("a refused search shows the API's reason", (tester) async {
      usePhoneSize(tester);
      final hotels = FakeHotelRepository(
        error: _status(400, {
          'errors': {
            'adults': ['Adults must be between 1 and 8.'],
          },
        }),
      );

      await tester.pumpWidget(_host(hotels));
      await tester.pumpAndSettle();

      expect(find.text('Adults must be between 1 and 8.'), findsOneWidget);
    });

    testWidgets('changing adults searches again from page 1', (tester) async {
      usePhoneSize(tester, height: 2400);
      final hotels = FakeHotelRepository();

      await tester.pumpWidget(_host(hotels));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(hotels.queries.last.page, 2);

      await tester.tap(find.text('2 adults · 1 room'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More adults'));
      await tester.pumpAndSettle();

      expect((hotels.queries.last.adults, hotels.queries.last.page), (3, 1));
    });
  });

  group('paging', () {
    testWidgets('Previous is off on the first page, Next on the last', (tester) async {
      usePhoneSize(tester, height: 2400);
      final hotels = FakeHotelRepository();

      await tester.pumpWidget(_host(hotels));
      await tester.pumpAndSettle();

      expect(find.text('Page 1 of 3'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Previous')).onPressed, isNull);

      hotels.results = _results(page: 3);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(hotels.queries.last.page, 2);
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Next')).onPressed, isNull);
    });

    testWidgets('a single page shows no pager', (tester) async {
      usePhoneSize(tester);

      await tester.pumpWidget(_host(FakeHotelRepository(results: _results(totalPages: 1))));
      await tester.pumpAndSettle();

      expect(find.textContaining('Page '), findsNothing);
    });
  });

  group('sort and filters', () {
    testWidgets('sorting searches again from page 1', (tester) async {
      usePhoneSize(tester, height: 2400);
      final hotels = FakeHotelRepository();

      await tester.pumpWidget(_host(hotels));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Sort hotels'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lowest price').last);
      await tester.pumpAndSettle();

      expect((hotels.queries.last.filters.sort, hotels.queries.last.page), (HotelSort.price, 1));
    });

    testWidgets('filters are sent only on Show hotels, and counted on the button', (tester) async {
      usePhoneSize(tester, height: 1000);
      final hotels = FakeHotelRepository();

      await tester.pumpWidget(_host(hotels));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('4+'));
      await tester.tap(find.text('8+'));
      await tester.enterText(find.widgetWithText(TextField, 'Max'), '900');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Apartments'), 100, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Apartments'));
      await tester.tap(find.text('Free cancellation only'));
      await tester.pumpAndSettle();
      expect(hotels.queries, hasLength(1));

      await tester.scrollUntilVisible(find.text('Show hotels'), 100, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Show hotels'));
      await tester.pumpAndSettle();

      final filters = hotels.queries.last.filters;
      expect((filters.minStars, filters.minReview, filters.maxPrice), (4, 8, 900));
      expect(filters.stayTypes, ['Apartments']);
      expect(filters.freeCancellation, isTrue);
      expect(find.text('Filters · 5'), findsOneWidget);
    });

    testWidgets('a minimum above the maximum is refused', (tester) async {
      usePhoneSize(tester, height: 1000);
      final hotels = FakeHotelRepository();

      await tester.pumpWidget(_host(hotels));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Min'), '500');
      await tester.enterText(find.widgetWithText(TextField, 'Max'), '100');
      await tester.pumpAndSettle();

      expect(find.text('The minimum price is above the maximum.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Show hotels'), 100, scrollable: find.byType(Scrollable).last);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Show hotels')).onPressed, isNull);
    });

    testWidgets('no match: Clear filters, and how many hotels could be checked', (tester) async {
      usePhoneSize(tester, height: 1000);
      final hotels = FakeHotelRepository();

      await tester.pumpWidget(_host(hotels));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Free cancellation only'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Free cancellation only'));
      hotels.results = _results(
        items: [],
        filtersCheckedOn: 14,
        message: 'No hotels match these filters.',
        searchUrl: 'https://www.booking.com/x',
      );
      await tester.scrollUntilVisible(find.text('Show hotels'), 100, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Show hotels'));
      await tester.pumpAndSettle();

      expect(find.text('No hotels match these filters'), findsOneWidget);
      expect(find.textContaining('known for 14 of the hotels found'), findsOneWidget);
      expect(find.text('Page 1 of 3'), findsOneWidget); // later pages may still match

      hotels.results = _results();
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(hotels.queries.last.filters, const HotelFilters());
      expect(find.byType(HotelCard), findsOneWidget);
    });

    testWidgets('wide screens keep the filters in a side panel and hotels in two columns', (tester) async {
      tester.view
        ..physicalSize = const Size(1440, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final hotels = FakeHotelRepository(
        results: _results(
          items: [
            hotelJson(),
            hotelJson(id: 'bk:2', name: 'Casa Monti'),
          ],
        ),
      );

      await tester.pumpWidget(_host(hotels));
      await tester.pumpAndSettle();

      expect(find.text('Filters'), findsNothing);
      expect(find.text('Show hotels'), findsOneWidget);
      final cards = find.byType(HotelCard);
      expect(tester.getTopLeft(cards.at(0)).dy, tester.getTopLeft(cards.at(1)).dy);

      await tester.tap(find.text('5'));
      await tester.tap(find.text('Show hotels'));
      await tester.pumpAndSettle();
      expect(hotels.queries.last.filters.minStars, 5);
    });
  });

  group('details', () {
    testWidgets('tapping a hotel opens its details for the same stay', (tester) async {
      usePhoneSize(tester, height: 2400);
      final hotels = FakeHotelRepository();

      await tester.pumpWidget(_host(hotels));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(HotelCard));
      await tester.pumpAndSettle();

      final query = hotels.detailQueries.single;
      expect((query.hotelId, query.adults, query.currency), ('bk:1', 2, 'USD'));
      expect((query.from, query.to), (hotels.queries.single.from, hotels.queries.single.to));
      expect(find.byType(HotelDetailsScreen), findsOneWidget);
    });

    testWidgets('shows every detail it has, and books on Booking.com unchanged', (tester) async {
      usePhoneSize(tester, height: 2000);
      final links = _Links();
      final hotels = FakeHotelRepository();

      await tester.pumpWidget(_host(hotels, links: links, start: '/discover/destination/3169070/hotels/bk:1'));
      await tester.pumpAndSettle();

      expect(find.text('Hotel Artemide'), findsOneWidget);
      expect(find.text('Fabulous · 3,214 reviews'), findsOneWidget);
      expect(find.text('Via Nazionale 22, 00184 Rome · 1.1 km from centre'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      for (final text in ['Hotels', 'Free cancellation', 'Breakfast included', 'From 14:00', 'Until 12:00']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('Free WiFi'), findsOneWidget);
      expect(find.text('English, Italian, xx'), findsOneWidget);
      expect(find.textContaining(r'$812'), findsOneWidget);
      expect(find.textContaining('2 adults · 1 room'), findsOneWidget);

      await tester.tap(find.text('Book on Booking.com'));
      await tester.pump();
      expect(links.opened, ['https://www.booking.com/hotel/it/artemide.html?checkin=2027-04-10']);
    });

    testWidgets('without a price for these dates it points to Booking.com, and hides unknown times', (tester) async {
      usePhoneSize(tester, height: 2000);
      final hotels = FakeHotelRepository(
        hotel: HotelDetails.fromJson(hotelDetailsJson(price: null, checkInFrom: null, breakfastIncluded: null)),
      );

      await tester.pumpWidget(_host(hotels, start: '/discover/destination/3169070/hotels/bk:1'));
      await tester.pumpAndSettle();

      expect(find.text('See the price on Booking.com'), findsOneWidget);
      expect(find.text('Book on Booking.com'), findsOneWidget);
      expect(find.text('Check-in'), findsNothing);
      expect(find.text('Until 12:00'), findsOneWidget);
      expect(find.text('Breakfast included'), findsNothing);
    });

    testWidgets('a link that will not open says so and stays', (tester) async {
      usePhoneSize(tester, height: 2000);
      final links = _Links()..works = false;

      await tester.pumpWidget(
        _host(FakeHotelRepository(), links: links, start: '/discover/destination/3169070/hotels/bk:1'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Book on Booking.com'));
      await tester.pumpAndSettle();

      expect(find.text('Could not open Booking.com.'), findsOneWidget);
      expect(find.text('Hotel Artemide'), findsOneWidget);
    });

    testWidgets('an unknown hotel says it cannot be found', (tester) async {
      usePhoneSize(tester);

      await tester.pumpWidget(
        _host(FakeHotelRepository(error: _status(404)), start: '/discover/destination/3169070/hotels/bk:9'),
      );
      await tester.pumpAndSettle();

      expect(find.text("This hotel can't be found"), findsOneWidget);
    });

    testWidgets('a failure keeps the layout with Try again', (tester) async {
      usePhoneSize(tester);
      final hotels = FakeHotelRepository(error: _status(503));

      await tester.pumpWidget(_host(hotels, start: '/discover/destination/3169070/hotels/bk:1'));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);

      hotels.error = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Hotel Artemide'), findsOneWidget);
    });
  });

  test('checked times read as today or the day', () {
    final now = DateTime(2027, 3, 1, 12);
    expect(describeCheckedAt(DateTime(2027, 3, 1, 9, 40), now: now), 'today at 09:40');
    expect(describeCheckedAt(DateTime(2027, 2, 27, 18, 5), now: now), '27 Feb at 18:05');
  });
}
