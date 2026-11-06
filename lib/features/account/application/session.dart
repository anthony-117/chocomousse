import 'dart:async';

import 'package:chocomousse/core/network/auth_interceptor.dart';
import 'package:chocomousse/features/account/data/auth_repository.dart';
import 'package:chocomousse/features/account/data/profile_models.dart';
import 'package:chocomousse/features/account/data/profile_repository.dart';
import 'package:chocomousse/features/assistant/application/chat_controller.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/flights/application/flight_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// The traveller, or null when signed out. Loading until Firebase has restored a saved sign-in.
final authUserProvider = StreamProvider<AuthUser?>((ref) => ref.watch(authRepositoryProvider).changes());

/// The signed-in traveller's profile, read again for each new traveller.
final profileProvider = FutureProvider<Profile>((ref) {
  ref.watch(authUserProvider.select((u) => u.value?.id));
  return ref.watch(profileRepositoryProvider).get();
});

/// Signing out, and everything the app holds for the traveller (spec FR-006).
class SessionController {
  SessionController(this._ref);

  final Ref _ref;

  Future<void> signOut() async {
    try {
      await _ref.read(authRepositoryProvider).signOut();
    } finally {
      clear();
    }
  }

  /// Forgets the traveller's trip settings, departure city, profile and assistant chat.
  void clear() {
    _ref
      ..invalidate(tripSettingsProvider)
      ..invalidate(departureCityProvider)
      ..invalidate(profileProvider)
      ..invalidate(chatControllerProvider);
  }
}

final sessionControllerProvider = Provider<SessionController>(SessionController.new);

/// New trips start from the profile (spec FR-005): passport, currency, preferences and departure city.
class ProfileSeeder {
  ProfileSeeder(this._ref);

  final Ref _ref;

  /// Reads the profile and applies it. A failure leaves the defaults; Profile shows the error.
  Future<void> seed() async {
    // Listened, not read: a provider nobody listens to is paused, and its future may never finish.
    final profile = _ref.listen(profileProvider.future, (_, _) {});
    try {
      apply(await profile.read());
    } on Object {
      // Profile shows the error with Try again.
    } finally {
      profile.close();
    }
  }

  void apply(Profile profile) {
    final trip = _ref.read(tripSettingsProvider.notifier);
    final budget = _ref.read(tripSettingsProvider).preferences.tripBudget;
    trip
      ..setPassport(profile.passport)
      ..setCurrency(profile.homeCurrency)
      ..setPreferences(Preferences(levels: profile.preferences.levels, tripBudget: budget))
      ..setPace(profile.pace);

    final city = profile.homeCity;
    if (city != null && _ref.read(departureCityProvider)?.id != city.id) {
      // The departure city needs the full city; a failure leaves it unset, and the flights tab asks for one.
      unawaited(
        _ref
            .read(destinationRepositoryProvider)
            .destination(city.id)
            .then((full) => _ref.read(departureCityProvider.notifier).choose(full), onError: (Object _) {}),
      );
    }
  }
}

final profileSeederProvider = Provider<ProfileSeeder>(ProfileSeeder.new);

/// The API client's view of the sign-in (plan decision 5).
class AccountApiSession implements ApiSession {
  AccountApiSession(this._ref);

  final Ref _ref;

  @override
  Future<String?> token({bool refresh = false}) => _ref.read(authRepositoryProvider).idToken(refresh: refresh);

  @override
  Future<void> signInRejected() => _ref.read(sessionControllerProvider).signOut();

  @override
  Future<void> emailNotConfirmed() => _ref.read(authRepositoryProvider).reloadUser();
}

/// Overrides for the app's `ProviderScope`: the real sign-in behind the API client.
List<Override> accountOverrides(AuthRepository auth) => [
  authRepositoryProvider.overrideWithValue(auth),
  apiSessionProvider.overrideWith(AccountApiSession.new),
];
