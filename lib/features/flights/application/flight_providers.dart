import 'package:chocomousse/features/destination/data/models.dart';
import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:chocomousse/features/flights/data/flight_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

/// The city the traveller flies from. Remembered for the session, across destinations, and never guessed.
class DepartureCityNotifier extends Notifier<DestinationSummary?> {
  @override
  DestinationSummary? build() => null;

  // ignore: use_setters_to_change_properties, a notifier's actions read better as methods.
  void choose(DestinationSummary city) => state = city;
}

final departureCityProvider = NotifierProvider<DepartureCityNotifier, DestinationSummary?>(DepartureCityNotifier.new);

final FutureProviderFamily<FlightResults, FlightQuery> flightResultsProvider = FutureProvider.autoDispose
    .family<FlightResults, FlightQuery>((ref, query) => ref.watch(flightRepositoryProvider).search(query));
