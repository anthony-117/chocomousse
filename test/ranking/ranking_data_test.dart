import 'dart:convert';

import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/ranking/application/ranking_providers.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:chocomousse/features/ranking/data/ranking_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../cars/fakes.dart';
import '../flights/fakes.dart';
import '../hotels/fakes.dart';
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

RankedQuery query({Preferences preferences = const Preferences()}) => (
  destinationId: '3169070',
  from: DateTime(2027, 4, 10),
  to: DateTime(2027, 4, 14),
  adults: 2,
  currency: 'EUR',
  driverAge: 24,
  preferences: preferences,
);

void main() {
  group('preferences', () {
    test('every criterion is Medium until set, and the levels send 10, 50 and 90', () {
      final p = const Preferences().withLevel(Criterion.budget, Level.high).withLevel(Criterion.nightlife, Level.low);

      expect(p.toQuery(), {'budget': 90, 'culture': 50, 'food': 50, 'nature': 50, 'nightlife': 10, 'comfort': 50});
      expect(p.withTripBudget(1500).toQuery()['tripBudget'], 1500);
      expect(p.summary, 'Budget High · Culture Medium · Food Medium · Nature Medium · Nightlife Low · Comfort Medium');
    });

    test('compare by value, so the same choices reuse a ranked list', () {
      const a = Preferences();
      final b = const Preferences().withLevel(Criterion.food, Level.medium);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == a.withTripBudget(900), isFalse);
      expect(Level.ofWeight(90), Level.high);
      expect(Level.ofWeight(70), isNull);
    });

    test('live in the trip settings and stay when other settings change', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tripSettingsProvider.notifier);
      final p = const Preferences(tripBudget: 1200).withLevel(Criterion.culture, Level.high);

      expect(container.read(tripSettingsProvider).preferences, const Preferences());
      notifier
        ..setPreferences(p)
        ..setAdults(3);
      expect(container.read(tripSettingsProvider).preferences, p);
    });
  });

  group('models', () {
    test('matches join to offers by id and keep the API order', () {
      final list = rankedHotels(
        ranked(
          hotelResultsJson(
            items: [
              hotelJson(id: 'bk:2', name: 'Second'),
              hotelJson(),
            ],
          ),
          matches: [matchJson(percent: 91), null],
        ),
      );

      expect(list.items.map((i) => i.offer.name), ['Second', 'Hotel Artemide']);
      expect(list.items.map((i) => i.match?.percent), [91, null]);
      expect(list.anyOverBudget, isFalse);
    });

    test('a part names its criterion and level, even one the app does not know', () {
      final match = rankedHotels().items.single.match!;

      expect(match.parts.map((p) => (p.label, p.levelLabel, p.known)), [
        ('Budget', 'High', true),
        ('Culture & history', 'Medium', true),
        ('Nightlife', 'Low', false),
      ]);
      final unknown = MatchPart.fromJson({'criterion': 'beaches', 'weight': 70, 'percent': 40});
      expect((unknown.label, unknown.levelLabel, unknown.known, unknown.detail), ('Beaches', '70', true, ''));
    });

    test('reads the ranking note, the trip budget and over-budget offers', () {
      final list = rankedCars(
        ranked(
          carResultsJson(),
          matches: [matchJson(overBudget: true)],
          rankingNote: 'Ranked on price only.',
          tripBudget: 50,
        ),
      );

      expect((list.rankingNote, list.tripBudget, list.anyOverBudget), ('Ranked on price only.', 50, true));
    });

    test('an unknown tab reads as hotels', () {
      expect(
        [RankedKind.parse('cars'), RankedKind.parse('boats'), RankedKind.parse(null)],
        [RankedKind.cars, RankedKind.hotels, RankedKind.hotels],
      );
    });
  });

  group('repository', () {
    (RankingRepository, _Adapter) make(Map<String, Object?> body) {
      final adapter = _Adapter(body);
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = adapter;
      return (RankingRepository(dio), adapter);
    }

    final prefs = const Preferences(tripBudget: 1500).withLevel(Criterion.budget, Level.high);

    test('hotels ask for sort=match with every weight, the budget and a long timeout', () async {
      final (repo, adapter) = make(ranked(hotelResultsJson()));

      final list = await repo.hotels(query(preferences: prefs));

      expect(adapter.last!.path, '/destinations/3169070/hotels');
      expect(adapter.last!.queryParameters, {
        'from': '2027-04-10',
        'to': '2027-04-14',
        'currency': 'EUR',
        'sort': 'match',
        'budget': 90,
        'culture': 50,
        'food': 50,
        'nature': 50,
        'nightlife': 50,
        'comfort': 50,
        'tripBudget': 1500,
        'adults': 2,
        'page': 1,
      });
      expect(adapter.last!.receiveTimeout, RankingRepository.searchTimeout);
      expect(list.items.single.match!.percent, 94);
    });

    test('flights ask for a round trip from the departure city, 20 at most', () async {
      final (repo, adapter) = make(ranked(resultsJson()));

      final list = await repo.flights(query(), '2988507');

      expect(adapter.last!.path, '/destinations/3169070/flights');
      expect(adapter.last!.queryParameters, containsPair('origin', '2988507'));
      expect(adapter.last!.queryParameters, containsPair('tripType', 'roundTrip'));
      expect(adapter.last!.queryParameters, containsPair('limit', 20));
      expect(adapter.last!.queryParameters, containsPair('sort', 'match'));
      expect(adapter.last!.queryParameters.containsKey('tripBudget'), isFalse);
      expect(list.items.single.offer.id, 'tp:1');
    });

    test('cars ask for the city centre and the driver age', () async {
      final (repo, adapter) = make(ranked(carResultsJson()));

      final list = await repo.cars(query());

      expect(adapter.last!.path, '/destinations/3169070/cars');
      expect(adapter.last!.queryParameters, containsPair('place', 'centre'));
      expect(adapter.last!.queryParameters, containsPair('driverAge', 24));
      expect(adapter.last!.receiveTimeout, RankingRepository.searchTimeout);
      expect(list.results.days, 4);
    });

    test('the provider builds the repository on the shared client', () {
      final container = ProviderContainer(overrides: [dioProvider.overrideWithValue(Dio())]);
      addTearDown(container.dispose);

      expect(container.read(rankingRepositoryProvider), isA<RankingRepository>());
    });
  });

  group('providers', () {
    test('a list is kept after nothing shows it, so going back to a tab asks again for nothing', () async {
      final fake = FakeRankingRepository();
      final container = ProviderContainer(overrides: [rankingRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final sub = container.listen(rankedHotelsProvider(query()), (_, _) {});
      await container.read(rankedHotelsProvider(query()).future);
      sub.close();
      await Future<void>.delayed(Duration.zero);
      await container.read(rankedHotelsProvider(query()).future);

      expect(fake.hotelQueries, hasLength(1));
    });

    test('new preferences are a new search', () async {
      final fake = FakeRankingRepository();
      final container = ProviderContainer(overrides: [rankingRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      final other = query(preferences: const Preferences().withLevel(Criterion.food, Level.high));

      await container.read(rankedCarsProvider(query()).future);
      await container.read(rankedCarsProvider(other).future);
      await container.read(rankedFlightsProvider((query(), '2988507')).future);

      expect(fake.carQueries.map((q) => q.preferences.of(Criterion.food)), [Level.medium, Level.high]);
      expect(fake.flightQueries.single.$2, '2988507');
    });
  });
}
