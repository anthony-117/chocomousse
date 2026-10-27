import 'package:chocomousse/env.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/destination/data/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

/// Who is travelling and when: drives visa checks, currency conversion and date-based sections.
class TripSettings {
  const TripSettings({required this.passport, required this.currency, required this.from, required this.to});

  final String passport;
  final String currency;
  final DateTime from;
  final DateTime to;

  int get nights => to.difference(from).inDays;

  TripSettings copyWith({String? passport, String? currency, DateTime? from, DateTime? to}) => TripSettings(
    passport: passport ?? this.passport,
    currency: currency ?? this.currency,
    from: from ?? this.from,
    to: to ?? this.to,
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
