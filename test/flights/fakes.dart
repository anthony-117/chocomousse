import 'dart:async';

import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:chocomousse/features/flights/data/flight_repository.dart';

/// Flights JSON as returned by pamplemousse, with fields the app must ignore.
Map<String, Object?> fareJson({
  String id = 'tp:1',
  String? returnAt = '2027-04-14T18:10:00+02:00',
  int stops = 0,
  int? returnStops = 0,
  int? durationMinutes = 260,
  num amount = 82,
  String dateMatch = 'exact',
  String bookingUrl = 'https://www.aviasales.com/search/1?marker=1',
}) => {
  'id': id,
  'airline': 'ITA Airways',
  'flightNumber': 'AZ319',
  'originAirport': 'ORY',
  'destinationAirport': 'FCO',
  'departureAt': '2027-04-10T09:25:00+02:00',
  'returnAt': returnAt,
  'stops': stops,
  'returnStops': returnStops,
  'durationMinutes': durationMinutes,
  'price': {'amount': amount, 'currency': 'USD'},
  'bookingUrl': bookingUrl,
  'dateMatch': dateMatch,
  'source': 'Travelpayouts',
};

const priceNote = 'Recent prices found by other travellers. The live price is on the booking site.';

Map<String, Object?> resultsJson({
  List<Map<String, Object?>>? items,
  String? message,
  String? searchUrl,
  List<String> warnings = const [],
  Map<String, Object?> origin = const {
    'id': '2988507',
    'name': 'Paris',
    'flightCity': 'Paris',
    'code': 'PAR',
    'isNearby': false,
    'distanceKm': 2,
  },
}) => {
  'origin': origin,
  'destination': {
    'id': '3169070',
    'name': 'Rome',
    'flightCity': 'Rome',
    'code': 'ROM',
    'isNearby': false,
    'distanceKm': 1,
  },
  'dates': {'from': '2027-04-10', 'to': '2027-04-14'},
  'tripType': 'roundTrip',
  'directOnly': false,
  'currency': 'USD',
  'items': items ?? [fareJson()],
  'priceNote': priceNote,
  'message': message,
  'searchUrl': searchUrl,
  'warnings': warnings,
};

/// Configurable stand-in for the API that records each search.
class FakeFlightRepository implements FlightRepository {
  FakeFlightRepository({FlightResults? results, this.error})
    : results = results ?? FlightResults.fromJson(resultsJson());

  FlightResults results;
  Exception? error;

  /// When set, searches wait for it, so a test can look at the loading state.
  Completer<void>? gate;

  final queries = <FlightQuery>[];

  @override
  Future<FlightResults> search(FlightQuery query) async {
    queries.add(query);
    await gate?.future;
    final failure = error;
    if (failure != null) throw failure;
    return results;
  }
}
