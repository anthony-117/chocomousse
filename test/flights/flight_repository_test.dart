import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:chocomousse/features/flights/data/flight_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Answers every request with an empty result and records the request.
class _Adapter implements HttpClientAdapter {
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      '''
{"origin":{"id":"1","name":"Paris","flightCity":"Paris","code":"PAR","isNearby":false,"distanceKm":2},
"destination":{"id":"2","name":"Rome","flightCity":"Rome","code":"ROM","isNearby":false,"distanceKm":1},
"items":[],"priceNote":"Note","message":null,"searchUrl":null,"warnings":[]}''',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

FlightQuery _query(FlightTripType type) => (
  destinationId: '3169070',
  originId: '2988507',
  from: DateTime(2027, 4, 10),
  to: DateTime(2027, 4, 14),
  currency: 'EUR',
  tripType: type,
  directOnly: true,
);

void main() {
  late _Adapter adapter;
  late FlightRepository repository;

  setUp(() {
    adapter = _Adapter();
    repository = FlightRepository(Dio()..httpClientAdapter = adapter);
  });

  test('a round trip sends every search value', () async {
    await repository.search(_query(FlightTripType.roundTrip));

    expect(adapter.last!.path, '/destinations/3169070/flights');
    expect(adapter.last!.queryParameters, {
      'origin': '2988507',
      'from': '2027-04-10',
      'to': '2027-04-14',
      'tripType': 'roundTrip',
      'directOnly': true,
      'currency': 'EUR',
    });
  });

  test('a one-way search sends no return date', () async {
    await repository.search(_query(FlightTripType.oneWay));

    expect(adapter.last!.queryParameters.containsKey('to'), isFalse);
    expect(adapter.last!.queryParameters['tripType'], 'oneWay');
  });

  group('isSameCityError', () {
    DioException failure(int status, Object? data) {
      final options = RequestOptions();
      return DioException(
        requestOptions: options,
        response: Response<Object?>(requestOptions: options, statusCode: status, data: data),
      );
    }

    test('is true only for a 400 naming the origin', () {
      expect(
        isSameCityError(
          failure(400, <String, dynamic>{
            'errors': <String, dynamic>{
              'origin': ['Same city.'],
            },
          }),
        ),
        isTrue,
      );
      expect(
        isSameCityError(
          failure(400, <String, dynamic>{
            'errors': <String, dynamic>{
              'to': ['Bad date.'],
            },
          }),
        ),
        isFalse,
      );
      expect(isSameCityError(failure(500, null)), isFalse);
      expect(isSameCityError(StateError('x')), isFalse);
    });
  });

  test('the shared JSON sample parses', () {
    expect(FlightResults.fromJson(resultsJson()).items.single.originAirport, 'ORY');
  });
}
