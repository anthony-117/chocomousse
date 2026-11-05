import 'package:chocomousse/env.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/destination/data/models.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

/// Who is travelling and when: drives visa checks, currency conversion and date-based sections.
class TripSettings {
  const TripSettings({
    required this.passport,
    required this.currency,
    required this.from,
    required this.to,
    this.adults = defaultAdults,
    this.driverAge = defaultDriverAge,
    this.preferences = const Preferences(),
  });

  /// The hotels API's default; flights always search for one adult.
  static const defaultAdults = 2;
  static const maxAdults = 8;

  /// The car API's default and limits.
  static const defaultDriverAge = 30;
  static const minDriverAge = 18;
  static const maxDriverAge = 99;

  final String passport;
  final String currency;
  final DateTime from;
  final DateTime to;
  final int adults;

  /// For car rentals: under 25 or over 70, rental companies may charge extra.
  final int driverAge;

  /// What matters to the traveller, for weighted search (spec 005).
  final Preferences preferences;

  int get nights => to.difference(from).inDays;

  TripSettings copyWith({
    String? passport,
    String? currency,
    DateTime? from,
    DateTime? to,
    int? adults,
    int? driverAge,
    Preferences? preferences,
  }) => TripSettings(
    passport: passport ?? this.passport,
    currency: currency ?? this.currency,
    from: from ?? this.from,
    to: to ?? this.to,
    adults: adults ?? this.adults,
    driverAge: driverAge ?? this.driverAge,
    preferences: preferences ?? this.preferences,
  );
}

class TripSettingsNotifier extends Notifier<TripSettings> {
  @override
  TripSettings build() {
    // Default trip: 5 days starting in 30 days (same default as the API).
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).add(const Duration(days: 30));
    return TripSettings(
      passport: Env.defaultPassport,
      currency: Env.defaultCurrency,
      from: start,
      to: start.add(const Duration(days: 4)),
    );
  }

  void setPassport(String code) => state = state.copyWith(passport: code);

  void setCurrency(String code) => state = state.copyWith(currency: code);

  void setDates(DateTime from, DateTime to) => state = state.copyWith(from: from, to: to);

  /// One room fits 1 to 8 adults, as the API accepts.
  void setAdults(int adults) => state = state.copyWith(adults: adults.clamp(1, TripSettings.maxAdults));

  /// The car API accepts drivers from 18 to 99.
  void setDriverAge(int age) =>
      state = state.copyWith(driverAge: age.clamp(TripSettings.minDriverAge, TripSettings.maxDriverAge));

  void setPreferences(Preferences preferences) => state = state.copyWith(preferences: preferences);
}

final tripSettingsProvider = NotifierProvider<TripSettingsNotifier, TripSettings>(TripSettingsNotifier.new);

final FutureProviderFamily<List<DestinationSummary>, String> destinationSearchProvider = FutureProvider.autoDispose
    .family<List<DestinationSummary>, String>((ref, query) {
      final q = query.trim();
      if (q.length < 2) return Future.value(const []);
      return ref.watch(destinationRepositoryProvider).search(q);
    });

final FutureProviderFamily<DestinationSummary, String> destinationProvider = FutureProvider.autoDispose
    .family<DestinationSummary, String>((ref, id) => ref.watch(destinationRepositoryProvider).destination(id));

final FutureProviderFamily<DestinationOverview, String> overviewProvider = FutureProvider.autoDispose
    .family<DestinationOverview, String>((ref, id) {
      final trip = ref.watch(tripSettingsProvider);
      return ref
          .watch(destinationRepositoryProvider)
          .overview(id, passport: trip.passport, currency: trip.currency, from: trip.from, to: trip.to);
    });

final FutureProviderFamily<PlacesResult, (String, PlaceCategory)> placesProvider = FutureProvider.autoDispose
    .family<PlacesResult, (String, PlaceCategory)>(
      (ref, key) => ref.watch(destinationRepositoryProvider).places(key.$1, key.$2),
    );

final FutureProviderFamily<Place, String> placeDetailsProvider = FutureProvider.autoDispose.family<Place, String>(
  (ref, placeId) => ref.watch(destinationRepositoryProvider).place(placeId),
);

final FutureProviderFamily<EventsResult, String> eventsProvider = FutureProvider.autoDispose
    .family<EventsResult, String>((ref, id) {
      final trip = ref.watch(tripSettingsProvider);
      return ref.watch(destinationRepositoryProvider).events(id, from: trip.from, to: trip.to);
    });

final countriesProvider = FutureProvider<List<CountryOption>>(
  (ref) => ref.watch(destinationRepositoryProvider).countries(),
);
