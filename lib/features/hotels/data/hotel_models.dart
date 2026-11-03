import 'package:flutter/foundation.dart';

/// How the API orders hotels. The names are the API's values.
enum HotelSort {
  recommended('Recommended'),
  price('Lowest price'),
  review('Best reviewed'),
  stars('Most stars'),
  distance('Closest to centre');

  HotelSort(this.label);

  final String label;
}

/// Stay types offered as filters, with the names Booking.com uses.
const hotelStayTypes = ['Hotels', 'Apartments', 'Guest houses', 'Hostels'];

/// Sort and filters for a search. The API applies them; the app never filters hotels itself.
@immutable
class HotelFilters {
  const HotelFilters({
    this.sort = HotelSort.recommended,
    this.minStars,
    this.minReview,
    this.minPrice,
    this.maxPrice,
    this.stayTypes = const [],
    this.freeCancellation = false,
  });

  final HotelSort sort;
  final int? minStars;
  final int? minReview;
  final int? minPrice;
  final int? maxPrice;
  final List<String> stayTypes;
  final bool freeCancellation;

  /// How many filters are on, for the Filters button. The sort isn't a filter.
  int get activeCount => [
    minStars != null,
    minReview != null,
    minPrice != null || maxPrice != null,
    stayTypes.isNotEmpty,
    freeCancellation,
  ].where((on) => on).length;

  /// The API checks these against each hotel's details, so it reports how many it could check.
  bool get needsDetails => stayTypes.isNotEmpty || freeCancellation;

  bool get priceRangeIsValid => minPrice == null || maxPrice == null || minPrice! <= maxPrice!;

  /// The same sort with every filter off.
  HotelFilters cleared() => HotelFilters(sort: sort);

  HotelFilters copyWith({
    HotelSort? sort,
    ValueGetter<int?>? minStars,
    ValueGetter<int?>? minReview,
    ValueGetter<int?>? minPrice,
    ValueGetter<int?>? maxPrice,
    List<String>? stayTypes,
    bool? freeCancellation,
  }) => HotelFilters(
    sort: sort ?? this.sort,
    minStars: minStars == null ? this.minStars : minStars(),
    minReview: minReview == null ? this.minReview : minReview(),
    minPrice: minPrice == null ? this.minPrice : minPrice(),
    maxPrice: maxPrice == null ? this.maxPrice : maxPrice(),
    stayTypes: stayTypes ?? this.stayTypes,
    freeCancellation: freeCancellation ?? this.freeCancellation,
  );

  Map<String, Object> toQuery() => {
    'sort': sort.name,
    'minStars': ?minStars,
    'minReview': ?minReview,
    'minPrice': ?minPrice,
    'maxPrice': ?maxPrice,
    if (stayTypes.isNotEmpty) 'stayType': stayTypes,
    if (freeCancellation) 'freeCancellation': true,
  };

  @override
  bool operator ==(Object other) =>
      other is HotelFilters &&
      other.sort == sort &&
      other.minStars == minStars &&
      other.minReview == minReview &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      listEquals(other.stayTypes, stayTypes) &&
      other.freeCancellation == freeCancellation;

  @override
  int get hashCode =>
      Object.hash(sort, minStars, minReview, minPrice, maxPrice, Object.hashAll(stayTypes), freeCancellation);
}

/// One hotel search. As a record it compares by value, so it can key a provider.
typedef HotelQuery = ({
  String destinationId,
  DateTime from,
  DateTime to,
  int adults,
  String currency,
  HotelFilters filters,
  int page,
});

/// One hotel's details for a stay.
typedef HotelDetailsQuery = ({String hotelId, DateTime from, DateTime to, int adults, String currency});

/// Total for the stay, with taxes and fees, for a room that fits the adults.
class HotelPrice {
  const HotelPrice({required this.total, required this.perNight, required this.currency});

  factory HotelPrice.fromJson(Map<String, dynamic> json) =>
      HotelPrice(total: json['total'] as num, perNight: json['perNight'] as num, currency: json['currency'] as String);

  final num total;
  final num perNight;
  final String currency;
}

/// A hotel in the results. Missing stars, reviews, stay type and free cancellation stay null, never 0 or false.
class HotelOffer {
  const HotelOffer({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.stars,
    required this.reviewScore,
    required this.reviewCount,
    required this.distanceKm,
    required this.nearCity,
    required this.freeCancellation,
    required this.price,
  });

  factory HotelOffer.fromJson(Map<String, dynamic> json) => HotelOffer(
    id: json['id'] as String,
    name: json['name'] as String,
    photoUrl: json['photoUrl'] as String?,
    stars: json['stars'] as int?,
    reviewScore: (json['reviewScore'] as num?)?.toDouble(),
    reviewCount: json['reviewCount'] as int?,
    distanceKm: (json['distanceKm'] as num).toDouble(),
    nearCity: json['nearCity'] as bool,
    freeCancellation: json['freeCancellation'] as bool?,
    price: HotelPrice.fromJson(json['price'] as Map<String, dynamic>),
  );

