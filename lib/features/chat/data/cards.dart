import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:chocomousse/features/destination/data/models.dart';
import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:chocomousse/features/hotels/data/hotel_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:flutter/foundation.dart';

/// The cards the assistant answers with (API spec 010, "Cards"). Every card has the same envelope; `item` is read
/// with the list parser of its kind. Unknown kinds and broken items are skipped, never a crash.
sealed class AssistantCard {
  const AssistantCard({
    required this.id,
    required this.lat,
    required this.lng,
    required this.approximate,
    required this.raw,
    this.foundAt,
  });

  /// The card, or null for an unknown `kind` or an item that doesn't parse.
  static AssistantCard? fromJson(Map<String, dynamic> json) {
    try {
      final item = json['item'];
      if (item is! Map<String, dynamic>) return null;
      final id = json['id']! as String;
      final lat = (json['lat'] as num?)?.toDouble() ?? 0;
      final lng = (json['lng'] as num?)?.toDouble() ?? 0;
      final approximate = json['approximate'] as bool? ?? false;
      final foundAt = json['foundAt'] is String ? DateTime.parse(json['foundAt'] as String) : null;
      final match = item['match'] is Map<String, dynamic>
          ? Match.fromJson(item['match'] as Map<String, dynamic>)
          : null;
      return switch (json['kind']) {
        'plan' => PlanCard(
          PlanSummary.fromJson(item),
          id: id,
          lat: lat,
          lng: lng,
          approximate: approximate,
          foundAt: foundAt,
          raw: json,
        ),
        'flight' => FlightCard(
          FlightFare.fromJson(item),
          match,
          id: id,
          lat: lat,
          lng: lng,
          approximate: approximate,
          foundAt: foundAt,
          raw: json,
        ),
        'hotel' => HotelCard(
          HotelOffer.fromJson(item),
          match,
          id: id,
          lat: lat,
          lng: lng,
          approximate: approximate,
          foundAt: foundAt,
          raw: json,
        ),
        'car' => CarCard(
          CarOffer.fromJson(item),
          match,
          id: id,
          lat: lat,
          lng: lng,
          approximate: approximate,
          foundAt: foundAt,
          raw: json,
        ),
        'place' => PlaceCard(
          Place.fromJson(item),
          id: id,
          lat: lat,
          lng: lng,
          approximate: approximate,
          foundAt: foundAt,
          raw: json,
        ),
        'event' => EventCard(
          TravelEvent.fromJson(item),
          GeoPoint.fromJsonOrNull(item['location']),
          id: id,
          lat: lat,
          lng: lng,
          approximate: approximate,
          foundAt: foundAt,
          raw: json,
        ),
        'facts' => FactsCard(
          TravelFacts.fromJson(item),
          id: id,
          lat: lat,
          lng: lng,
          approximate: approximate,
          foundAt: foundAt,
          raw: json,
        ),
        _ => null,
      };
      // A broken item from the API is skipped like an unknown kind (spec 003), so a cast failure is expected here.
      // ignore: avoid_catching_errors
    } on TypeError {
      return null;
    } on FormatException {
      return null;
    }
  }

  final String id;
  final double lat;
  final double lng;

  /// The position is a city centre, not the place itself.
  final bool approximate;
  final DateTime? foundAt;

  /// The card's JSON as it came, kept so a saved item can be sent back as the contract asks.
  final Map<String, dynamic> raw;

  /// The API's `kind`.
  String get kind;

  /// The card's name, as lists and the map show it.
  String get title;
}

/// The cards of a JSON list, skipping those [AssistantCard.fromJson] can't read.
List<AssistantCard> readCards(Object? json) => json is List
    ? json.whereType<Map<String, dynamic>>().map(AssistantCard.fromJson).whereType<AssistantCard>().toList()
    : const [];

class PlanCard extends AssistantCard {
  const PlanCard(
    this.plan, {
    required super.id,
    required super.lat,
    required super.lng,
    required super.approximate,
    required super.raw,
    super.foundAt,
  });

  final PlanSummary plan;

  @override
  String get kind => 'plan';

  @override
  String get title => plan.name;
}

class FlightCard extends AssistantCard {
  const FlightCard(
    this.fare,
    this.match, {
    required super.id,
    required super.lat,
    required super.lng,
    required super.approximate,
    required super.raw,
    super.foundAt,
  });

  final FlightFare fare;

  /// Null when no match was computed: no badge then, never "0 %".
  final Match? match;

  @override
  String get kind => 'flight';

  @override
  String get title => '${fare.originAirport} → ${fare.destinationAirport}';
}

class HotelCard extends AssistantCard {
  const HotelCard(
    this.hotel,
    this.match, {
    required super.id,
    required super.lat,
    required super.lng,
    required super.approximate,
    required super.raw,
    super.foundAt,
  });

  final HotelOffer hotel;
  final Match? match;

