import 'package:flutter/foundation.dart';

/// How the API orders cars. The names are the API's values.
enum CarSort {
  recommended('Recommended'),
  price('Lowest price'),
  rating('Best rated');

  CarSort(this.label);

  final String label;
}

enum Gearbox {
  manual('Manual'),
  automatic('Automatic');

  Gearbox(this.label);

  final String label;

  static Gearbox? parse(String? value) => Gearbox.values.where((g) => g.name == value).firstOrNull;
}

/// Where at the pick-up place the car waits. The names are the API's values.
enum PickUpType {
  terminal('Airport terminal'),
  shuttle('Airport shuttle'),
  rentalCentre('Rental centre'),
  trainStation('Train station'),
  downtown('Downtown'),
  other('Other');

  PickUpType(this.label);

  final String label;

  /// A type the app doesn't know yet reads as [other], so a new value from the source can't break the screen.
  static PickUpType parse(String? value) => PickUpType.values.where((t) => t.name == value).firstOrNull ?? other;
}

/// Seat and bag minimums offered as filters (C2).
const carSeatChoices = [4, 5, 7];
const carBagChoices = [1, 2, 3];

/// Sort and filters for a search. The API applies them to its saved search; the app never filters cars itself.
@immutable
class CarFilters {
  const CarFilters({
    this.sort = CarSort.recommended,
    this.sizes = const [],
    this.gearbox,
    this.minSeats,
    this.minBags,
    this.maxPrice,
    this.pickUpTypes = const [],
    this.companies = const [],
    this.freeCancellation = false,
  });

  final CarSort sort;
  final List<String> sizes;
  final Gearbox? gearbox;
  final int? minSeats;
  final int? minBags;

  /// Whole number, total for the rental in the trip's currency.
  final int? maxPrice;
  final List<PickUpType> pickUpTypes;
  final List<String> companies;
  final bool freeCancellation;

  /// How many filters are on, for the Filters chip. The sort isn't a filter.
  int get activeCount => [
    sizes.isNotEmpty,
    gearbox != null,
    minSeats != null,
    minBags != null,
    maxPrice != null,
    pickUpTypes.isNotEmpty,
    companies.isNotEmpty,
    freeCancellation,
  ].where((on) => on).length;

  /// The API refuses a maximum of 0 or less.
  bool get maxPriceIsValid => maxPrice == null || maxPrice! > 0;

  /// The same sort with every filter off.
  CarFilters cleared() => CarFilters(sort: sort);

  CarFilters copyWith({
    CarSort? sort,
    List<String>? sizes,
    ValueGetter<Gearbox?>? gearbox,
    ValueGetter<int?>? minSeats,
    ValueGetter<int?>? minBags,
    ValueGetter<int?>? maxPrice,
    List<PickUpType>? pickUpTypes,
    List<String>? companies,
    bool? freeCancellation,
  }) => CarFilters(
    sort: sort ?? this.sort,
    sizes: sizes ?? this.sizes,
    gearbox: gearbox == null ? this.gearbox : gearbox(),
    minSeats: minSeats == null ? this.minSeats : minSeats(),
    minBags: minBags == null ? this.minBags : minBags(),
    maxPrice: maxPrice == null ? this.maxPrice : maxPrice(),
    pickUpTypes: pickUpTypes ?? this.pickUpTypes,
    companies: companies ?? this.companies,
    freeCancellation: freeCancellation ?? this.freeCancellation,
  );

  Map<String, Object> toQuery() => {
    'sort': sort.name,
    if (sizes.isNotEmpty) 'size': sizes,
    'gearbox': ?gearbox?.name,
    'minSeats': ?minSeats,
    'minBags': ?minBags,
    'maxPrice': ?maxPrice,
    if (pickUpTypes.isNotEmpty) 'pickUpType': [for (final t in pickUpTypes) t.name],
    if (companies.isNotEmpty) 'company': companies,
    if (freeCancellation) 'freeCancellation': true,
  };

  @override
  bool operator ==(Object other) =>
      other is CarFilters &&
      other.sort == sort &&
      listEquals(other.sizes, sizes) &&
      other.gearbox == gearbox &&
      other.minSeats == minSeats &&
      other.minBags == minBags &&
      other.maxPrice == maxPrice &&
      listEquals(other.pickUpTypes, pickUpTypes) &&
      listEquals(other.companies, companies) &&
      other.freeCancellation == freeCancellation;

  @override
  int get hashCode => Object.hash(
    sort,
    Object.hashAll(sizes),
    gearbox,
    minSeats,
    minBags,
    maxPrice,
    Object.hashAll(pickUpTypes),
    Object.hashAll(companies),
    freeCancellation,
  );
}

