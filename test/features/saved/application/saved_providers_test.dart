import 'dart:async';

import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/saved/application/saved_providers.dart';
import 'package:chocomousse/features/saved/data/saved_models.dart';
import 'package:chocomousse/features/saved/data/saved_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../chat/fakes.dart';
import '../fakes.dart';

void main() {
  final hotel = AssistantCard.fromJson(hotelCardJson())!;
  final place = AssistantCard.fromJson({...placeCardJson(), 'destinationId': '2988507'})!;

  (ProviderContainer, FakeSavedRepository) setUpContainer({int max = 200}) {
    final saved = FakeSavedRepository(max: max);
    final container = ProviderContainer(overrides: savedOverrides(saved));
    addTearDown(container.dispose);
    return (container, saved);
  }

  test('a toggle shows at once, saves, and reloads the Saved list', () async {
    final (container, saved) = setUpContainer();
    await container.read(savedIdsProvider.future);
    final list = container.listen(savedProvider, (_, _) {});
    await container.read(savedProvider.future);

    final gate = saved.gate = Completer<void>();
    final done = container.read(savedIdsProvider.notifier).toggle(hotel, fallbackDestinationId: '3169070');
    expect(container.read(savedIdsProvider).value!.contains(SavedKind.hotel, 'bk:1'), isTrue);
    gate.complete();
    expect(await done, isNull);
    saved.gate = null;

    expect(saved.items.single.destinationId, '3169070');
    expect((await container.read(savedProvider.future)).items.single.id, 'bk:1');
    list.close();
  });

  test("the card's own city wins over the chat's trip city", () async {
    final (container, saved) = setUpContainer();
    await container.read(savedIdsProvider.future);
    await container.read(savedIdsProvider.notifier).toggle(place, fallbackDestinationId: '3169070');
    expect(saved.items.single.destinationId, '2988507');
  });

  test('a second toggle removes it', () async {
    final (container, saved) = setUpContainer();
    await container.read(savedIdsProvider.future);
    final ids = container.read(savedIdsProvider.notifier);
    await ids.toggle(hotel, fallbackDestinationId: '3169070');
    expect(await ids.toggle(hotel), isNull);
    expect(container.read(savedIdsProvider).value!.hotel, isEmpty);
    expect(saved.calls, ['ids', 'save hotel bk:1', 'remove hotel bk:1']);
  });

  test('a failed save reverts the bookmark and says why', () async {
    final (container, saved) = setUpContainer();
    await container.read(savedIdsProvider.future);
    saved.failWith = savedProblem(500, {});
    final message = await container.read(savedIdsProvider.notifier).toggle(hotel, fallbackDestinationId: '3169070');
    expect(message, kSaveFailed);
    expect(container.read(savedIdsProvider).value!.hotel, isEmpty);
  });

  test('a failed remove puts the bookmark back', () async {
    final (container, saved) = setUpContainer();
    await container.read(savedIdsProvider.future);
    final ids = container.read(savedIdsProvider.notifier);
    await ids.toggle(hotel, fallbackDestinationId: '3169070');
    saved.failWith = savedProblem(500, {});
    expect(await ids.toggle(hotel), kRemoveFailed);
    expect(container.read(savedIdsProvider).value!.hotel, {'bk:1'});
  });

  test('the limit is named', () async {
    final (container, _) = setUpContainer(max: 0);
    await container.read(savedIdsProvider.future);
    final message = await container.read(savedIdsProvider.notifier).toggle(hotel, fallbackDestinationId: '3169070');
    expect(message, TooManySaved(0).message);
    expect(container.read(savedIdsProvider).value!.hotel, isEmpty);
  });

  test('without any city nothing is sent', () async {
    final (container, saved) = setUpContainer();
    await container.read(savedIdsProvider.future);
    expect(await container.read(savedIdsProvider.notifier).toggle(hotel), const NoCity().message);
    expect(saved.calls, ['ids']);
  });

  test('ids that failed to load show empty, and a toggle still works', () async {
    final saved = FakeSavedRepository()..failWith = savedProblem(500, {});
    final container = ProviderContainer(overrides: savedOverrides(saved), retry: (_, _) => null);
    addTearDown(container.dispose);
    await expectLater(container.read(savedIdsProvider.future), throwsA(anything));
    final ids = container.read(savedIdsProvider.notifier);
    expect(ids.isSaved(hotel), isFalse);
    expect(await ids.toggle(hotel, fallbackDestinationId: '3169070'), isNull);
    expect(ids.isSaved(hotel), isTrue);
  });

  test('flights and cars are not toggled', () async {
    final (container, saved) = setUpContainer();
    await container.read(savedIdsProvider.future);
    expect(await container.read(savedIdsProvider.notifier).toggle(AssistantCard.fromJson(carCardJson())!), isNull);
    expect(saved.calls, ['ids']);
  });
}
