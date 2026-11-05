import 'dart:async';

import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:chocomousse/features/ranking/data/ranking_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

/// How long a tab's list is kept after nothing shows it, so switching tabs back shows it at once (spec FR-006).
const keepRankedFor = Duration(minutes: 10);

/// Keeps a list while something watches it, and [keepRankedFor] after that.
void _keepForAWhile(Ref ref) {
  final link = ref.keepAlive();
  Timer? timer;
  ref
    ..onCancel(() => timer = Timer(keepRankedFor, link.close))
    ..onResume(() => timer?.cancel())
    ..onDispose(() => timer?.cancel());
}

final FutureProviderFamily<RankedHotels, RankedQuery> rankedHotelsProvider = FutureProvider.autoDispose
    .family<RankedHotels, RankedQuery>((ref, query) {
      _keepForAWhile(ref);
      return ref.watch(rankingRepositoryProvider).hotels(query);
    });

/// Keyed by the search and the departure city's id.
final FutureProviderFamily<RankedFlights, (RankedQuery, String)> rankedFlightsProvider = FutureProvider.autoDispose
    .family<RankedFlights, (RankedQuery, String)>((ref, key) {
      _keepForAWhile(ref);
      return ref.watch(rankingRepositoryProvider).flights(key.$1, key.$2);
    });

final FutureProviderFamily<RankedCars, RankedQuery> rankedCarsProvider = FutureProvider.autoDispose
    .family<RankedCars, RankedQuery>((ref, query) {
      _keepForAWhile(ref);
      return ref.watch(rankingRepositoryProvider).cars(query);
    });
