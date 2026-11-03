import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/hotels/data/hotel_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Calls the pamplemousse hotel endpoints. Tests replace it through [hotelRepositoryProvider].
class HotelRepository {
  const HotelRepository(this._dio);

  final Dio _dio;

  static final _day = DateFormat('yyyy-MM-dd');

  Future<HotelResults> search(HotelQuery query) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/destinations/${query.destinationId}/hotels',
      queryParameters: {
        ..._stay(query.from, query.to, query.adults, query.currency),
        ...query.filters.toQuery(),
        'page': query.page,
      },
      // `stayType` repeats: stayType=Hotels&stayType=Apartments.
      options: Options(listFormat: ListFormat.multi),
    );
    return HotelResults.fromJson(response.data!);
  }

  Future<HotelDetails> details(HotelDetailsQuery query) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/hotels/${Uri.encodeComponent(query.hotelId)}',
      queryParameters: _stay(query.from, query.to, query.adults, query.currency),
    );
    return HotelDetails.fromJson(response.data!);
  }

  static Map<String, Object> _stay(DateTime from, DateTime to, int adults, String currency) => {
    'from': _day.format(from),
    'to': _day.format(to),
    'adults': adults,
    'currency': currency,
  };
}

final hotelRepositoryProvider = Provider<HotelRepository>((ref) => HotelRepository(ref.watch(dioProvider)));
