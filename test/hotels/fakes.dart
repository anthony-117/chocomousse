import 'dart:async';

import 'package:chocomousse/features/hotels/data/hotel_models.dart';
import 'package:chocomousse/features/hotels/data/hotel_repository.dart';

/// A hotel in a search, as returned by pamplemousse.
Map<String, Object?> hotelJson({
  String id = 'bk:1',
  String name = 'Hotel Artemide',
  String? photoUrl = 'https://cf.bstatic.com/square500/1.jpg',
  int? stars = 4,
  num? reviewScore = 8.9,
  int? reviewCount = 3214,
  num distanceKm = 1.1,
  bool nearCity = false,
  bool? freeCancellation = true,
  num total = 812.4,
  num perNight = 203.1,
}) => {
  'id': id,
  'name': name,
  'photoUrl': photoUrl,
  'stars': stars,
  'reviewScore': reviewScore,
  'reviewCount': reviewCount,
  'location': {'lat': 41.9, 'lng': 12.49},
  'distanceKm': distanceKm,
  'nearCity': nearCity,
  'stayType': null,
  'freeCancellation': freeCancellation,
  'price': {'total': total, 'perNight': perNight, 'currency': 'USD'},
  'source': 'Booking.com',
};

Map<String, Object?> hotelResultsJson({
  List<Map<String, Object?>>? items,
  String name = 'Rome',
  String? sourceName,
  int page = 1,
  int totalPages = 3,
  String? pricesFetchedAt = '2027-03-01T09:40:00Z',
  bool isSavedPrice = false,
  int? filtersCheckedOn,
  String? message,
  String? searchUrl,
  List<String> warnings = const [],
}) => {
  'destination': {'id': '3169070', 'name': name, 'sourceName': sourceName},
  'dates': {'from': '2027-04-10', 'to': '2027-04-14', 'nights': 4},
  'adults': 2,
  'currency': 'USD',
  'sort': 'recommended',
  'page': page,
  'totalItems': 20,
  'totalPages': totalPages,
  'pricesFetchedAt': pricesFetchedAt,
  'isSavedPrice': isSavedPrice,
  'items': items ?? [hotelJson()],
  'filtersCheckedOn': filtersCheckedOn,
  'message': message,
  'searchUrl': searchUrl,
  'warnings': warnings,
};

Map<String, Object?> hotelDetailsJson({
  Map<String, Object?>? price = const {'total': 812.4, 'perNight': 203.1, 'currency': 'USD'},
  String? checkInFrom = '14:00',
  String? checkOutUntil = '12:00',
  bool? breakfastIncluded = true,
  List<String> warnings = const [],
}) => {
  'id': 'bk:1',
  'name': 'Hotel Artemide',
  'photoUrls': ['https://cf.bstatic.com/square500/1.jpg', 'https://cf.bstatic.com/square500/2.jpg'],
  'stars': 4,
  'starsEstimated': false,
  'reviewScore': 8.9,
  'reviewCount': 3214,
  'reviewWord': 'Fabulous',
  'location': {'lat': 41.9, 'lng': 12.49},
  'address': 'Via Nazionale 22, 00184 Rome',
  'district': 'Monti',
  'distanceToCentreKm': 1.1,
  'stayType': 'Hotels',
  'freeCancellation': true,
  'breakfastIncluded': breakfastIncluded,
  'checkInFrom': checkInFrom,
  'checkInUntil': '23:00',
  'checkOutFrom': '07:00',
  'checkOutUntil': checkOutUntil,
  'facilities': ['Free WiFi', 'Air conditioning'],
  'languages': ['en-gb', 'it', 'xx'],
  'price': price,
  'priceFetchedAt': '2027-03-01T09:40:00Z',
  'bookingUrl': 'https://www.booking.com/hotel/it/artemide.html?checkin=2027-04-10',
  'detailsFetchedAt': '2027-03-01T09:41:00Z',
  'source': 'Booking.com',
  'warnings': warnings,
};

/// Configurable stand-in for the API that records each request.
class FakeHotelRepository implements HotelRepository {
  FakeHotelRepository({HotelResults? results, HotelDetails? hotel, this.error})
    : results = results ?? HotelResults.fromJson(hotelResultsJson()),
      hotel = hotel ?? HotelDetails.fromJson(hotelDetailsJson());

  HotelResults results;
  HotelDetails hotel;
  Exception? error;

  /// When set, requests wait for it, so a test can look at the loading state.
  Completer<void>? gate;

  final queries = <HotelQuery>[];
  final detailQueries = <HotelDetailsQuery>[];

  @override
  Future<HotelResults> search(HotelQuery query) async {
    queries.add(query);
    await gate?.future;
    final failure = error;
    if (failure != null) throw failure;
    return results;
  }

  @override
  Future<HotelDetails> details(HotelDetailsQuery query) async {
    detailQueries.add(query);
    await gate?.future;
    final failure = error;
    if (failure != null) throw failure;
    return hotel;
  }
}