/// One car search. As a record it compares by value, so it can key a provider.
typedef CarQuery = ({
  String destinationId,
  DateTime from,
  DateTime to,
  String place,
  int driverAge,
  String currency,
  CarFilters filters,
  int page,
});

/// Where a car can be picked up and returned: the city centre or one of the city's airports.
class PickUpPlace {
  const PickUpPlace({required this.id, required this.isAirport, required this.name, required this.iata});

  factory PickUpPlace.fromJson(Map<String, dynamic> json) => PickUpPlace(
    id: json['id'] as String,
    isAirport: json['kind'] == 'airport',
    name: json['name'] as String,
    iata: json['iata'] as String?,
  );

  static const centreId = 'centre';
  static const centre = PickUpPlace(id: centreId, isAirport: false, name: 'City centre', iata: null);

  final String id;
  final bool isAirport;
  final String name;
  final String? iata;

  /// "Fiumicino Airport · FCO", or "City centre".
  String get label => iata == null ? name : '$name · $iata';
}

class CarPlaces {
  const CarPlaces({required this.places, required this.warnings});

  factory CarPlaces.fromJson(Map<String, dynamic> json) => CarPlaces(
    places: (json['places'] as List<dynamic>).cast<Map<String, dynamic>>().map(PickUpPlace.fromJson).toList(),
    warnings: (json['warnings'] as List<dynamic>).cast<String>(),
  );

  final List<PickUpPlace> places;
  final List<String> warnings;
}

/// An amount in its own currency, such as a deposit in EUR on a USD search.
class Money {
  const Money({required this.amount, required this.currency});

  factory Money.fromJson(Map<String, dynamic> json) =>
      Money(amount: json['amount'] as num, currency: json['currency'] as String);

  static Money? maybe(Object? json) => json is Map<String, dynamic> ? Money.fromJson(json) : null;

  final num amount;
  final String currency;
}

/// The normal Booking.com price for the whole rental.
class CarPrice {
  const CarPrice({required this.total, required this.perDay, required this.currency, required this.payNow});

  factory CarPrice.fromJson(Map<String, dynamic> json) => CarPrice(
    total: json['total'] as num,
    perDay: json['perDay'] as num,
    currency: json['currency'] as String,
    payNow: json['payNow'] as bool,
  );

  final num total;
  final num perDay;
  final String currency;

  /// Paid when booking; otherwise at pick-up.
  final bool payNow;
}

class RentalCompany {
  const RentalCompany({required this.name, required this.logoUrl, required this.rating, required this.reviewCount});

  factory RentalCompany.fromJson(Map<String, dynamic> json) => RentalCompany(
    name: json['name'] as String,
    logoUrl: json['logoUrl'] as String?,
    rating: (json['rating'] as num?)?.toDouble(),
    reviewCount: json['reviewCount'] as int?,
  );

  final String name;
  final String? logoUrl;
  final double? rating;
  final int? reviewCount;
}

class CarPickUp {
  const CarPickUp({required this.name, required this.type, required this.address, required this.distanceKm});

  factory CarPickUp.fromJson(Map<String, dynamic> json) => CarPickUp(
    name: json['name'] as String,
    type: PickUpType.parse(json['type'] as String?),
    address: json['address'] as String?,
    distanceKm: (json['distanceKm'] as num).toDouble(),
  );

  final String name;
  final PickUpType type;
  final String? address;

  /// From the destination's centre.
  final double distanceKm;
}

/// A car in the results. Missing values stay null, never 0 or false.
class CarOffer {
  const CarOffer({
    required this.id,
    required this.model,
    required this.orSimilar,
    required this.size,
    required this.photoUrl,
    required this.gearbox,
    required this.seats,
    required this.doors,
    required this.bags,
    required this.airCon,
    required this.mileage,
    required this.unlimitedMileage,
    required this.fuelPolicy,
    required this.company,
    required this.pickUp,
    required this.price,
    required this.freeCancellation,
    required this.deposit,
    required this.damageExcess,
    required this.sponsored,
    required this.bookingUrl,
  });

  factory CarOffer.fromJson(Map<String, dynamic> json) => CarOffer(
    id: json['id'] as String,
    model: json['model'] as String,
    orSimilar: json['orSimilar'] as String?,
    size: json['size'] as String,
    photoUrl: json['photoUrl'] as String?,
    gearbox: Gearbox.parse(json['gearbox'] as String?),
    seats: json['seats'] as int?,
    doors: json['doors'] as int?,
    bags: json['bags'] as int?,
    airCon: json['airCon'] as bool?,
    mileage: json['mileage'] as String?,
    unlimitedMileage: json['unlimitedMileage'] as bool?,
    fuelPolicy: json['fuelPolicy'] as String?,
    company: RentalCompany.fromJson(json['company'] as Map<String, dynamic>),
    pickUp: CarPickUp.fromJson(json['pickUp'] as Map<String, dynamic>),
    price: CarPrice.fromJson(json['price'] as Map<String, dynamic>),
    freeCancellation: json['freeCancellation'] as bool?,
    deposit: Money.maybe(json['deposit']),
    damageExcess: Money.maybe(json['damageExcess']),
    sponsored: json['sponsored'] as bool,
    bookingUrl: json['bookingUrl'] as String,
  );

