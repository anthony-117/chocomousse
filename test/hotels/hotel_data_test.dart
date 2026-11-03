import 'dart:convert';

import 'package:chocomousse/features/hotels/application/hotel_providers.dart';
import 'package:chocomousse/features/hotels/data/hotel_models.dart';
import 'package:chocomousse/features/hotels/data/hotel_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Answers with [body] and records the request.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);

  final Map<String, Object?> body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

HotelQuery _query({HotelFilters filters = const HotelFilters(), int page = 1}) => (
  destinationId: '3169070',
  from: DateTime(2027, 4, 10),
  to: DateTime(2027, 4, 14),
  adults: 3,
  currency: 'EUR',
  filters: filters,
  page: page,
);

void main() {
  group('models', () {
    test('a hotel keeps missing values empty, never 0 or false', () {
      final hotel = HotelOffer.fromJson(
        hotelJson(stars: null, reviewScore: null, reviewCount: null, freeCancellation: null, photoUrl: null),
      );

      expect(
        (hotel.stars, hotel.reviewScore, hotel.reviewCount, hotel.freeCancellation, hotel.photoUrl),
        (null, null, null, null, null),
      );
    });

    test('results read paging, notes and the time in the device zone', () {
      final results = HotelResults.fromJson(
        hotelResultsJson(page: 2, totalPages: 2, sourceName: 'Roma', filtersCheckedOn: 14),
      );

      expect((results.page, results.totalPages, results.hasNextPage, results.nights), (2, 2, false, 4));
      expect((results.sourceName, results.filtersCheckedOn), ('Roma', 14));
      expect(results.pricesFetchedAt, DateTime.utc(2027, 3, 1, 9, 40).toLocal());
      expect(results.items.single.price.total, 812.4);
    });

    test('a hotel without a price or id is a broken answer', () {
      expect(() => HotelOffer.fromJson(hotelJson()..remove('price')), throwsA(isA<TypeError>()));
      expect(() => HotelOffer.fromJson(hotelJson()..remove('id')), throwsA(isA<TypeError>()));
      expect(() => HotelResults.fromJson(hotelResultsJson(pricesFetchedAt: 'soon')), throwsFormatException);
    });

    test('details allow a missing price but need a booking link', () {
      final details = HotelDetails.fromJson(hotelDetailsJson(price: null));

      expect(details.price, isNull);
      expect(details.reviewWord, 'Fabulous');
      expect(() => HotelDetails.fromJson(hotelDetailsJson()..remove('bookingUrl')), throwsA(isA<TypeError>()));
    });

    test('filters count what is on and compare by value', () {
      const none = HotelFilters();
      final some = none.copyWith(minStars: () => 4, minPrice: () => 100, maxPrice: () => 900, stayTypes: ['Hotels']);

      expect((none.activeCount, some.activeCount), (0, 3));
      expect((none.needsDetails, some.needsDetails), (false, true));
      expect(some, none.copyWith(minStars: () => 4, minPrice: () => 100, maxPrice: () => 900, stayTypes: ['Hotels']));
      expect(some.copyWith(minStars: () => null).minStars, isNull);
      expect(some.cleared(), none);
      expect(none.copyWith(minPrice: () => 900, maxPrice: () => 100).priceRangeIsValid, isFalse);
    });
  });

  group('repository', () {
    test('a search sends the stay, sort, filters and page', () async {
      final adapter = _Adapter(hotelResultsJson());
      final repository = HotelRepository(Dio()..httpClientAdapter = adapter);
      final filters = const HotelFilters(
        sort: HotelSort.price,
      ).copyWith(minReview: () => 8, maxPrice: () => 900, stayTypes: ['Hotels', 'Apartments'], freeCancellation: true);

      await repository.search(_query(filters: filters, page: 2));

      expect(adapter.last!.path, '/destinations/3169070/hotels');
      expect(adapter.last!.queryParameters, {
        'from': '2027-04-10',
        'to': '2027-04-14',
        'adults': 3,
        'currency': 'EUR',
        'sort': 'price',
        'minReview': 8,
        'maxPrice': 900,
        'stayType': ['Hotels', 'Apartments'],
        'freeCancellation': true,
        'page': 2,
      });
      expect(adapter.last!.uri.query, contains('stayType=Hotels&stayType=Apartments'));
    });

    test('the default search sends no filter', () async {
      final adapter = _Adapter(hotelResultsJson());

      await HotelRepository(Dio()..httpClientAdapter = adapter).search(_query());

      expect(adapter.last!.queryParameters.keys, ['from', 'to', 'adults', 'currency', 'sort', 'page']);
    });

    test('details are asked for the same stay', () async {
      final adapter = _Adapter(hotelDetailsJson());

      final details = await HotelRepository(
        Dio()..httpClientAdapter = adapter,
      ).details((hotelId: 'bk:1', from: DateTime(2027, 4, 10), to: DateTime(2027, 4, 14), adults: 2, currency: 'USD'));

      expect(adapter.last!.path, '/hotels/bk%3A1');
      expect(adapter.last!.queryParameters, {'from': '2027-04-10', 'to': '2027-04-14', 'adults': 2, 'currency': 'USD'});
      expect(details.name, 'Hotel Artemide');
    });
  });

  group('providers', () {
    test('equal searches share one request, and another page makes another', () async {
      final hotels = FakeHotelRepository();
      final container = ProviderContainer(overrides: [hotelRepositoryProvider.overrideWithValue(hotels)]);
      addTearDown(container.dispose);

      container
        ..listen(hotelResultsProvider(_query()), (_, _) {})
        ..listen(hotelResultsProvider(_query()), (_, _) {});
      await container.read(hotelResultsProvider(_query()).future);
      expect(hotels.queries, hasLength(1));

      await container.read(hotelResultsProvider(_query(page: 2)).future);
      expect(hotels.queries.map((q) => q.page), [1, 2]);
    });
  });
}