  final String id;
  final String name;
  final String? photoUrl;
  final int? stars;
  final double? reviewScore;
  final int? reviewCount;

  /// From the destination's position.
  final double distanceKm;

  /// More than 10 km from the destination.
  final bool nearCity;
  final bool? freeCancellation;
  final HotelPrice price;
}

class HotelResults {
  const HotelResults({
    required this.destinationName,
    required this.sourceName,
    required this.nights,
    required this.page,
    required this.totalPages,
    required this.pricesFetchedAt,
    required this.isSavedPrice,
    required this.items,
    required this.filtersCheckedOn,
    required this.message,
    required this.searchUrl,
    required this.warnings,
  });

  factory HotelResults.fromJson(Map<String, dynamic> json) {
    final destination = json['destination'] as Map<String, dynamic>;
    final fetchedAt = json['pricesFetchedAt'] as String?;
    return HotelResults(
      destinationName: destination['name'] as String,
      sourceName: destination['sourceName'] as String?,
      nights: (json['dates'] as Map<String, dynamic>)['nights'] as int,
      page: json['page'] as int,
      totalPages: json['totalPages'] as int,
      pricesFetchedAt: fetchedAt == null ? null : DateTime.parse(fetchedAt).toLocal(),
      isSavedPrice: json['isSavedPrice'] as bool,
      items: (json['items'] as List<dynamic>).cast<Map<String, dynamic>>().map(HotelOffer.fromJson).toList(),
      filtersCheckedOn: json['filtersCheckedOn'] as int?,
      message: json['message'] as String?,
      searchUrl: json['searchUrl'] as String?,
      warnings: (json['warnings'] as List<dynamic>).cast<String>(),
    );
  }

  final String destinationName;

  /// The city the source searched, when it isn't the destination's name.
  final String? sourceName;
  final int nights;
  final int page;
  final int totalPages;

  /// In the device's time.
  final DateTime? pricesFetchedAt;
  final bool isSavedPrice;
  final List<HotelOffer> items;
  final int? filtersCheckedOn;
  final String? message;
  final String? searchUrl;
  final List<String> warnings;

  bool get hasNextPage => page < totalPages;
}

class HotelDetails {
  const HotelDetails({
    required this.id,
    required this.name,
    required this.photoUrls,
    required this.stars,
    required this.reviewScore,
    required this.reviewCount,
    required this.reviewWord,
    required this.address,
    required this.district,
    required this.distanceToCentreKm,
    required this.stayType,
    required this.freeCancellation,
    required this.breakfastIncluded,
    required this.checkInFrom,
    required this.checkOutUntil,
    required this.facilities,
    required this.languages,
    required this.price,
    required this.priceFetchedAt,
    required this.bookingUrl,
    required this.warnings,
  });

  factory HotelDetails.fromJson(Map<String, dynamic> json) {
    final price = json['price'] as Map<String, dynamic>?;
    final fetchedAt = json['priceFetchedAt'] as String?;
    return HotelDetails(
      id: json['id'] as String,
      name: json['name'] as String,
      photoUrls: (json['photoUrls'] as List<dynamic>).cast<String>(),
      stars: json['stars'] as int?,
      reviewScore: (json['reviewScore'] as num?)?.toDouble(),
      reviewCount: json['reviewCount'] as int?,
      reviewWord: json['reviewWord'] as String?,
      address: json['address'] as String?,
      district: json['district'] as String?,
      distanceToCentreKm: (json['distanceToCentreKm'] as num?)?.toDouble(),
      stayType: json['stayType'] as String?,
      freeCancellation: json['freeCancellation'] as bool?,
      breakfastIncluded: json['breakfastIncluded'] as bool?,
      checkInFrom: json['checkInFrom'] as String?,
      checkOutUntil: json['checkOutUntil'] as String?,
      facilities: (json['facilities'] as List<dynamic>).cast<String>(),
      languages: (json['languages'] as List<dynamic>).cast<String>(),
      price: price == null ? null : HotelPrice.fromJson(price),
      priceFetchedAt: fetchedAt == null ? null : DateTime.parse(fetchedAt).toLocal(),
      bookingUrl: json['bookingUrl'] as String,
      warnings: (json['warnings'] as List<dynamic>).cast<String>(),
    );
  }

  final String id;
  final String name;
  final List<String> photoUrls;
  final int? stars;
  final double? reviewScore;
  final int? reviewCount;
  final String? reviewWord;
  final String? address;
  final String? district;
  final double? distanceToCentreKm;
  final String? stayType;
  final bool? freeCancellation;
  final bool? breakfastIncluded;
  final String? checkInFrom;
  final String? checkOutUntil;
  final List<String> facilities;

  /// Codes such as `en-gb`; see `languageName`.
  final List<String> languages;

  /// Null when the last search price was for other dates, adults or currency.
  final HotelPrice? price;
  final DateTime? priceFetchedAt;
  final String bookingUrl;
  final List<String> warnings;
}
