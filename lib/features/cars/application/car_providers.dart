import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:chocomousse/features/cars/data/car_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

/// A city's pick-up places. Only read when the pick-up sheet opens.
final FutureProviderFamily<CarPlaces, String> carPlacesProvider = FutureProvider.autoDispose.family<CarPlaces, String>(
  (ref, destinationId) => ref.watch(carRepositoryProvider).places(destinationId),
);

final FutureProviderFamily<CarResults, CarQuery> carResultsProvider = FutureProvider.autoDispose
    .family<CarResults, CarQuery>((ref, query) => ref.watch(carRepositoryProvider).search(query));