  @override
  String get kind => 'hotel';

  @override
  String get title => hotel.name;
}

class CarCard extends AssistantCard {
  const CarCard(
    this.car,
    this.match, {
    required super.id,
    required super.lat,
    required super.lng,
    required super.approximate,
    required super.raw,
    super.foundAt,
  });

  final CarOffer car;
  final Match? match;

  @override
  String get kind => 'car';

  @override
  String get title => car.model;
}

class PlaceCard extends AssistantCard {
  const PlaceCard(
    this.place, {
    required super.id,
    required super.lat,
    required super.lng,
    required super.approximate,
    required super.raw,
    super.foundAt,
  });

  final Place place;

  @override
  String get kind => 'place';

  @override
  String get title => place.name;
}

class EventCard extends AssistantCard {
  const EventCard(
    this.event,
    this.location, {
    required super.id,
    required super.lat,
    required super.lng,
    required super.approximate,
    required super.raw,
    super.foundAt,
  });

  final TravelEvent event;

  /// The venue, when the event source gave one.
  final GeoPoint? location;

  @override
  String get kind => 'event';

  @override
  String get title => event.name;
}

class FactsCard extends AssistantCard {
  const FactsCard(
    this.facts, {
    required super.id,
    required super.lat,
    required super.lng,
    required super.approximate,
    required super.raw,
    super.foundAt,
  });

  final TravelFacts facts;

  @override
  String get kind => 'facts';

  @override
  String get title => facts.destination.name;
}

@immutable
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  static GeoPoint? fromJsonOrNull(Object? json) => json is Map<String, dynamic>
      ? GeoPoint((json['lat']! as num).toDouble(), (json['lng']! as num).toDouble())
      : null;

  final double lat;
  final double lng;
}

/// The destination of a facts card.
@immutable
class FactsDestination {
  const FactsDestination({required this.id, required this.name, this.countryCode});

  factory FactsDestination.fromJson(Map<String, dynamic> json) => FactsDestination(
    id: json['id']! as String,
    name: json['name']! as String,
    countryCode: json['countryCode'] as String?,
  );

  final String id;
  final String name;
  final String? countryCode;
}

/// One weather line for the trip's dates.
@immutable
class FactsWeather {
  const FactsWeather({required this.kind, required this.summary, this.maxC, this.minC, this.rainChance});

  factory FactsWeather.fromJson(Map<String, dynamic> json) => FactsWeather(
    kind: json['kind'] as String? ?? 'forecast',
    summary: json['summary'] as String? ?? '',
    maxC: (json['maxC'] as num?)?.round(),
    minC: (json['minC'] as num?)?.round(),
    rainChance: (json['rainChance'] as num?)?.round(),
  );

  /// `forecast`, or `climate` (the month's averages) when the dates are too far off.
  final String kind;
  final String summary;
  final int? maxC;
  final int? minC;
  final int? rainChance;
}

/// The exchange rate of a facts card (`from` → `to`).
@immutable
class FactsCurrency {
  const FactsCurrency({required this.from, required this.to, required this.rate, this.date});

  factory FactsCurrency.fromJson(Map<String, dynamic> json) => FactsCurrency(
    from: json['from']! as String,
    to: json['to']! as String,
    rate: (json['rate']! as num).toDouble(),
    date: json['date'] is String ? DateTime.parse(json['date'] as String) : null,
  );

  final String from;
  final String to;
  final double rate;
  final DateTime? date;
}

/// Travel facts for a trip. Each part is null when its source had nothing.
@immutable
class TravelFacts {
  const TravelFacts({
    required this.destination,
    this.from,
    this.to,
    this.weather,
    this.visa,
    this.currency,
    this.safety,
    this.holidays = const [],
  });

  factory TravelFacts.fromJson(Map<String, dynamic> json) => TravelFacts(
    destination: FactsDestination.fromJson(json['destination']! as Map<String, dynamic>),
    from: json['from'] is String ? DateTime.parse(json['from'] as String) : null,
    to: json['to'] is String ? DateTime.parse(json['to'] as String) : null,
    weather: _map(json['weather'], FactsWeather.fromJson),
    visa: _map(json['visa'], VisaRequirement.fromJson),
    currency: _map(json['currency'], FactsCurrency.fromJson),
    safety: _map(json['safety'], TravelAdvisory.fromJson),
    holidays: json['holidays'] is List
        ? (json['holidays'] as List).whereType<Map<String, dynamic>>().map(Holiday.fromJson).toList()
        : const [],
  );

  final FactsDestination destination;
  final DateTime? from;
  final DateTime? to;
  final FactsWeather? weather;
  final VisaRequirement? visa;
  final FactsCurrency? currency;
  final TravelAdvisory? safety;
  final List<Holiday> holidays;
}

T? _map<T>(Object? json, T Function(Map<String, dynamic>) read) => json is Map<String, dynamic> ? read(json) : null;
