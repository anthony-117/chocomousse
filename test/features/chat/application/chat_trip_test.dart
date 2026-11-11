import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/chat/application/chat_trip.dart';
import 'package:chocomousse/features/chat/application/recents.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../account/fakes.dart';
import '../../../itinerary/fakes.dart';

class _Recents extends RecentsController {
  _Recents(this.items);

  final List<ChatListItem> items;

  @override
  Future<RecentsState> build() async => RecentsState(items: items, keepDays: 90);
}

ChatListItem _chat(ChatTrip? trip) => ChatListItem(
  id: 'c1',
  trip: trip,
  createdAt: DateTime.utc(2026, 11, 9),
  lastMessageAt: DateTime.utc(2026, 11, 10),
  messageCount: 2,
);

PlanSummary _plan() =>
    PlanSummary.fromJson({...summaryJson(), 'destinationId': '3169070', 'adults': 2, 'tripBudget': 1200});

Future<ProviderContainer> _container({
  List<ChatListItem> chats = const [],
  List<PlanSummary> plans = const [],
  Pace pace = Pace.balanced,
}) async {
  final container = ProviderContainer(
    overrides: [
      recentsProvider.overrideWith(() => _Recents(chats)),
      plansProvider.overrideWith((ref) => PlanList(items: plans, count: plans.length, max: 50)),
      profileProvider.overrideWith(
        (ref) => defaultProfile(
          preferences: const Preferences(levels: {Criterion.budget: Level.high}),
          pace: pace,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.listen(chatTripProvider, (_, _) {});
  await container.read(recentsProvider.future);
  await container.read(plansProvider.future);
  await container.read(profileProvider.future);
  return container;
}

void main() {
  test("starts from the latest chat's trip", () async {
    final trip = ChatTrip(destinationId: '3169070', destinationName: 'Rome', from: DateTime(2027, 4, 10), adults: 2);
    final c = await _container(chats: [_chat(trip)], plans: [_plan()]);
    expect(c.read(chatTripProvider).trip, trip);
  });

  test("falls back to the latest plan's trip", () async {
    final c = await _container(chats: [_chat(null)], plans: [_plan()]);
    final trip = c.read(chatTripProvider).trip;
    expect(trip.destinationId, '3169070');
    expect(trip.destinationName, 'Rome');
    expect(trip.from, DateTime(2027, 4, 10));
    expect(trip.adults, 2);
    expect(trip.tripBudget, 1200);
  });

  test('is empty with no chat and no plan', () async {
    final c = await _container();
    expect(c.read(chatTripProvider).trip.isEmpty, isTrue);
  });

  test('takes the preferences and pace from the profile, and sends them only once changed', () async {
    final c = await _container(pace: Pace.packed);
    final state = c.read(chatTripProvider);
    expect(state.preferences['budget'], 90);
    expect(state.preferences['food'], 50);
    expect(state.pace, Pace.packed);
    expect(c.read(chatTripProvider.notifier).toRequestParts(), (trip: null, preferences: null, pace: null));

    c.read(chatTripProvider.notifier)
      ..setPreferences({'budget': 10})
      ..setPace(Pace.relaxed);
    final parts = c.read(chatTripProvider.notifier).toRequestParts();
    expect(parts.preferences, {'budget': 10});
    expect(parts.pace, Pace.relaxed);
  });

  test('a trip the traveller set is kept when Recents reloads', () async {
    final c = await _container(chats: [_chat(const ChatTrip(destinationId: '1'))]);
    c.read(chatTripProvider.notifier).setTrip(const ChatTrip(destinationId: '2'));
    c.invalidate(recentsProvider);
    await c.read(recentsProvider.future);
    expect(c.read(chatTripProvider).trip.destinationId, '2');
    expect(c.read(chatTripProvider.notifier).toRequestParts().trip!.destinationId, '2');
  });
}
