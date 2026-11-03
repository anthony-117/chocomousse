import 'package:chocomousse/features/hotels/data/hotel_models.dart';
import 'package:chocomousse/features/hotels/data/hotel_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

final FutureProviderFamily<HotelResults, HotelQuery> hotelResultsProvider = FutureProvider.autoDispose
    .family<HotelResults, HotelQuery>((ref, query) => ref.watch(hotelRepositoryProvider).search(query));

final FutureProviderFamily<HotelDetails, HotelDetailsQuery> hotelDetailsProvider = FutureProvider.autoDispose
    .family<HotelDetails, HotelDetailsQuery>((ref, query) => ref.watch(hotelRepositoryProvider).details(query));
