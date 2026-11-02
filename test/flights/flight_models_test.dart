import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  test('a fare keeps the airport local time, whatever the device zone', () {
    final fare = FlightFare.fromJson(fareJson());

    expect(fare.departureAt, DateTime(2027, 4, 10, 9, 25));
    expect(fare.returnAt, DateTime(2027, 4, 14, 18, 10));
    expect(fare.amount, 82);
    expect(fare.currency, 'USD');
    expect(fare.dateMatch, FlightDateMatch.exact);
  });

  test('a one-way fare has no return', () {
    final fare = FlightFare.fromJson(fareJson(returnAt: null, returnStops: null));

    expect(fare.returnAt, isNull);
    expect(fare.returnStops, isNull);
  });

  test('a badly formed date or missing link fails the parse, so no fare has a dead button', () {
    expect(() => FlightFare.fromJson({...fareJson(), 'departureAt': 'soon, maybe later'}), throwsA(anything));
    expect(() => FlightFare.fromJson({...fareJson(), 'bookingUrl': null}), throwsA(anything));
  });

  test('date levels have labels, and an unknown level has none', () {
    expect(FlightDateMatch.parse('exact').label, isNull);
    expect(FlightDateMatch.parse('nearby').label, 'Nearby dates');
    expect(FlightDateMatch.parse('sameMonth').label, 'Same month');
    expect(FlightDateMatch.parse('anyReturn').label, 'Different return');
    expect(FlightDateMatch.parse('somethingNew').label, isNull);
  });

  test('a city without an airport says which one is used', () {
    const paris = FlightCity(name: 'Paris', flightCity: 'Paris', isNearby: false, distanceKm: 2);
    const byblos = FlightCity(name: 'Byblos', flightCity: 'Beirut', isNearby: true, distanceKm: 38);

    expect(paris.nearbyNote, isNull);
    expect(byblos.nearbyNote, 'Byblos has no airport, so we use Beirut (38 km away).');
  });

  test('results read the message, search link and warnings', () {
    final results = FlightResults.fromJson(
      resultsJson(items: [], message: 'None found.', searchUrl: 'https://book', warnings: ['Down.']),
    );

    expect(results.items, isEmpty);
    expect(results.message, 'None found.');
    expect(results.searchUrl, 'https://book');
    expect(results.warnings, ['Down.']);
    expect(results.priceNote, priceNote);
  });
}
