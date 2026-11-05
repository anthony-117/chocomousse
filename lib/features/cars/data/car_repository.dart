import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Calls the pamplemousse car endpoints. Tests replace it through [carRepositoryProvider].
class CarRepository {
  const CarRepository(this._dio);

  final Dio _dio;

  /// A new search takes 15–30 s at Booking.com, so it waits longer than other requests (spec FR-004).
  static const searchTimeout = Duration(seconds: 60);

  static final _day = DateFormat('yyyy-MM-dd');

  Future<CarPlaces> places(String destinationId) async {
    final response = await _dio.get<Map<String, dynamic>>('/destinations/$destinationId/car-places');
    return CarPlaces.fromJson(response.data!);
  }

  Future<CarResults> search(CarQuery query) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/destinations/${query.destinationId}/cars',
      queryParameters: {
        'from': _day.format(query.from),
        'to': _day.format(query.to),
        'place': query.place,
        'driverAge': query.driverAge,
        'currency': query.currency,
        ...query.filters.toQuery(),
        'page': query.page,
      },
      // `size`, `company` and `pickUpType` repeat: size=Mini&size=Compact. On the web the connect timeout lasts
      // until the response headers arrive, and the API sends them only when the search ends, so both are raised.
      options: Options(listFormat: ListFormat.multi, connectTimeout: searchTimeout, receiveTimeout: searchTimeout),
    );
    return CarResults.fromJson(response.data!);
  }
}

final carRepositoryProvider = Provider<CarRepository>((ref) => CarRepository(ref.watch(dioProvider)));
