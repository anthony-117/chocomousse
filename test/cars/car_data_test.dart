import 'dart:convert';

import 'package:chocomousse/features/cars/application/car_providers.dart';
import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:chocomousse/features/cars/data/car_repository.dart';
import 'package:chocomousse/features/cars/presentation/widgets/car_texts.dart';
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

CarQuery _query({CarFilters filters = const CarFilters(), int page = 1, String place = 'centre'}) => (
  destinationId: '3169070',
  from: DateTime(2027, 4, 10),
  to: DateTime(2027, 4, 14),
  place: place,
  driverAge: 24,
  currency: 'EUR',
  filters: filters,
  page: page,
);

void main() {
  group('models', () {
    test('a car keeps missing values empty, never 0 or false', () {
      final car = CarOffer.fromJson(
        carJson(
          gearbox: null,
          seats: null,
          doors: null,
          bags: null,
          airCon: null,
          freeCancellation: null,
          deposit: null,
          photoUrl: null,
          rating: null,
        ),
      );

      expect(
        (car.gearbox, car.seats, car.doors, car.bags, car.airCon, car.freeCancellation, car.deposit, car.photoUrl),
        (null, null, null, null, null, null, null, null),
      );
      expect(car.company.rating, isNull);
      expect(car.damageExcess!.currency, 'EUR');
    });

    test('an unknown gearbox or pick-up type does not break the car', () {
      final car = CarOffer.fromJson(carJson(gearbox: 'cvt', pickUpType: 'meetAndGreet'));

      expect((car.gearbox, car.pickUp.type), (null, PickUpType.other));
    });

    test('a car without a price, id or link is a broken answer', () {
      expect(() => CarOffer.fromJson(carJson()..remove('price')), throwsA(isA<TypeError>()));
      expect(() => CarOffer.fromJson(carJson()..remove('id')), throwsA(isA<TypeError>()));
      expect(() => CarOffer.fromJson(carJson()..remove('bookingUrl')), throwsA(isA<TypeError>()));
    });

    test('results read paging, filter values, notes and the time in the device zone', () {
      final results = CarResults.fromJson(carResultsJson(page: 2, mayHaveMore: true, driverNote: 'Young driver'));

      expect((results.page, results.totalPages, results.days, results.mayHaveMore), (2, 3, 4, true));
      expect(results.pricesFetchedAt, DateTime.utc(2027, 3, 1, 9, 40).toLocal());
      expect(results.searchedCount, 415);
      expect(results.companies.map((c) => c.value), ['Budget', 'Hertz']);
      expect((results.driverNote, results.place.id), ('Young driver', 'centre'));
    });

    test('the Booking.com search falls back to a car link when the API gives none', () {
      expect(CarResults.fromJson(carResultsJson(searchUrl: null)).bookingSearchUrl, carSearchUrl);
      expect(CarResults.fromJson(carResultsJson(searchUrl: null, items: [])).bookingSearchUrl, isNull);
    });

    test('pick-up places read airports with their code', () {
      final places = CarPlaces.fromJson(carPlacesJson()).places;

      expect(places.map((p) => p.label), ['City centre', 'Fiumicino Airport · FCO', 'Ciampino Airport · CIA']);
      expect(places.map((p) => p.isAirport), [false, true, true]);
    });

    test('filters count what is on, compare by value and keep the sort when cleared', () {
      const none = CarFilters();
      final some = none.copyWith(
        sort: CarSort.price,
        gearbox: () => Gearbox.automatic,
        minSeats: () => 5,
        companies: ['Budget'],
        freeCancellation: true,
      );

      expect((none.activeCount, some.activeCount), (0, 4));
      expect(
        some,
        none.copyWith(
          sort: CarSort.price,
          gearbox: () => Gearbox.automatic,
          minSeats: () => 5,
          companies: ['Budget'],
          freeCancellation: true,
        ),
      );
      expect(some.copyWith(gearbox: () => null).gearbox, isNull);
      expect(some.cleared(), const CarFilters(sort: CarSort.price));
      expect(none.copyWith(maxPrice: () => 0).maxPriceIsValid, isFalse);
    });
  });

  group('texts', () {
    test('specs and pick-up leave out what is not known', () {
      final car = CarOffer.fromJson(carJson());
      final bare = CarOffer.fromJson(carJson(gearbox: null, seats: null, bags: 1, airCon: false, orSimilar: null));

      expect(carTitle(car), 'Fiat 600 or similar');
      expect(carSpecs(car), 'Intermediate · Automatic · 5 seats · 3 bags · A/C');
      expect((carTitle(bare), carSpecs(bare)), ('Fiat 600', 'Intermediate · 1 bag'));
      expect(pickUpLine(car.pickUp), 'via Sardegna · Downtown · 0.9 km from centre');
      expect(
        pickUpLine(CarOffer.fromJson(carJson(pickUpType: 'other', distanceKm: 24.4)).pickUp),
        'via Sardegna · 24 km from centre',
      );
    });

    test('fuel, money, days and the driver note read plainly', () {
      expect(fuelPolicyText('Full to full'), 'return it full');
      expect(fuelPolicyText('Quick tank'), 'Quick tank');
      expect(formatAmount(const Money(amount: 300, currency: 'EUR')), '€300');
      expect(formatAmount(const Money(amount: 12.5, currency: 'EUR')), '€12.50');
      expect((daysLabel(1), daysLabel(4)), ('1 day', '4 days'));
      expect(rentalDay(DateTime(2027, 4, 10)), 'Sat 10 Apr, 10:00');
      expect(driverAgeNote(24), contains('Under 25'));
      expect(driverAgeNote(71), contains('Over 70'));
      expect((driverAgeNote(30), driverAgeNote(null)), (null, null));
    });
  });

  group('repository', () {
    test('a search sends the rental, sort, filters and page, with repeated lists and a long wait', () async {
      final adapter = _Adapter(carResultsJson());
      final repository = CarRepository(Dio()..httpClientAdapter = adapter);
      final filters = const CarFilters(sort: CarSort.price).copyWith(
        sizes: ['Small', 'Intermediate'],
        gearbox: () => Gearbox.manual,
        minSeats: () => 5,
        minBags: () => 2,
        maxPrice: () => 400,
        pickUpTypes: [PickUpType.terminal, PickUpType.rentalCentre],
        companies: ['Budget'],
        freeCancellation: true,
      );

      await repository.search(_query(filters: filters, page: 2, place: 'FCO'));

      expect(adapter.last!.path, '/destinations/3169070/cars');
      expect(adapter.last!.queryParameters, {
        'from': '2027-04-10',
        'to': '2027-04-14',
        'place': 'FCO',
        'driverAge': 24,
        'currency': 'EUR',
        'sort': 'price',
        'size': ['Small', 'Intermediate'],
        'gearbox': 'manual',
        'minSeats': 5,
        'minBags': 2,
        'maxPrice': 400,
        'pickUpType': ['terminal', 'rentalCentre'],
        'company': ['Budget'],
        'freeCancellation': true,
        'page': 2,
      });
      expect(adapter.last!.uri.query, contains('size=Small&size=Intermediate'));
      expect(
        (adapter.last!.connectTimeout, adapter.last!.receiveTimeout),
        (CarRepository.searchTimeout, CarRepository.searchTimeout),
      );
    });

    test('the default search sends no filter', () async {
      final adapter = _Adapter(carResultsJson());

      await CarRepository(Dio()..httpClientAdapter = adapter).search(_query());

      expect(adapter.last!.queryParameters.keys, ['from', 'to', 'place', 'driverAge', 'currency', 'sort', 'page']);
    });

    test('places are asked for the destination', () async {
      final adapter = _Adapter(carPlacesJson());

      final places = await CarRepository(Dio()..httpClientAdapter = adapter).places('3169070');

      expect(adapter.last!.path, '/destinations/3169070/car-places');
      expect(places.places, hasLength(3));
    });
  });

  group('providers', () {
    test('equal searches share one request, and another page makes another', () async {
      final cars = FakeCarRepository();
      final container = ProviderContainer(overrides: [carRepositoryProvider.overrideWithValue(cars)]);
      addTearDown(container.dispose);

      container
        ..listen(carResultsProvider(_query()), (_, _) {})
        ..listen(carResultsProvider(_query()), (_, _) {});
      await container.read(carResultsProvider(_query()).future);
      expect(cars.queries, hasLength(1));

      await container.read(carResultsProvider(_query(page: 2)).future);
      expect(cars.queries.map((q) => q.page), [1, 2]);
    });

    test('places are loaded once per destination', () async {
      final cars = FakeCarRepository();
      final container = ProviderContainer(overrides: [carRepositoryProvider.overrideWithValue(cars)]);
      addTearDown(container.dispose);

      container.listen(carPlacesProvider('3169070'), (_, _) {});
      await container.read(carPlacesProvider('3169070').future);
      await container.read(carPlacesProvider('3169070').future);

      expect(cars.placeRequests, 1);
    });
  });
}
