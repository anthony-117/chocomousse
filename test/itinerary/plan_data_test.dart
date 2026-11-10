import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

(PlanRepository, ScriptedAdapter) _repository(List<(int, Object?)> answers) {
  final adapter = ScriptedAdapter(answers);
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
  return (PlanRepository(dio), adapter);
}

final _trip = TripSettings(
  passport: 'LB',
  currency: 'USD',
  from: DateTime(2027, 4, 10),
  to: DateTime(2027, 4, 14),
  adults: 1,
  preferences: const Preferences(levels: {Criterion.budget: Level.high, Criterion.nature: Level.low}, tripBudget: 1200),
  pace: Pace.packed,
);

void main() {
  group('Plan.fromJson', () {
    test('reads every part of the contract', () {
      final plan = Plan.fromJson(planJson(withCar: true, overBudgetBy: 40));

      expect(plan.id, 'p1');
      expect(plan.name, 'Rome, 5 days');
      expect(plan.status, PlanStatus.draft);
      expect(plan.destinationId, '3169070');
      expect(plan.destinationName, 'Rome');
      expect(plan.from, DateTime(2027, 4, 10));
      expect(plan.nights, 4);
      expect(plan.adults, 1);
      expect(plan.originId, '276781');
      expect(plan.pace, Pace.balanced);
      expect(plan.tripBudget, 1200);

      final match = plan.match!;
      expect(match.percent, 91);
      expect(match.parts.map((p) => (p.part, p.percent)), [
        (MatchPartKind.hotel, 94),
        (MatchPartKind.flight, 88),
        (MatchPartKind.days, 89),
      ]);
      expect(match.days.first.label, 'Culture & history');

      expect(plan.hotel!.offer.id, 'bk:1');
      expect(plan.hotel!.ranked.match!.percent, 94);
      expect(plan.hotel!.checkedAt, DateTime.utc(2027, 4, 1, 10, 2));
      expect(plan.flight!.offer.id, 'tp:1');
      expect(plan.car!.offer.id, 'bk:car:1');
      expect(plan.car!.ranked.match!.percent, 70);

      expect(plan.total.amount, 939);
      expect(plan.total.car, 180);
      expect(plan.total.unpriced, 8);
      expect(plan.total.overBudgetBy, 40);

      expect(plan.days, hasLength(5));
      final day2 = plan.days[1];
      expect(day2.title, 'Day 2 · Colosseum area');
      expect(day2.weather!.maxC, 21);
      expect(day2.walkKm, 6.4);
      expect(day2.items.map((i) => i.kind), [
        ItemKind.sight,
        ItemKind.sight,
        ItemKind.restaurant,
        ItemKind.freeTime,
        ItemKind.event,
      ]);
      final opera = day2.items.last;
      expect(opera.start, '20:00');
      expect(opera.price!.amount, 38);
      expect(opera.ref!.kind, RefKind.event);
      expect(opera.ref!.url, 'https://www.ticketmaster.it/e/1');
      expect(plan.notes.single, contains('45 minutes'));
    });

    test('a plan without a flight, car or match reads them as null', () {
      final plan = Plan.fromJson({...planJson(withFlight: false), 'match': null});

      expect(plan.flight, isNull);
      expect(plan.car, isNull);
      expect(plan.match, isNull);
      expect(plan.total.flight, isNull);
      expect(plan.originId, isNull);
    });

    test('unknown values read as other or the default', () {
      final json = planJson(status: 'archived', pace: 'frantic');
      final days = json['days']! as List<Map<String, Object?>>;
      days[0] = dayJson(
        1,
        items: [
          itemJson('picnic', '12:00', 'Picnic', ref: {'kind': 'boat', 'id': 'x:1'}),
        ],
      );
      final match = json['match']! as Map<String, Object?>;
      json['match'] = {
        ...match,
        'parts': [
          {'part': 'train', 'weight': 1, 'percent': 50},
        ],
        'days': [
          {'criterion': 'shopping', 'weight': 1, 'percent': 50},
        ],
      };

      final plan = Plan.fromJson(json);

      expect(plan.status, PlanStatus.draft);
      expect(plan.pace, Pace.balanced);
      expect(plan.days.first.items.single.kind, ItemKind.other);
      expect(plan.days.first.items.single.ref!.kind, RefKind.other);
      expect(plan.match!.parts.single.part, MatchPartKind.other);
      expect(plan.match!.days.single.label, 'shopping');
    });

    test('only OpenTripMap places have a details page', () {
      final items = Plan.fromJson(planJson()).days[1].items;

      expect(items.map((i) => i.ref?.hasPlaceDetails ?? false), [false, true, true, false, false]);
    });
  });

  test('PlanSummary and PlanList read the My plans list', () {
    final list = PlanList.fromJson({
      'items': [summaryJson(status: 'planned'), summaryJson(id: 'p2', updatedAt: '2027-04-02T08:00:00Z')],
      'count': 2,
      'max': 50,
    });

    expect(list.count, 2);
    expect(list.max, 50);
    expect(list.items.first.status, PlanStatus.planned);
    expect(list.items.first.matchPercent, 91);
    expect(list.items.last.updatedAt, DateTime.utc(2027, 4, 2, 8));
  });

  group('PlanRepository', () {
    test('build posts the trip, its weights and the pace', () async {
      final (repository, adapter) = _repository([(201, planJson())]);

      final plan = await repository.build(
        destinationId: '3169070',
        destinationName: 'Rome',
        trip: _trip,
        originId: '276781',
      );

      expect(plan.id, 'p1');
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/plans');
      expect(request.receiveTimeout, const Duration(seconds: 60));
      final body = request.data as Map<String, Object?>;
      expect(body['destinationId'], '3169070');
      expect(body['from'], '2027-04-10');
      expect(body['to'], '2027-04-14');
      expect(body['adults'], 1);
      expect(body['currency'], 'USD');
      expect(body['originId'], '276781');
      expect(body['pace'], 'packed');
      expect(body['tripBudget'], 1200);
      expect(body['preferences'], {
        'budget': 90,
        'culture': 50,
        'food': 50,
        'nature': 10,
        'nightlife': 50,
        'comfort': 50,
      });
    });

    test('each route uses its method and path', () async {
      final (repository, adapter) = _repository([
        (200, planJson()),
        (
          200,
          {
            'items': [summaryJson()],
            'count': 1,
            'max': 50,
          },
        ),
        (200, planJson(name: 'Spring in Rome')),
        (200, planJson(status: 'planned')),
        (204, null),
        (200, alternativesJson('hotel', [], chosenId: 'bk:1')),
        (200, alternativesJson('flight', [])),
        (200, alternativesJson('car', [])),
        (200, planJson(hotelId: 'bk:2')),
        (200, planJson()),
      ]);

      await repository.plan('p1');
      await repository.list();
      expect((await repository.rename('p1', 'Spring in Rome')).name, 'Spring in Rome');
      expect((await repository.setStatus('p1', PlanStatus.planned)).status, PlanStatus.planned);
      await repository.delete('p1');
      expect((await repository.hotels('p1')).chosenId, 'bk:1');
      await repository.flights('p1');
      await repository.cars('p1');
      expect((await repository.swap('p1', OfferKind.hotel, 'bk:2')).hotel!.offer.id, 'bk:2');
      await repository.removeCar('p1');

      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'GET /plans/p1',
        'GET /plans',
        'PATCH /plans/p1',
        'PATCH /plans/p1',
        'DELETE /plans/p1',
        'GET /plans/p1/alternatives/hotels',
        'GET /plans/p1/alternatives/flights',
        'GET /plans/p1/alternatives/cars',
        'PUT /plans/p1/hotel',
        'DELETE /plans/p1/car',
      ]);
      expect(adapter.requests[2].data, {'name': 'Spring in Rome'});
      expect(adapter.requests[3].data, {'status': 'planned'});
      expect(adapter.requests[8].data, {'offerId': 'bk:2'});
    });

    test('409 too-many-plans is the plan limit', () async {
      final (repository, _) = _repository([(409, problem(409, 'too-many-plans'))]);

      await expectLater(
        repository.build(destinationId: '3169070', destinationName: 'Rome', trip: _trip),
        throwsA(
          isA<PlanLimitReached>().having(
            (e) => e.message,
            'message',
            'You can keep up to 50 plans. Delete one to make room.',
          ),
        ),
      );
    });

    test('422 no-places names the city', () async {
      final (repository, _) = _repository([(422, problem(422, 'no-places'))]);

      await expectLater(
        repository.build(destinationId: '3169070', destinationName: 'Rome', trip: _trip),
        throwsA(isA<NoPlaces>().having((e) => e.message, 'message', contains('for Rome right now'))),
      );
    });

    test('404 is a missing plan, on reads and on deletes', () async {
      final (repository, _) = _repository([(404, problem(404, 'not-found')), (404, problem(404, 'not-found'))]);

      await expectLater(repository.plan('gone'), throwsA(isA<PlanNotFound>()));
      await expectLater(repository.delete('gone'), throwsA(isA<PlanNotFound>()));
    });

    test('400 names the refused field', () async {
      final (repository, _) = _repository([
        (
          400,
          {
            'status': 400,
            'errors': {
              'name': ['Name must be 1 to 60 characters.'],
            },
          },
        ),
      ]);

      await expectLater(
        repository.rename('p1', ''),
        throwsA(
          isA<PlanFieldError>()
              .having((e) => e.field, 'field', 'name')
              .having((e) => e.message, 'message', 'Name must be 1 to 60 characters.'),
        ),
      );
    });

    test('any other failure is left as it is', () async {
      final (repository, _) = _repository([(500, problem(500, 'boom'))]);

      await expectLater(repository.list(), throwsA(isA<DioException>()));
    });
  });
}
