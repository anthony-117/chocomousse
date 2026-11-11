import 'dart:async';

import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/account/data/profile_models.dart';
import 'package:chocomousse/features/chat/application/recents.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the composer's chips hold: the trip, the six preference weights (0–100) and the pace.
@immutable
class ChatTripState {
  const ChatTripState({
    this.trip = ChatTrip.empty,
    this.preferences = const {},
    this.pace = Pace.balanced,
    this.preferencesChanged = false,
    this.paceChanged = false,
  });

  final ChatTrip trip;
  final Map<String, int> preferences;
  final Pace pace;

  /// Set once the traveller changed them in the chips; until then the API uses the profile's.
  final bool preferencesChanged;
  final bool paceChanged;

  ChatTripState copyWith({
    ChatTrip? trip,
    Map<String, int>? preferences,
    Pace? pace,
    bool? preferencesChanged,
    bool? paceChanged,
  }) => ChatTripState(
    trip: trip ?? this.trip,
    preferences: preferences ?? this.preferences,
    pace: pace ?? this.pace,
    preferencesChanged: preferencesChanged ?? this.preferencesChanged,
    paceChanged: paceChanged ?? this.paceChanged,
  );
}

/// The parts of a [ChatRequest] the chips add to a message.
typedef ChatRequestParts = ({ChatTrip? trip, Map<String, int>? preferences, Pace? pace});

/// The composer's trip, preferences and pace (spec 008 US1). The trip starts from the latest chat's, else the latest
/// plan's, else empty; the preferences and pace start from the profile. A value the traveller set is never replaced.
class ChatTripController extends Notifier<ChatTripState> {
  bool _tripSet = false;

  @override
  ChatTripState build() {
    // The sources can change while a screen builds; the chips follow just after, never during it.
    void later(ChatTripState Function(ChatTripState current) change) => scheduleMicrotask(() {
      if (!ref.mounted) return;
      final next = change(state);
      if (!identical(next, state)) state = next;
    });
    ref
      ..listen(recentsProvider, (_, _) => later(_seeded))
      ..listen(plansProvider, (_, _) => later(_seeded))
      ..listen(profileProvider, (_, next) => later((current) => _withProfile(current, next.value)));
    return _seeded(_withProfile(const ChatTripState(), ref.read(profileProvider).value));
  }

  ChatTripState _withProfile(ChatTripState current, Profile? profile) => profile == null
      ? current
      : current.copyWith(
          preferences: current.preferencesChanged
              ? null
              : {for (final c in Criterion.values) c.name: profile.preferences.of(c).weight},
          pace: current.paceChanged ? null : profile.pace,
        );

  /// The first trip found, in the order latest chat, latest plan. A plan waits for Recents, so it never wins over a
  /// newer chat.
  ChatTripState _seeded(ChatTripState current) {
    if (_tripSet) return current;
    final recents = ref.read(recentsProvider);
    final fromChat = recents.value?.items.map((i) => i.trip).nonNulls.where((t) => !t.isEmpty).firstOrNull;
    if (fromChat != null) {
      _tripSet = true;
      return current.copyWith(trip: fromChat);
    }
    if (recents.isLoading) return current;
    final plan = ref.read(plansProvider).value?.items.firstOrNull;
    if (plan == null) return current;
    _tripSet = true;
    return current.copyWith(
      trip: ChatTrip(
        destinationId: plan.destinationId,
        destinationName: plan.destinationName,
        from: plan.from,
        to: plan.to,
        adults: plan.adults,
        currency: plan.currency,
        tripBudget: plan.tripBudget,
      ),
    );
  }

  void setTrip(ChatTrip trip) {
    _tripSet = true;
    state = state.copyWith(trip: trip);
  }

  void setPreferences(Map<String, int> preferences) =>
      state = state.copyWith(preferences: Map.unmodifiable(preferences), preferencesChanged: true);

  void setPace(Pace pace) => state = state.copyWith(pace: pace, paceChanged: true);

  /// A reopened chat: the chips take its stored trip, preferences and pace, so the next message continues it.
  void fromChat(Chat chat) {
    var next = state;
    if (chat.trip case final trip? when !trip.isEmpty) {
      _tripSet = true;
      next = next.copyWith(trip: trip);
    }
    if (chat.preferences case final preferences?) {
      next = next.copyWith(preferences: Map.unmodifiable(preferences), preferencesChanged: true);
    }
    if (chat.pace case final pace?) next = next.copyWith(pace: pace, paceChanged: true);
    if (!identical(next, state)) state = next;
  }

  /// The trip when it has anything; the preferences and pace only once changed, so the profile stays the default.
  ChatRequestParts toRequestParts() => (
    trip: state.trip.isEmpty ? null : state.trip,
    preferences: state.preferencesChanged ? state.preferences : null,
    pace: state.paceChanged ? state.pace : null,
  );
}

final chatTripProvider = NotifierProvider<ChatTripController, ChatTripState>(ChatTripController.new);
