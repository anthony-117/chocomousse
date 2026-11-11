import 'dart:convert';

import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/saved/data/saved_models.dart';
import 'package:chocomousse/features/saved/data/saved_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../itinerary/fakes.dart';
import '../../chat/fakes.dart';

(SavedRepository, ScriptedAdapter) _repository(List<(int, Object?)> answers) {
  final adapter = ScriptedAdapter(answers);
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
  return (SavedRepository(dio), adapter);
}

Map<String, Object?> savedItemJson({
  String kind = 'hotel',
  String id = 'bk:1',
  String name = 'Hotel Artemide',
  String savedAt = '2026-11-11T10:00:00Z',
  Map<String, Object?>? item,
}) => {
  'kind': kind,
  'id': id,
  'destinationId': '3169070',
  'destinationName': 'Rome',
  'name': name,
  'imageUrl': 'https://cf.bstatic.com/artemide.jpg',
  'lat': 41.9,
  'lng': 12.49,
  'savedAt': savedAt,
  'item': item,
};

void main() {
  final hotel = AssistantCard.fromJson(hotelCardJson())!;
  final place = AssistantCard.fromJson(placeCardJson())!;

  test('save puts the card under its kind and id, with its envelope and raw item', () async {
    final (repo, adapter) = _repository([(204, null)]);
    await repo.save(place, destinationId: '3169070');
    final request = adapter.requests.single;
    expect((request.method, request.path), ('PUT', '/saved/place/wd%3AQ10285'));
    final body = request.data as Map<String, Object?>;
    expect(body.keys, containsAll(['destinationId', 'name', 'imageUrl', 'lat', 'lng', 'item']));
    expect(body['destinationId'], '3169070');
    expect(body['name'], 'Colosseum');
    expect(body['imageUrl'], 'https://upload.wikimedia.org/colosseum.jpg');
    expect(body['item'], place.raw['item']);
  });

  test('a name over 200 characters is cut; an item over 20 KB packed is left out', () {
    final big = AssistantCard.fromJson({
      ...placeCardJson(),
      'item': {...placeItemJson(name: 'x' * 250), 'description': 'y' * (21 * 1024)},
    })!;
    final body = SavedRepository.body(big, destinationId: '3169070');
    expect((body['name']! as String).length, SavedRepository.maxNameLength);
    expect(body.containsKey('item'), isFalse);

    final small = SavedRepository.body(hotel, destinationId: '3169070');
    expect(utf8.encode(jsonEncode(small['item'])).length, lessThanOrEqualTo(SavedRepository.maxItemBytes));
    expect(small.containsKey('item'), isTrue);
  });

  test('flights and cars cannot be saved', () async {
    final (repo, _) = _repository([]);
    expect(() => repo.save(AssistantCard.fromJson(flightCardJson())!, destinationId: '3169070'), throwsArgumentError);
  });

  test('remove deletes the kind and id', () async {
    final (repo, adapter) = _repository([(204, null)]);
    await repo.remove(SavedKind.event, 'tm:Z7r');
    expect((adapter.requests.single.method, adapter.requests.single.path), ('DELETE', '/saved/event/tm%3AZ7r'));
  });

  test('list reads the items newest first and parses each item back into its card', () async {
    final (repo, adapter) = _repository([
      (
        200,
        {
          'items': [
            savedItemJson(kind: 'place', id: 'wd:Q10285', name: 'Colosseum', item: placeItemJson()),
            savedItemJson(savedAt: '2026-11-10T09:00:00Z'),
            {...savedItemJson(), 'kind': 'flight'},
          ],
          'count': 2,
          'max': 200,
        },
      ),
    ]);
    final list = await repo.list(kind: SavedKind.place, destinationId: '3169070');
    expect(adapter.requests.single.path, '/saved');
    expect(adapter.requests.single.queryParameters, {'kind': 'place', 'destinationId': '3169070'});
    expect(list.items.map((i) => i.name), ['Colosseum', 'Hotel Artemide']);
    expect((list.count, list.max), (2, 200));
    expect(list.items.first.card, isA<PlaceCard>());
    expect(list.items.first.card!.destinationId, '3169070');
    expect(list.items.last.card, isNull);
    expect(list.of(SavedKind.hotel).single.savedAt, DateTime.utc(2026, 11, 10, 9));
  });

  test('a list without filters sends no query', () async {
    final (repo, adapter) = _repository([
      (200, {'items': <Object>[], 'count': 0, 'max': 200}),
    ]);
    await repo.list();
    expect(adapter.requests.single.queryParameters, isEmpty);
  });

  test('ids reads the three sets', () async {
    final (repo, adapter) = _repository([
      (
        200,
        {
          'hotel': ['bk:1'],
          'place': ['wd:Q10285', 'otm:N1'],
          'event': <String>[],
        },
      ),
    ]);
    final ids = await repo.ids();
    expect(adapter.requests.single.path, '/saved/ids');
    expect(ids.contains(SavedKind.hotel, 'bk:1'), isTrue);
    expect(ids.place, {'wd:Q10285', 'otm:N1'});
    expect(ids.event, isEmpty);
  });

  test('409 too-many-saved names the limit; a 400 names the field', () async {
    final (full, _) = _repository([
      (409, {...problem(409, 'too-many-saved'), 'max': 200}),
    ]);
    await expectLater(
      full.save(hotel, destinationId: '3169070'),
      throwsA(
        isA<TooManySaved>()
            .having((f) => f.max, 'max', 200)
            .having((f) => f.message, 'message', 'You can keep up to 200 saved items. Remove one to make room.'),
      ),
    );

    final (refused, _) = _repository([
      (
        400,
        {
          'status': 400,
          'title': 'Invalid',
          'errors': {
            'name': ['Give a name of 1 to 200 characters.'],
          },
        },
      ),
    ]);
    await expectLater(
      refused.save(hotel, destinationId: '3169070'),
      throwsA(isA<FieldError>().having((f) => f.field, 'field', 'name')),
    );
  });

  test('another failure is the dio error', () async {
    final (repo, _) = _repository([(500, null)]);
    await expectLater(repo.ids(), throwsA(isA<DioException>()));
  });

  test('SavedIds adds and removes one id of one kind', () {
    final ids = SavedIds.empty.withId(SavedKind.hotel, 'bk:1', saved: true).withId(SavedKind.place, 'p', saved: true);
    expect(ids.hotel, {'bk:1'});
    expect(ids.withId(SavedKind.hotel, 'bk:1', saved: false).hotel, isEmpty);
    expect(ids.withId(SavedKind.hotel, 'bk:1', saved: false).place, {'p'});
  });
}
