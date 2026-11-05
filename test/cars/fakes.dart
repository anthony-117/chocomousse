import 'dart:async';

import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:chocomousse/features/cars/data/car_repository.dart';

const carSearchUrl = 'https://www.booking.com/cars/search?loc=Rome&driverAge=30';

/// A car in a search, as returned by pamplemousse.
Map<String, Object?> carJson({
  String id = 'bk:car:1',
  String model = 'Fiat 600',
  String? orSimilar = 'or similar intermediate car',
  String size = 'Intermediate',
  String? photoUrl = 'https://cdn.rcstatic.com/images/car_images/fiat_600.jpg',
  String? gearbox = 'automatic',
  int? seats = 5,
  int? doors = 5,
  int? bags = 3,
  bool? airCon = true,
  String? mileage = 'Unlimited km',
  bool? unlimitedMileage = true,
  String? fuelPolicy = 'Like for like',
  String company = 'Budget',
  String? logoUrl = 'https://cdn.rcstatic.com/supplier_logos/budget.png',
  num? rating = 7.4,
  int? reviewCount = 372,
  String pickUpName = 'via Sardegna',
  String pickUpType = 'downtown',
  String? address = 'Via Sardegna 50, 00187 Rome',
  num distanceKm = 0.9,
  num total = 77,
  num perDay = 19.25,
  bool payNow = true,
  bool? freeCancellation = true,
  Map<String, Object?>? deposit = const {'amount': 300, 'currency': 'EUR'},
  Map<String, Object?>? damageExcess = const {'amount': 1200, 'currency': 'EUR'},
  bool sponsored = false,
}) => {
  'id': id,
  'model': model,
  'orSimilar': orSimilar,
  'size': size,
  'photoUrl': photoUrl,
  'gearbox': gearbox,
  'seats': seats,
  'doors': doors,
  'bags': bags,
  'airCon': airCon,
  'mileage': mileage,
  'unlimitedMileage': unlimitedMileage,
  'fuelPolicy': fuelPolicy,
  'company': {'name': company, 'logoUrl': logoUrl, 'rating': rating, 'reviewCount': reviewCount},
  'pickUp': {
    'name': pickUpName,
    'type': pickUpType,
    'address': address,
    'location': {'lat': 41.9, 'lng': 12.49},
    'distanceKm': distanceKm,
  },
  'price': {'total': total, 'perDay': perDay, 'currency': 'USD', 'payNow': payNow},
  'freeCancellation': freeCancellation,
  'deposit': deposit,
  'damageExcess': damageExcess,
  'sponsored': sponsored,
  'bookingUrl': carSearchUrl,
  'source': 'Booking.com',
};

Map<String, Object?> carResultsJson({
  List<Map<String, Object?>>? items,
  Map<String, Object?> place = const {'id': 'centre', 'kind': 'centre', 'name': 'City centre', 'iata': null},
  int page = 1,
  int totalPages = 3,
  int driverAge = 30,
  String? pricesFetchedAt = '2027-03-01T09:40:00Z',
  bool isSavedPrice = false,
  bool mayHaveMore = false,
  List<Map<String, Object?>> sizes = const [
    {'value': 'Small', 'count': 120},
    {'value': 'Intermediate', 'count': 295},
  ],
  List<Map<String, Object?>> companies = const [
    {'value': 'Budget', 'count': 40},
    {'value': 'Hertz', 'count': 35},
  ],
  List<Map<String, Object?>> pickUpTypes = const [
    {'value': 'downtown', 'count': 300},
    {'value': 'trainStation', 'count': 115},
  ],
  String? driverNote,
  String? message,
  String? searchUrl = carSearchUrl,
  List<String> warnings = const [],
}) => {
  'destination': {'id': '3169070', 'name': 'Rome'},
  'place': place,
  'dates': {'from': '2027-04-10', 'to': '2027-04-14', 'days': 4, 'pickUpTime': '10:00', 'returnTime': '10:00'},
  'driverAge': driverAge,
  'currency': 'USD',
  'sort': 'recommended',
  'page': page,
  'totalItems': 415,
  'totalPages': totalPages,
  'pricesFetchedAt': pricesFetchedAt,
  'isSavedPrice': isSavedPrice,
  'mayHaveMore': mayHaveMore,
  'items': items ?? [carJson()],
  'filterOptions': {'sizes': sizes, 'companies': companies, 'pickUpTypes': pickUpTypes},
  'driverNote': driverNote,
  'message': message,
  'searchUrl': searchUrl,
  'warnings': warnings,
};

Map<String, Object?> carPlacesJson({List<String> warnings = const []}) => {
  'places': [
    {'id': 'centre', 'kind': 'centre', 'name': 'City centre', 'iata': null, 'location': null},
    {
      'id': 'FCO',
      'kind': 'airport',
      'name': 'Fiumicino Airport',
      'iata': 'FCO',
      'location': {'lat': 41.8, 'lng': 12.25},
    },
    {
      'id': 'CIA',
      'kind': 'airport',
      'name': 'Ciampino Airport',
      'iata': 'CIA',
      'location': {'lat': 41.79, 'lng': 12.59},
    },
  ],
  'warnings': warnings,
};

/// Configurable stand-in for the API that records each request.
class FakeCarRepository implements CarRepository {
  FakeCarRepository({CarResults? results, CarPlaces? places, this.error, this.placesError})
    : results = results ?? CarResults.fromJson(carResultsJson()),
      placeList = places ?? CarPlaces.fromJson(carPlacesJson());

  CarResults results;
  CarPlaces placeList;
  Exception? error;
  Exception? placesError;

  /// When set, searches wait for it, so a test can look at the searching state.
  Completer<void>? gate;

  final queries = <CarQuery>[];
  int placeRequests = 0;

  @override
  Future<CarPlaces> places(String destinationId) async {
    placeRequests++;
    final failure = placesError;
    if (failure != null) throw failure;
    return placeList;
  }

  @override
  Future<CarResults> search(CarQuery query) async {
    queries.add(query);
    await gate?.future;
    final failure = error;
    if (failure != null) throw failure;
    return results;
  }
}
