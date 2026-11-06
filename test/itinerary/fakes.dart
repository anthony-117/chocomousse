import 'dart:async';
import 'dart:convert';

import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:chocomousse/features/hotels/data/hotel_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:dio/dio.dart';

import '../cars/fakes.dart';
import '../flights/fakes.dart';
import '../hotels/fakes.dart';
import '../ranking/fakes.dart';

Map<String, Object?> itemJson(
  String kind,
  String start,
  String name, {
  int minutes = 120,
  num walkKm = 0.4,
  Map<String, Object?>? price,
  Map<String, Object?>? ref,
}) => {'kind': kind, 'start': start, 'minutes': minutes, 'name': name, 'walkKm': walkKm, 'price': price, 'ref': ref};

Map<String, Object?> placeRef(String id, {String? url}) => {
  'kind': 'place',
  'id': id,
  'lat': 41.89,
  'lng': 12.49,
  'imageUrl': null,
  'url': url,
};

Map<String, Object?> dayJson(int number, {String? title, List<Map<String, Object?>>? items}) => {
  'number': number,
  'date': '2027-04-${(9 + number).toString().padLeft(2, '0')}',
  'title': title ?? (number == 2 ? 'Day 2 · Colosseum area' : 'Day $number · Rome'),
  'weather': {'summary': 'Sunny', 'maxC': 21, 'minC': 12, 'rainChance': 10},
  'walkKm': 6.4,
  'items':
      items ??
      (number == 1
          ? [
              itemJson('arrival', '11:25', 'Land at FCO, then to the hotel', minutes: 105, walkKm: 0),
              itemJson('sight', '14:00', 'Trevi Fountain', ref: placeRef('otm:trevi')),
            ]
          : [
              itemJson(
                'sight',
                '09:00',
                'Colosseum',
                walkKm: 1.1,
                ref: placeRef('wd:Q10285', url: 'https://www.wikidata.org/wiki/Q10285'),
              ),
              itemJson('sight', '11:15', 'Roman Forum', minutes: 90, ref: placeRef('otm:forum')),
              itemJson('restaurant', '13:00', 'Lunch · Trattoria Luzzi', minutes: 60, ref: placeRef('otm:luzzi')),
              itemJson('freeTime', '16:00', 'Free time', minutes: 150, walkKm: 0),
              itemJson(
                'event',
                '20:00',
                'Opera at the Baths',
                price: {'amount': 38, 'currency': 'USD'},
                ref: {'kind': 'event', 'id': 'tm:1', 'url': 'https://www.ticketmaster.it/e/1'},
              ),
            ]),
};

Map<String, Object?> planJson({
  String id = 'p1',
  String name = 'Rome, 5 days',
  String status = 'draft',
  bool withCar = false,
  bool withFlight = true,
  String hotelId = 'bk:1',
  List<String> notes = const ['The time from the airport to the hotel is estimated at 45 minutes.'],
  List<String> warnings = const [],
  num? overBudgetBy,
  String pace = 'balanced',
  int days = 5,
}) => {
  'id': id,
  'name': name,
  'status': status,
  'destination': {'id': '3169070', 'name': 'Rome', 'countryCode': 'IT'},
  'from': '2027-04-10',
  'to': '2027-04-${(9 + days).toString().padLeft(2, '0')}',
  'adults': 1,
  'currency': 'USD',
  'originId': withFlight ? '276781' : null,
  'preferences': {'budget': 90, 'culture': 90, 'food': 50, 'nature': 10, 'nightlife': 10, 'comfort': 50},
  'pace': pace,
  'tripBudget': 1200,
  'match': {
    'percent': 91,
    'reason': 'Great hotel for you, days full of sights',
    'parts': [
      {'part': 'hotel', 'weight': 300, 'percent': 94},
      {'part': 'flight', 'weight': 140, 'percent': 88},
      {'part': 'days', 'weight': 160, 'percent': 89},
    ],
    'days': [
      {'criterion': 'culture', 'weight': 90, 'percent': 100},
      {'criterion': 'nature', 'weight': 10, 'percent': 67},
    ],
  },
  'hotel': {
    'offer': {...hotelJson(id: hotelId, total: 612, perNight: 153), 'match': matchJson()},
    'checkedAt': '2027-04-01T10:02:00Z',
  },
  'flight': withFlight
      ? {
          'offer': {...fareJson(amount: 289), 'match': matchJson(percent: 88)},
          'checkedAt': '2027-04-01T10:02:00Z',
        }
      : null,
  'car': withCar
      ? {
          'offer': {...carJson(), 'match': matchJson(percent: 70)},
          'checkedAt': '2027-04-01T10:05:00Z',
        }
      : null,
  'total': {
    'amount': 939,
    'currency': 'USD',
    'flight': withFlight ? 289 : null,
    'hotel': 612,
    'car': withCar ? 180 : null,
    'events': 38,
    'unpriced': 8,
    'otherCurrency': 0,
    'overBudgetBy': overBudgetBy,
  },
  'days': [for (var n = 1; n <= days; n++) dayJson(n)],
  'notes': notes,
  'warnings': warnings,
  'createdAt': '2027-04-01T10:02:00Z',
  'updatedAt': '2027-04-01T10:02:00Z',
};

