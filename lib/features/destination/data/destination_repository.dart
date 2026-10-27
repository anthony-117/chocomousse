import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import 'models.dart';

/// Calls the pamplemousse destination endpoints. Tests replace it through [destinationRepositoryProvider].
class DestinationRepository {
  const DestinationRepository(this._dio);

  final Dio _dio;

  static final _day = DateFormat('yyyy-MM-dd');

  Future<List<DestinationSummary>> search(String query) async {
    final response = await _dio.get<List<dynamic>>('/destinations', queryParameters: {'q': query, 'limit': 10});
    return response.data!.cast<Map<String, dynamic>>().map(DestinationSummary.fromJson).toList();
  }

  Future<DestinationSummary> destination(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/destinations/$id');
    return DestinationSummary.fromJson(response.data!['destination'] as Map<String, dynamic>);
  }

  Future<DestinationOverview> overview(
    String id, {
    required String passport,
    required String currency,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/destinations/$id/overview',
      queryParameters: {'passport': passport, 'currency': currency, 'from': _day.format(from), 'to': _day.format(to)},
    );
    return DestinationOverview.fromJson(response.data!);
  }

  Future<PlacesResult> places(String id, PlaceCategory category) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/destinations/$id/places',
      queryParameters: {'category': category.name},
    );
    return PlacesResult.fromJson(response.data!);
  }

  Future<Place> place(String placeId) async {
    final response = await _dio.get<Map<String, dynamic>>('/places/${Uri.encodeComponent(placeId)}');
    return Place.fromJson(response.data!);
  }

  Future<EventsResult> events(String id, {required DateTime from, required DateTime to}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/destinations/$id/events',
      queryParameters: {'from': _day.format(from), 'to': _day.format(to)},
    );
    return EventsResult.fromJson(response.data!);
  }

  Future<List<CountryOption>> countries() async {
    final response = await _dio.get<List<dynamic>>('/countries');
    return response.data!.cast<Map<String, dynamic>>().map(CountryOption.fromJson).toList();
  }
}

final destinationRepositoryProvider = Provider<DestinationRepository>(
  (ref) => DestinationRepository(ref.watch(dioProvider)),
);
