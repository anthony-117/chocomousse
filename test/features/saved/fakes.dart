import 'dart:async';

import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/saved/data/saved_models.dart';
import 'package:chocomousse/features/saved/data/saved_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../account/fakes.dart';
import '../../itinerary/fakes.dart';
import '../chat/fakes.dart';

/// An in-memory Saved store. It outlives an app, so a rebuilt app reads what the last one saved.
class FakeSavedRepository implements SavedRepository {
  FakeSavedRepository({this.max = 200});

  final int max;
  final _items = <SavedItem>[];
  final calls = <String>[];

  /// Makes the next call fail with this.
  Exception? failWith;

  /// Holds every call until completed.
  Completer<void>? gate;

  int _clock = 0;

  List<SavedItem> get items => List.unmodifiable(_items);

  Future<void> _step(String call) async {
    calls.add(call);
    await gate?.future;
    final error = failWith;
    if (error != null) {
      failWith = null;
      throw error;
    }
  }

  @override
  Future<void> save(AssistantCard card, {required String destinationId}) async {
    final kind = SavedKind.of(card)!;
    await _step('save ${kind.name} ${card.id}');
    if (_items.any((i) => i.kind == kind && i.id == card.id)) return;
    if (_items.length >= max) throw TooManySaved(max);
    final body = SavedRepository.body(card, destinationId: destinationId);
    _items.add(
      SavedItem.fromJson({
        'kind': kind.name,
        'id': card.id,
        'destinationId': destinationId,
        'destinationName': card.destinationName ?? 'Rome',
        'name': body['name'],
        'imageUrl': body['imageUrl'],
        'lat': card.lat,
        'lng': card.lng,
        'savedAt': DateTime.utc(2026, 11, 11, 10, _clock++).toIso8601String(),
        'item': body['item'],
      })!,
    );
  }

  @override
  Future<void> remove(SavedKind kind, String id) async {
    await _step('remove ${kind.name} $id');
    _items.removeWhere((i) => i.kind == kind && i.id == id);
  }

  @override
  Future<SavedList> list({SavedKind? kind, String? destinationId}) async {
    await _step('list');
    final items = _items
        .where((i) => (kind == null || i.kind == kind) && (destinationId == null || i.destinationId == destinationId))
        .toList()
        .reversed
        .toList();
    return SavedList(items: items, count: _items.length, max: max);
  }

  @override
  Future<SavedIds> ids() async {
    await _step('ids');
    var ids = SavedIds.empty;
    for (final item in _items) {
      ids = ids.withId(item.kind, item.id, saved: true);
    }
    return ids;
  }
}

/// What a bookmark needs around it: the saved store, the chat fakes, and a trip chip that starts from a plan in Rome.
List<Override> bookmarkOverrides(FakeSavedRepository saved) => [
  ...chatOverrides(FakeChatTransport(), saved: saved),
  // The trip chip starts from this plan: Rome.
  plansProvider.overrideWith(
    (ref) => PlanList(
      items: [
        PlanSummary.fromJson({...summaryJson(), 'destinationId': '3169070'}),
      ],
      count: 1,
      max: 50,
    ),
  ),
  profileProvider.overrideWith((ref) => defaultProfile()),
];

/// A Saved store for screens that show cards but don't test saving.
List<Override> savedOverrides([FakeSavedRepository? saved]) => [
  savedRepositoryProvider.overrideWithValue(saved ?? FakeSavedRepository()),
];

/// A refusal as dio raises it.
DioException savedProblem(int status, Map<String, Object?> data) {
  final options = RequestOptions(path: '/saved');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status, data: data),
  );
}
