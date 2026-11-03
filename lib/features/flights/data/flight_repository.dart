import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Calls the pamplemousse flights endpoint. Tests replace it through [flightRepositoryProvider].
class FlightRepository {
  const FlightRepository(this._dio);

  final Dio _dio;

  static final _day = DateFormat('yyyy-MM-dd');

  Future<FlightResults> search(FlightQuery query) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/destinations/${query.destinationId}/flights',
      queryParameters: {
        'origin': query.originId,
        'from': _day.format(query.from),
        if (query.tripType == FlightTripType.roundTrip) 'to': _day.format(query.to),
        'tripType': query.tripType.name,
        'directOnly': query.directOnly,
        'currency': query.currency,
      },
    );
    return FlightResults.fromJson(response.data!);
  }
}

final flightRepositoryProvider = Provider<FlightRepository>((ref) => FlightRepository(ref.watch(dioProvider)));

/// True when the API refused the search because both cities use the same flight city.
bool isSameCityError(Object error) {
  if (error is! DioException || error.response?.statusCode != 400) return false;
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return false;
  final errors = data['errors'];
  return errors is Map<String, dynamic> && errors.containsKey('origin');
}
