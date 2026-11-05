import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:chocomousse/features/hotels/data/hotel_models.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

typedef RankedHotels = RankedList<HotelOffer, HotelResults>;
typedef RankedFlights = RankedList<FlightFare, FlightResults>;
typedef RankedCars = RankedList<CarOffer, CarResults>;

/// Asks the existing hotel, flight and car endpoints for `sort=match` (API spec 007). Tests replace it through
/// [rankingRepositoryProvider].
class RankingRepository {
  const RankingRepository(this._dio);

  final Dio _dio;

  /// The first ranked hotel search for a city also counts the places near each hotel, and a car search takes 15–30 s
  /// at Booking.com, so both wait as long as the car screen does. On the web the connect timeout lasts until the
  /// headers arrive, so it is raised too.
  static const searchTimeout = Duration(seconds: 60);

  static final _day = DateFormat('yyyy-MM-dd');
  static final _slow = Options(connectTimeout: searchTimeout, receiveTimeout: searchTimeout);

  Map<String, Object> _common(RankedQuery q) => {
    'from': _day.format(q.from),
    'to': _day.format(q.to),
    'currency': q.currency,
    'sort': 'match',
    ...q.preferences.toQuery(),
  };

  Future<RankedHotels> hotels(RankedQuery q) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/destinations/${q.destinationId}/hotels',
      queryParameters: {..._common(q), 'adults': q.adults, 'page': 1},
      options: _slow,
    );
    final json = response.data!;
    final results = HotelResults.fromJson(json);
    return RankedList.fromJson(json, results: results, offers: results.items, id: (h) => h.id);
  }

  Future<RankedFlights> flights(RankedQuery q, String originId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/destinations/${q.destinationId}/flights',
      queryParameters: {..._common(q), 'origin': originId, 'tripType': FlightTripType.roundTrip.name, 'limit': 20},
    );
    final json = response.data!;
    final results = FlightResults.fromJson(json);
    return RankedList.fromJson(json, results: results, offers: results.items, id: (f) => f.id);
  }

  Future<RankedCars> cars(RankedQuery q) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/destinations/${q.destinationId}/cars',
      queryParameters: {..._common(q), 'place': 'centre', 'driverAge': q.driverAge, 'page': 1},
      options: _slow,
    );
    final json = response.data!;
    final results = CarResults.fromJson(json);
    return RankedList.fromJson(json, results: results, offers: results.items, id: (c) => c.id);
  }
}

final rankingRepositoryProvider = Provider<RankingRepository>((ref) => RankingRepository(ref.watch(dioProvider)));
