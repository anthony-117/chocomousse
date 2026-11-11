import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../itinerary/fakes.dart';

(PlanRepository, ScriptedAdapter) _repository(List<(int, Object?)> answers) {
  final adapter = ScriptedAdapter(answers);
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
  return (PlanRepository(dio), adapter);
}

Map<String, Object?> _withEdits() => {
  ...planJson(),
  'edits': [
    {
      'day': 2,
      'action': 'replace',
      'itemId': 'wd:Q10285',
      'newItem': {'kind': 'place', 'id': 'otm:N123', 'name': 'Villa Borghese'},
    },
    {'day': 3, 'action': 'remove', 'itemId': 'wd:Q243', 'newItem': null},
    {'day': 4, 'action': 'shuffle'},
  ],
};

void main() {
  group('Plan.edits', () {
    test('reads replace, remove and unknown actions', () {
      final edits = Plan.fromJson(_withEdits()).edits;
      expect(edits.map((e) => (e.day, e.action, e.itemId)), [
        (2, EditAction.replace, 'wd:Q10285'),
        (3, EditAction.remove, 'wd:Q243'),
        (4, EditAction.other, null),
      ]);
      expect(edits.first.newItem, (kind: RefKind.place, id: 'otm:N123', name: 'Villa Borghese'));
      expect(edits[1].newItem, isNull);
    });

    test('a plan without edits has none', () {
      expect(Plan.fromJson(planJson()).edits, isEmpty);
    });
  });

  group('routes', () {
    test('day alternatives ask for the item and the kind, and read the cards nearest first', () async {
      final (repo, adapter) = _repository([
        (
          200,
          {
            'day': 2,
            'itemId': 'wd:Q10285',
            'kind': 'nature',
            'items': [
              {...alternativeCardJson(), 'walkKmFromDay': 0.8},
              {'kind': 'mystery', 'id': 'x', 'item': <String, Object?>{}},
            ],
          },
        ),
      ]);
      final answer = await repo.dayAlternatives('p1', 2, itemId: 'wd:Q10285', kind: AlternativeKind.nature);
      final request = adapter.requests.single;
      expect(request.path, '/plans/p1/days/2/alternatives');
      expect(request.queryParameters, {'itemId': 'wd:Q10285', 'kind': 'nature'});
      expect((answer.day, answer.itemId, answer.kind), (2, 'wd:Q10285', AlternativeKind.nature));
      expect(answer.items.single.walkKmFromDay, 0.8);
      expect((answer.items.single.card as PlaceCard).place.name, 'Villa Borghese');
    });

    test('day alternatives without an item leave it out, and carry the message when empty', () async {
      final (repo, adapter) = _repository([
        (200, {'day': 1, 'kind': 'sight', 'items': <Object>[], 'message': 'Nothing else nearby for this day.'}),
      ]);
      final answer = await repo.dayAlternatives('p1', 1);
      expect(adapter.requests.single.queryParameters, isEmpty);
      expect(answer.items, isEmpty);
      expect(answer.message, 'Nothing else nearby for this day.');
    });

    test('add or replace posts the kind, the id and what it replaces', () async {
      final (repo, adapter) = _repository([(200, _withEdits()), (200, planJson())]);
      final plan = await repo.addOrReplaceItem('p1', 2, kind: RefKind.place, itemId: 'otm:N123', replaces: 'wd:Q10285');
      expect(plan.edits, isNotEmpty);
      await repo.addOrReplaceItem('p1', 3, kind: RefKind.event, itemId: 'tm:9');
      expect(adapter.requests.map((r) => [r.method, r.path, r.data]), [
        [
          'POST',
          '/plans/p1/days/2/items',
          {'kind': 'place', 'id': 'otm:N123', 'replaces': 'wd:Q10285'},
        ],
        [
          'POST',
          '/plans/p1/days/3/items',
          {'kind': 'event', 'id': 'tm:9'},
        ],
      ]);
    });

    test('remove deletes the item of the day', () async {
      final (repo, adapter) = _repository([(200, planJson())]);
      await repo.removeItem('p1', 3, 'tm:G5vY');
      expect(
        (adapter.requests.single.method, adapter.requests.single.path),
        ('DELETE', '/plans/p1/days/3/items/tm%3AG5vY'),
      );
    });

    test('rebuild sends only the values given', () async {
      final (repo, adapter) = _repository([(200, planJson()), (200, planJson())]);
      await repo.rebuild(
        'p1',
        RebuildRequest(
          from: DateTime(2027, 4, 11),
          to: DateTime(2027, 4, 15),
          adults: 2,
          originId: '276781',
          preferences: const {'culture': 90},
          pace: Pace.relaxed,
          tripBudget: 1300,
        ),
      );
      await repo.rebuild('p1', const RebuildRequest());
      expect(adapter.requests.map((r) => r.path), everyElement('/plans/p1/rebuild'));
      expect(adapter.requests.map((r) => r.data), [
        {
          'from': '2027-04-11',
          'to': '2027-04-15',
          'adults': 2,
          'originId': '276781',
          'preferences': {'culture': 90},
          'pace': 'relaxed',
          'tripBudget': 1300,
        },
        isEmpty,
      ]);
    });
  });

  group('failures', () {
    Future<Object?> failureOf((int, Object?) answer, Future<Object?> Function(PlanRepository) call) async {
      final (repo, _) = _repository([answer]);
      try {
        await call(repo);
      } on Object catch (e) {
        return e;
      }
      return null;
    }

    test('422 day-full carries the API words', () async {
      final failure = await failureOf((
        422,
        {...problem(422, 'day-full'), 'detail': 'Day 2 is full for a balanced pace. Replace a place instead.'},
      ), (r) => r.addOrReplaceItem('p1', 2, kind: RefKind.place, itemId: 'otm:N123'));
      expect(failure, isA<DayFull>());
      expect((failure! as DayFull).message, 'Day 2 is full for a balanced pace. Replace a place instead.');
    });

    test('422 no-places on rebuild names the city', () async {
      final failure = await failureOf((
        422,
        problem(422, 'no-places'),
      ), (r) => r.rebuild('p1', const RebuildRequest(), city: 'Rome'));
      expect(failure, isA<NoPlaces>());
      expect((failure! as NoPlaces).message, contains('Rome'));
    });

    test('400 names the field', () async {
      final failure = await failureOf((
        400,
        {
          ...problem(400, 'validation'),
          'errors': {
            'id': ['Not among the alternatives of day 2.'],
          },
        },
      ), (r) => r.addOrReplaceItem('p1', 2, kind: RefKind.place, itemId: 'otm:nope'));
      expect(failure, isA<PlanFieldError>());
      expect((failure! as PlanFieldError).field, 'id');
    });

    test('404 is PlanNotFound', () async {
      final failure = await failureOf((404, problem(404, 'not-found')), (r) => r.removeItem('p1', 9, 'wd:Q1'));
      expect(failure, isA<PlanNotFound>());
    });
  });
}