Map<String, Object?> summaryJson({
  String id = 'p1',
  String name = 'Rome, 5 days',
  String status = 'draft',
  String updatedAt = '2027-04-01T10:02:00Z',
}) => {
  'id': id,
  'name': name,
  'status': status,
  'destinationName': 'Rome',
  'from': '2027-04-10',
  'to': '2027-04-14',
  'total': 939,
  'currency': 'USD',
  'matchPercent': 91,
  'imageUrl': null,
  'updatedAt': updatedAt,
};

Map<String, Object?> alternativesJson(String kind, List<Map<String, Object?>> items, {String? chosenId}) => {
  'kind': kind,
  'chosenId': chosenId,
  'checkedAt': '2027-04-01T10:02:00Z',
  'items': items,
};

/// Answers each request with the next scripted (status, body), and records the requests.
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.answers);

  final List<(int, Object?)> answers;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = answers.removeAt(0);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> problem(int status, String code) => {'status': status, 'title': 'Refused', 'code': code};

/// Plans held in memory, answering as the API would. [failWith] makes the next call fail; [gate] holds the next build.
class FakePlanRepository implements PlanRepository {
  FakePlanRepository({List<Plan>? plans}) {
    for (final plan in plans ?? [Plan.fromJson(planJson())]) {
      _plans[plan.id] = plan;
    }
  }

  final _plans = <String, Plan>{};
  final calls = <String>[];
  Exception? failWith;
  Completer<void>? gate;
  TripSettings? builtWith;
  String? builtFrom;
  int _next = 2;

  Plan saved(String id) => _plans[id]!;

  void _fail() {
    final error = failWith;
    if (error != null) {
      failWith = null;
      throw error;
    }
  }

  @override
  Future<Plan> build({
    required String destinationId,
    required String destinationName,
    required TripSettings trip,
    String? originId,
  }) async {
    calls.add('build');
    await gate?.future;
    _fail();
    builtWith = trip;
    builtFrom = originId;
    final plan = Plan.fromJson(planJson(id: 'p${_next++}', pace: trip.pace.name, withFlight: originId != null));
    return _plans[plan.id] = plan;
  }

  @override
  Future<Plan> plan(String id) async {
    calls.add('plan $id');
    _fail();
    return _plans[id] ?? (throw const PlanNotFound());
  }

  @override
  Future<PlanList> list() async {
    calls.add('list');
    _fail();
    final items = _plans.values
        .map(
          (p) => PlanSummary.fromJson(
            summaryJson(id: p.id, name: p.name, status: p.status.name, updatedAt: p.updatedAt.toIso8601String()),
          ),
        )
        .toList()
        .reversed
        .toList();
    return PlanList(items: items, count: items.length, max: 50);
  }

  Plan _change(String id, Map<String, Object?> Function(Map<String, Object?>) edit) {
    final current = _plans[id] ?? (throw const PlanNotFound());
    final json = edit(
      planJson(
        id: id,
        name: current.name,
        status: current.status.name,
        withCar: current.car != null,
        hotelId: current.hotel?.offer.id ?? 'bk:1',
      ),
    );
    return _plans[id] = Plan.fromJson({...json, 'updatedAt': DateTime.now().toUtc().toIso8601String()});
  }

  @override
  Future<Plan> rename(String id, String name) async {
    calls.add('rename $id $name');
    _fail();
    return _change(id, (j) => {...j, 'name': name});
  }

  @override
  Future<Plan> setStatus(String id, PlanStatus status) async {
    calls.add('status $id ${status.name}');
    _fail();
    return _change(id, (j) => {...j, 'status': status.name});
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete $id');
    _fail();
    _plans.remove(id);
  }

  @override
  Future<Alternatives<HotelOffer>> hotels(String id) async {
    calls.add('hotels $id');
    _fail();
    return Alternatives.fromJson(
      alternativesJson('hotel', [
        {...hotelJson(total: 612), 'match': matchJson()},
        {
          ...hotelJson(id: 'bk:2', name: 'Hotel Santa Maria', total: 498),
          'match': matchJson(percent: 89, reason: 'Cheapest, quiet streets'),
        },
      ], chosenId: _plans[id]?.hotel?.offer.id),
      HotelOffer.fromJson,
    );
  }

  @override
  Future<Alternatives<FlightFare>> flights(String id) async {
    calls.add('flights $id');
    _fail();
    return Alternatives.fromJson(
      alternativesJson('flight', [
        {...fareJson(amount: 289), 'match': matchJson(percent: 88)},
        {...fareJson(id: 'tp:2', amount: 240), 'match': matchJson(percent: 80)},
      ], chosenId: 'tp:1'),
      FlightFare.fromJson,
    );
  }

  @override
  Future<Alternatives<CarOffer>> cars(String id) async {
    calls.add('cars $id');
    _fail();
    return Alternatives.fromJson(
      alternativesJson('car', [
        {...carJson(), 'match': matchJson(percent: 70)},
      ], chosenId: _plans[id]?.car?.offer.id),
      CarOffer.fromJson,
    );
  }

  @override
  Future<Plan> swap(String id, OfferKind kind, String offerId) async {
    calls.add('swap $id ${kind.name} $offerId');
    _fail();
    return switch (kind) {
      OfferKind.hotel => _change(id, (j) => planJson(id: id, hotelId: offerId, name: j['name']! as String)),
      OfferKind.car => _change(id, (j) => {...planJson(id: id, withCar: true, name: j['name']! as String)}),
      OfferKind.flight => _change(id, (j) => j),
    };
  }

  @override
  Future<Plan> removeCar(String id) async {
    calls.add('remove car $id');
    _fail();
    return _change(id, (j) => planJson(id: id, name: j['name']! as String));
  }
}
