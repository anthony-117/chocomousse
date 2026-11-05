import 'dart:async';

import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:chocomousse/features/hotels/data/hotel_models.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:chocomousse/features/ranking/data/ranking_repository.dart';

import '../cars/fakes.dart';
import '../flights/fakes.dart';
import '../hotels/fakes.dart';

/// A match as the API returns it for `sort=match`.
Map<String, Object?> matchJson({
  int percent = 94,
  String reason = 'Cheap for Rome, with lots of culture close by',
  bool overBudget = false,
  List<Map<String, Object?>>? parts,
}) => {
  'percent': percent,
  'reason': reason,
  'overBudget': overBudget,
  'parts':
      parts ??
      [
        {'criterion': 'budget', 'weight': 90, 'percent': 88, 'known': true, 'detail': r'$812 for 4 nights'},
        {'criterion': 'culture', 'weight': 50, 'percent': 97, 'known': true, 'detail': '41 sights within 1 km'},
        {'criterion': 'nightlife', 'weight': 10, 'percent': 50, 'known': false, 'detail': ''},
      ],
};

/// Adds a match to each item and the ranking fields to the response.
Map<String, Object?> ranked(
  Map<String, Object?> json, {
  List<Map<String, Object?>?>? matches,
  String? rankingNote,
  num? tripBudget,
}) {
  final items = (json['items']! as List).cast<Map<String, Object?>>();
  return {
    ...json,
    'sort': 'match',
    'items': [
      for (var i = 0; i < items.length; i++)
        {...items[i], 'match': matches == null ? matchJson() : (i < matches.length ? matches[i] : null)},
    ],
    'weights': {'budget': 90, 'culture': 50, 'food': 50, 'nature': 50, 'nightlife': 10, 'comfort': 50},
    'tripBudget': tripBudget,
    'rankingNote': rankingNote,
  };
}

RankedHotels rankedHotels([Map<String, Object?>? json]) {
  final body = json ?? ranked(hotelResultsJson());
  final results = HotelResults.fromJson(body);
  return RankedList.fromJson(body, results: results, offers: results.items, id: (h) => h.id);
}

RankedFlights rankedFlights([Map<String, Object?>? json]) {
  final body = json ?? ranked(resultsJson());
  final results = FlightResults.fromJson(body);
  return RankedList.fromJson(body, results: results, offers: results.items, id: (f) => f.id);
}

RankedCars rankedCars([Map<String, Object?>? json]) {
  final body = json ?? ranked(carResultsJson());
  final results = CarResults.fromJson(body);
  return RankedList.fromJson(body, results: results, offers: results.items, id: (c) => c.id);
}

/// Configurable stand-in for the API that records each ranked search.
class FakeRankingRepository implements RankingRepository {
  FakeRankingRepository({RankedHotels? hotels, RankedFlights? flights, RankedCars? cars, this.error})
    : hotelList = hotels ?? rankedHotels(),
      flightList = flights ?? rankedFlights(),
      carList = cars ?? rankedCars();

  RankedHotels hotelList;
  RankedFlights flightList;
  RankedCars carList;
  Exception? error;

  /// When set, searches wait for it, so a test can look at the loading state.
  Completer<void>? gate;

  final hotelQueries = <RankedQuery>[];
  final flightQueries = <(RankedQuery, String)>[];
  final carQueries = <RankedQuery>[];

  Future<T> _answer<T>(T value) async {
    await gate?.future;
    final failure = error;
    if (failure != null) throw failure;
    return value;
  }

  @override
  Future<RankedHotels> hotels(RankedQuery q) {
    hotelQueries.add(q);
    return _answer(hotelList);
  }

  @override
  Future<RankedFlights> flights(RankedQuery q, String originId) {
    flightQueries.add((q, originId));
    return _answer(flightList);
  }

  @override
  Future<RankedCars> cars(RankedQuery q) {
    carQueries.add(q);
    return _answer(carList);
  }
}
