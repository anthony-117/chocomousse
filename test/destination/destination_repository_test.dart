import 'dart:convert';
import 'dart:typed_data';

import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/destination/data/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Answers every request with [body] and records the request.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body);

  final Object body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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

(DestinationRepository, _FakeAdapter) _repo(Object body) {
  final adapter = _FakeAdapter(body);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = adapter;
  return (DestinationRepository(dio), adapter);
}

void main() {
  test('search sends the query and parses cities', () async {
    final (repo, adapter) = _repo([
      {
        'id': '3169070',
        'name': 'Rome',
        'region': 'Lazio',
        'countryCode': 'IT',
        'countryName': 'Italy',
        'flag': null,
        'lat': 41.9,
        'lng': 12.5,
        'timeZone': 'Europe/Rome',
      },
    ]);

    final results = await repo.search('rom');

    expect(results.single.subtitle, 'Lazio, Italy');
    expect(adapter.requests.single.path, '/destinations');
    expect(adapter.requests.single.queryParameters, {'q': 'rom', 'limit': 10});
  });

  test('overview sends passport, currency and ISO dates', () async {
    final (repo, adapter) = _repo(overviewJson);

    final overview = await repo.overview(
      '3169070',
      passport: 'LB',
      currency: 'USD',
      from: DateTime(2027, 4, 10),
      to: DateTime(2027, 4, 14),
    );

    expect(overview.destination.name, 'Rome');
    expect(adapter.requests.single.path, '/destinations/3169070/overview');
    expect(adapter.requests.single.queryParameters, {
      'passport': 'LB',
      'currency': 'USD',
      'from': '2027-04-10',
      'to': '2027-04-14',
    });
  });

  test('places sends the category name', () async {
    final (repo, adapter) = _repo({'items': <Object>[], 'warnings': <Object>[]});

    await repo.places('3169070', PlaceCategory.restaurant);

    expect(adapter.requests.single.queryParameters, {'category': 'restaurant'});
  });

  test('place details encode the id (it contains a colon)', () async {
    final (repo, adapter) = _repo({
      'id': 'otm:W3',
      'name': 'Colosseum',
      'category': 'attraction',
      'location': {'lat': 41.89, 'lng': 12.49},
      'openingHours': <Object>[],
      'source': 'OpenTripMap',
    });

    final place = await repo.place('otm:W3');

    expect(place.name, 'Colosseum');
    expect(adapter.requests.single.path, '/places/otm%3AW3');
  });

  test('destination reads the summary out of the details response', () async {
    final (repo, _) = _repo({'destination': overviewJson['destination'], 'country': null});

    expect((await repo.destination('3169070')).name, 'Rome');
  });

  test('events and countries parse their lists', () async {
    final (eventsRepo, eventsAdapter) = _repo({
      'items': [
        {
          'id': 'tm:E1',
          'name': 'AS Roma vs Lazio',
          'date': '2026-11-28',
          'time': '20:45',
          'venue': 'Stadio Olimpico',
          'category': 'Sports',
          'priceFrom': {'amount': 45.0, 'currency': 'EUR'},
          'url': 'https://tm/e1',
        },
      ],
      'warnings': <Object>[],
    });
    final events = await eventsRepo.events('3169070', from: DateTime(2026, 11, 26), to: DateTime(2026, 11, 30));
    expect(events.items.single.priceFrom, '45 EUR');
    expect(eventsAdapter.requests.single.queryParameters, {'from': '2026-11-26', 'to': '2026-11-30'});

    final (countriesRepo, _) = _repo([
      {
        'code': 'LB',
        'name': 'Lebanon',
        'flag': null,
        'currencies': ['LBP'],
      },
    ]);
    expect((await countriesRepo.countries()).single.currencies, ['LBP']);
  });
}
