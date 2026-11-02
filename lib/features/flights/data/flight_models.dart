/// Round trip or one way. The names are the API's values.
enum FlightTripType { roundTrip, oneWay }

/// How closely a fare matches the requested dates. The names are the API's values.
enum FlightDateMatch {
  exact(null),
  nearby('Nearby dates'),
  sameMonth('Same month'),
  anyReturn('Different return'),
  other(null);

  FlightDateMatch(this.label);

  /// Shown on a fare that is not on the exact dates.
  final String? label;

  /// A value this version of the app doesn't know shows no label; the API's message still explains it.
  static FlightDateMatch parse(String? value) => values.asNameMap()[value] ?? other;
}

/// One flight search. As a record it compares by value, so it can key a provider.
typedef FlightQuery = ({
  String destinationId,
  String originId,
  DateTime from,
  DateTime to,
  String currency,
  FlightTripType tripType,
  bool directOnly,
});

/// A city in a search, and the city whose airports are used for it.
class FlightCity {
  const FlightCity({required this.name, required this.flightCity, required this.isNearby, required this.distanceKm});

  factory FlightCity.fromJson(Map<String, dynamic> json) => FlightCity(
    name: json['name'] as String,
    flightCity: json['flightCity'] as String?,
    isNearby: json['isNearby'] as bool,
    distanceKm: (json['distanceKm'] as num?)?.round(),
  );

  final String name;
  final String? flightCity;
  final bool isNearby;
  final int? distanceKm;

  /// Says which city is used when this one has no airport of its own.
  String? get nearbyNote => isNearby && flightCity != null
      ? '$name has no airport, so we use $flightCity${distanceKm == null ? '' : ' ($distanceKm km away)'}.'
      : null;
}

/// One priced option. The source's airline and flight number are often wrong (spec 001-flight-screen), so they are
/// not read here, and the screen can't show them by accident.
class FlightFare {
  const FlightFare({
    required this.id,
    required this.originAirport,
    required this.destinationAirport,
    required this.departureAt,
    required this.returnAt,
    required this.stops,
    required this.returnStops,
    required this.durationMinutes,
    required this.amount,
    required this.currency,
    required this.bookingUrl,
    required this.dateMatch,
  });

  factory FlightFare.fromJson(Map<String, dynamic> json) {
    final price = json['price'] as Map<String, dynamic>;
    final returnAt = json['returnAt'] as String?;
    return FlightFare(
      id: json['id'] as String,
      originAirport: json['originAirport'] as String,
      destinationAirport: json['destinationAirport'] as String,
      departureAt: _airportTime(json['departureAt'] as String),
      returnAt: returnAt == null ? null : _airportTime(returnAt),
      stops: json['stops'] as int,
      returnStops: json['returnStops'] as int?,
      durationMinutes: json['durationMinutes'] as int?,
      amount: price['amount'] as num,
      currency: price['currency'] as String,
      bookingUrl: json['bookingUrl'] as String,
      dateMatch: FlightDateMatch.parse(json['dateMatch'] as String?),
    );
  }

  final String id;
  final String originAirport;
  final String destinationAirport;

  /// Local time at the airport, as written in the API's value. Its offset is dropped on purpose.
  final DateTime departureAt;
  final DateTime? returnAt;
  final int stops;
  final int? returnStops;
  final int? durationMinutes;
  final num amount;
  final String currency;
  final String bookingUrl;
  final FlightDateMatch dateMatch;

  /// Checks the whole value, then keeps its date and time without the offset, so `DateTime` can't convert it.
  static DateTime _airportTime(String value) {
    DateTime.parse(value);
    return DateTime.parse(value.substring(0, 19));
  }
}

class FlightResults {
  const FlightResults({
    required this.origin,
    required this.destination,
    required this.items,
    required this.priceNote,
    required this.message,
    required this.searchUrl,
    required this.warnings,
  });

  factory FlightResults.fromJson(Map<String, dynamic> json) => FlightResults(
    origin: FlightCity.fromJson(json['origin'] as Map<String, dynamic>),
    destination: FlightCity.fromJson(json['destination'] as Map<String, dynamic>),
    items: (json['items'] as List<dynamic>).cast<Map<String, dynamic>>().map(FlightFare.fromJson).toList(),
    priceNote: json['priceNote'] as String,
    message: json['message'] as String?,
    searchUrl: json['searchUrl'] as String?,
    warnings: (json['warnings'] as List<dynamic>).cast<String>(),
  );

  final FlightCity origin;
  final FlightCity destination;
  final List<FlightFare> items;
  final String priceNote;
  final String? message;
  final String? searchUrl;
  final List<String> warnings;
}