  final String id;
  final String model;

  /// The source's words, such as "or similar large car".
  final String? orSimilar;
  final String size;
  final String? photoUrl;
  final Gearbox? gearbox;
  final int? seats;
  final int? doors;

  /// Checked bags.
  final int? bags;
  final bool? airCon;

  /// The source's words, such as "Unlimited km".
  final String? mileage;
  final bool? unlimitedMileage;
  final String? fuelPolicy;
  final RentalCompany company;
  final CarPickUp pickUp;
  final CarPrice price;
  final bool? freeCancellation;
  final Money? deposit;
  final Money? damageExcess;
  final bool sponsored;

  /// Booking.com's car search for the same place, dates and driver, not this car alone.
  final String bookingUrl;
}

/// A value of a filter with how many cars of the whole search have it.
class FilterOption {
  const FilterOption({required this.value, required this.count});

  factory FilterOption.fromJson(Map<String, dynamic> json) =>
      FilterOption(value: json['value'] as String, count: json['count'] as int);

  final String value;
  final int count;
}

class CarResults {
  const CarResults({
    required this.destinationName,
    required this.place,
    required this.from,
    required this.to,
    required this.days,
    required this.driverAge,
    required this.page,
    required this.totalItems,
    required this.totalPages,
    required this.pricesFetchedAt,
    required this.isSavedPrice,
    required this.mayHaveMore,
    required this.items,
    required this.sizes,
    required this.companies,
    required this.pickUpTypes,
    required this.driverNote,
    required this.message,
    required this.searchUrl,
    required this.warnings,
  });

  factory CarResults.fromJson(Map<String, dynamic> json) {
    final dates = json['dates'] as Map<String, dynamic>;
    final fetchedAt = json['pricesFetchedAt'] as String?;
    final options = json['filterOptions'] as Map<String, dynamic>;
    List<FilterOption> optionsOf(String key) =>
        (options[key] as List<dynamic>).cast<Map<String, dynamic>>().map(FilterOption.fromJson).toList();

    return CarResults(
      destinationName: (json['destination'] as Map<String, dynamic>)['name'] as String,
      place: PickUpPlace.fromJson(json['place'] as Map<String, dynamic>),
      from: DateTime.parse(dates['from'] as String),
      to: DateTime.parse(dates['to'] as String),
      days: dates['days'] as int,
      driverAge: json['driverAge'] as int,
      page: json['page'] as int,
      totalItems: json['totalItems'] as int,
      totalPages: json['totalPages'] as int,
      pricesFetchedAt: fetchedAt == null ? null : DateTime.parse(fetchedAt).toLocal(),
      isSavedPrice: json['isSavedPrice'] as bool,
      mayHaveMore: json['mayHaveMore'] as bool,
      items: (json['items'] as List<dynamic>).cast<Map<String, dynamic>>().map(CarOffer.fromJson).toList(),
      sizes: optionsOf('sizes'),
      companies: optionsOf('companies'),
      pickUpTypes: optionsOf('pickUpTypes'),
      driverNote: json['driverNote'] as String?,
      message: json['message'] as String?,
      searchUrl: json['searchUrl'] as String?,
      warnings: (json['warnings'] as List<dynamic>).cast<String>(),
    );
  }

  final String destinationName;
  final PickUpPlace place;
  final DateTime from;
  final DateTime to;
  final int days;
  final int driverAge;
  final int page;

  /// Cars matching the filters, across all pages.
  final int totalItems;
  final int totalPages;

  /// In the device's time.
  final DateTime? pricesFetchedAt;
  final bool isSavedPrice;

  /// The source returned its maximum, so Booking.com may have more cars.
  final bool mayHaveMore;
  final List<CarOffer> items;

  /// Filter values with their counts over the whole search, before filters.
  final List<FilterOption> sizes;
  final List<FilterOption> companies;
  final List<FilterOption> pickUpTypes;
  final String? driverNote;
  final String? message;
  final String? searchUrl;
  final List<String> warnings;

  /// All cars before filters: the filter options count each car once.
  int get searchedCount => sizes.fold(0, (sum, o) => sum + o.count);

  /// Booking.com's search for the same place, dates and driver; every car's link is this search.
  String? get bookingSearchUrl => searchUrl ?? items.firstOrNull?.bookingUrl;
}
