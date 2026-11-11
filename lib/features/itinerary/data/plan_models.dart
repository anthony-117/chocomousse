import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:chocomousse/features/hotels/data/hotel_models.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:flutter/foundation.dart';

/// Read as the API writes them (contract of API spec 008). Unknown values never crash: they read as `other`.
enum PlanStatus {
  draft('Draft'),
  planned('Planned');

  PlanStatus(this.label);

  final String label;

  static PlanStatus parse(String? value) => values.asNameMap()[value] ?? draft;
}

/// The hotel, flight or car of a plan. The names are the API's route values.
enum OfferKind {
  hotel('hotels'),
  flight('flights'),
  car('cars');

  OfferKind(this.listName);

  /// The value of `/alternatives/{kind}`.
  final String listName;

  static OfferKind? parse(String? value) => values.asNameMap()[value];
}

enum ItemKind { arrival, departure, sight, nature, restaurant, nightlife, event, freeTime, other }

enum RefKind { place, event, flight, hotel, other }

enum MatchPartKind {
  hotel('Hotel'),
  flight('Flight'),
  car('Car'),
  days('Your days'),
  other('Other');

  MatchPartKind(this.label);

  final String label;
}

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) => values.asNameMap()[name] ?? fallback;

DateTime _date(Object? value) => DateTime.parse(value! as String);

DateTime? _time(Object? value) => value == null ? null : DateTime.parse(value as String);

double _double(Object? value) => (value as num?)?.toDouble() ?? 0;

num? _num(Object? value) => value as num?;

List<Map<String, dynamic>> _list(Object? value) => (value as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

/// What an item is a copy of: a place, an event, the flight or the hotel.
@immutable
class ItemRef {
  const ItemRef({required this.kind, required this.id, this.lat, this.lng, this.imageUrl, this.url});

  factory ItemRef.fromJson(Map<String, dynamic> json) => ItemRef(
    kind: _enum(RefKind.values, json['kind'], RefKind.other),
    id: json['id']! as String,
    lat: _num(json['lat'])?.toDouble(),
    lng: _num(json['lng'])?.toDouble(),
    imageUrl: json['imageUrl'] as String?,
    url: json['url'] as String?,
  );

  final RefKind kind;
  final String id;
  final double? lat;
  final double? lng;
  final String? imageUrl;
  final String? url;

  /// Only OpenTripMap places have a details page in the app (plan decision 6).
  bool get hasPlaceDetails => kind == RefKind.place && id.startsWith('otm:');
}

/// One timed item of a day. [start] is the destination's local time, "HH:mm".
@immutable
class PlanItem {
  const PlanItem({
    required this.kind,
    required this.start,
    required this.minutes,
    required this.name,
    required this.walkKm,
    this.price,
    this.ref,
  });

  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem(
    kind: _enum(ItemKind.values, json['kind'], ItemKind.other),
    start: json['start']! as String,
    minutes: json['minutes']! as int,
    name: json['name']! as String,
    walkKm: _double(json['walkKm']),
    price: Money.maybe(json['price']),
    ref: switch (json['ref']) {
      final Map<String, dynamic> m => ItemRef.fromJson(m),
      _ => null,
    },
  );

  final ItemKind kind;
  final String start;
  final int minutes;
  final String name;

  /// From the previous item, or the hotel.
  final double walkKm;
  final Money? price;
  final ItemRef? ref;
}

@immutable
class PlanWeather {
  const PlanWeather({required this.summary, required this.maxC, required this.minC, this.rainChance});

  factory PlanWeather.fromJson(Map<String, dynamic> json) => PlanWeather(
    summary: json['summary']! as String,
    maxC: _double(json['maxC']),
    minC: _double(json['minC']),
    rainChance: json['rainChance'] as int?,
  );

  final String summary;
  final double maxC;
  final double minC;
  final int? rainChance;
}

@immutable
class PlanDay {
  const PlanDay({
    required this.number,
    required this.date,
    required this.title,
    required this.walkKm,
    required this.items,
    this.weather,
  });

  factory PlanDay.fromJson(Map<String, dynamic> json) => PlanDay(
    number: json['number']! as int,
    date: _date(json['date']),
    title: json['title']! as String,
    weather: switch (json['weather']) {
      final Map<String, dynamic> m => PlanWeather.fromJson(m),
      _ => null,
    },
    walkKm: _double(json['walkKm']),
    items: _list(json['items']).map(PlanItem.fromJson).toList(),
  );

  final int number;
  final DateTime date;

  /// "Day 2 · Colosseum area"
  final String title;
  final PlanWeather? weather;
  final double walkKm;
  final List<PlanItem> items;
}

/// What the plan costs in its currency. A part is null when the plan has none.
@immutable
class PlanTotal {
  const PlanTotal({
    required this.amount,
    required this.currency,
    required this.events,
    required this.unpriced,
    required this.otherCurrency,
    this.flight,
    this.hotel,
    this.car,
    this.overBudgetBy,
  });

  factory PlanTotal.fromJson(Map<String, dynamic> json) => PlanTotal(
    amount: json['amount']! as num,
    currency: json['currency']! as String,
    flight: _num(json['flight']),
    hotel: _num(json['hotel']),
    car: _num(json['car']),
    events: _num(json['events']) ?? 0,
    unpriced: json['unpriced'] as int? ?? 0,
    otherCurrency: json['otherCurrency'] as int? ?? 0,
    overBudgetBy: _num(json['overBudgetBy']),
  );

  final num amount;
  final String currency;
  final num? flight;
  final num? hotel;
  final num? car;
  final num events;

  /// Items with no known price.
  final int unpriced;

  /// Items left out because their price is in another currency.
  final int otherCurrency;
  final num? overBudgetBy;
}

@immutable
class PlanMatchPart {
  const PlanMatchPart({required this.part, required this.weight, required this.percent});

  factory PlanMatchPart.fromJson(Map<String, dynamic> json) => PlanMatchPart(
    part: _enum(MatchPartKind.values, json['part'], MatchPartKind.other),
    weight: json['weight']! as int,
    percent: json['percent']! as int,
  );

  final MatchPartKind part;
  final int weight;
  final int percent;
}

/// How well the days fit one interest.
@immutable
class DaysFit {
  const DaysFit({required this.criterion, required this.weight, required this.percent});

  factory DaysFit.fromJson(Map<String, dynamic> json) => DaysFit(
    criterion: json['criterion']! as String,
    weight: json['weight']! as int,
    percent: json['percent']! as int,
  );

  /// The API's name, e.g. "culture".
  final String criterion;
  final int weight;
  final int percent;

  String get label => Criterion.parse(criterion)?.label ?? criterion;
}

/// The plan's match: the weighted average of its parts.
@immutable
class PlanMatch {
  const PlanMatch({required this.percent, required this.reason, required this.parts, required this.days});

  factory PlanMatch.fromJson(Map<String, dynamic> json) => PlanMatch(
    percent: json['percent']! as int,
    reason: json['reason']! as String,
    parts: _list(json['parts']).map(PlanMatchPart.fromJson).toList(),
    days: _list(json['days']).map(DaysFit.fromJson).toList(),
  );

  final int percent;
  final String reason;
  final List<PlanMatchPart> parts;
  final List<DaysFit> days;
}

/// An offer the plan uses, with its match and when its price was checked.
@immutable
class ChosenOffer<T> {
  const ChosenOffer(this.ranked, this.checkedAt);

  final Ranked<T> ranked;
  final DateTime? checkedAt;

  T get offer => ranked.offer;
}

Ranked<T> _ranked<T>(Map<String, dynamic> json, T Function(Map<String, dynamic>) read) =>
    Ranked(read(json), switch (json['match']) {
      final Map<String, dynamic> m => Match.fromJson(m),
      _ => null,
    });

ChosenOffer<T>? _chosen<T>(Object? json, T Function(Map<String, dynamic>) read) => switch (json) {
  final Map<String, dynamic> m => ChosenOffer(
    _ranked(m['offer']! as Map<String, dynamic>, read),
    _time(m['checkedAt']),
  ),
  _ => null,
};

/// A saved plan (`GET /api/v1/plans/{id}`).
@immutable
class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.status,
    required this.destinationId,
    required this.destinationName,
    required this.from,
    required this.to,
    required this.adults,
    required this.currency,
    required this.pace,
    required this.total,
    required this.days,
    required this.notes,
    required this.warnings,
    required this.updatedAt,
    this.originId,
    this.tripBudget,
    this.match,
    this.hotel,
    this.flight,
    this.car,
    this.edits = const [],
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    final destination = json['destination']! as Map<String, dynamic>;
    return Plan(
      id: json['id']! as String,
      name: json['name']! as String,
      status: PlanStatus.parse(json['status'] as String?),
      destinationId: destination['id']! as String,
      destinationName: destination['name']! as String,
      from: _date(json['from']),
      to: _date(json['to']),
      adults: json['adults']! as int,
      currency: json['currency']! as String,
      originId: json['originId'] as String?,
      pace: Pace.parse(json['pace'] as String?),
      tripBudget: _num(json['tripBudget']),
      match: switch (json['match']) {
        final Map<String, dynamic> m => PlanMatch.fromJson(m),
        _ => null,
      },
      hotel: _chosen(json['hotel'], HotelOffer.fromJson),
      flight: _chosen(json['flight'], FlightFare.fromJson),
      car: _chosen(json['car'], CarOffer.fromJson),
      total: PlanTotal.fromJson(json['total']! as Map<String, dynamic>),
      days: _list(json['days']).map(PlanDay.fromJson).toList(),
      notes: (json['notes'] as List<dynamic>? ?? const []).cast<String>(),
      warnings: (json['warnings'] as List<dynamic>? ?? const []).cast<String>(),
      updatedAt: _date(json['updatedAt']),
      edits: _list(json['edits']).map(PlanEdit.fromJson).toList(),
    );
  }

  final String id;
  final String name;
  final PlanStatus status;
  final String destinationId;
  final String destinationName;
  final DateTime from;
  final DateTime to;
  final int adults;
  final String currency;
  final String? originId;
  final Pace pace;
  final num? tripBudget;
  final PlanMatch? match;
  final ChosenOffer<HotelOffer>? hotel;
  final ChosenOffer<FlightFare>? flight;
  final ChosenOffer<CarOffer>? car;
  final PlanTotal total;
  final List<PlanDay> days;
  final List<String> notes;
  final List<String> warnings;
  final DateTime updatedAt;

  /// The day edits the traveller made, kept through every rebuild (API spec 010 plan edits).
  final List<PlanEdit> edits;

  int get nights => to.difference(from).inDays;
}

/// A line of My plans.
@immutable
class PlanSummary {
  const PlanSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.destinationName,
    required this.from,
    required this.to,
    required this.total,
    required this.currency,
    this.matchPercent,
    this.imageUrl,
    this.updatedAt,
    this.destinationId,
    this.adults,
    this.tripBudget,
    this.pace = Pace.balanced,
    this.lat,
    this.lng,
  });

  factory PlanSummary.fromJson(Map<String, dynamic> json) => PlanSummary(
    id: json['id']! as String,
    name: json['name']! as String,
    status: PlanStatus.parse(json['status'] as String?),
    destinationName: json['destinationName']! as String,
    from: _date(json['from']),
    to: _date(json['to']),
    total: json['total']! as num,
    currency: json['currency']! as String,
    matchPercent: json['matchPercent'] as int?,
    imageUrl: json['imageUrl'] as String?,
    updatedAt: _time(json['updatedAt']),
    destinationId: json['destinationId'] as String?,
    adults: json['adults'] as int?,
    tripBudget: json['tripBudget'] as num?,
    pace: Pace.parse(json['pace'] as String?),
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
  );

  final String id;
  final String name;
  final PlanStatus status;
  final String destinationName;
  final DateTime from;
  final DateTime to;
  final num total;
  final String currency;
  final int? matchPercent;
  final String? imageUrl;
  final DateTime? updatedAt;

  // Added by API spec 010 (plan cards and `GET /plans`); older answers leave them out.
  final String? destinationId;
  final int? adults;
  final num? tripBudget;
  final Pace pace;
  final double? lat;
  final double? lng;
}

@immutable
class PlanList {
  const PlanList({required this.items, required this.count, required this.max});

  factory PlanList.fromJson(Map<String, dynamic> json) => PlanList(
    items: _list(json['items']).map(PlanSummary.fromJson).toList(),
    count: json['count']! as int,
    max: json['max']! as int,
  );

  final List<PlanSummary> items;
  final int count;
  final int max;
}

/// The ranked list kept with a plan for one kind (API research R-7).
@immutable
class Alternatives<T> {
  const Alternatives({required this.items, this.chosenId, this.checkedAt});

  final List<Ranked<T>> items;
  final String? chosenId;
  final DateTime? checkedAt;

  static Alternatives<T> fromJson<T>(Map<String, dynamic> json, T Function(Map<String, dynamic>) read) => Alternatives(
    items: _list(json['items']).map((item) => _ranked(item, read)).toList(),
    chosenId: json['chosenId'] as String?,
    checkedAt: _time(json['checkedAt']),
  );
}

enum EditAction { replace, add, remove, other }

/// A day edit kept in the plan: an item replaced, added or removed.
@immutable
class PlanEdit {
  const PlanEdit({required this.day, required this.action, this.itemId, this.newItem});

  factory PlanEdit.fromJson(Map<String, dynamic> json) => PlanEdit(
    day: json['day']! as int,
    action: _enum(EditAction.values, json['action'], EditAction.other),
    itemId: json['itemId'] as String?,
    newItem: switch (json['newItem']) {
      final Map<String, dynamic> m => (
        kind: _enum(RefKind.values, m['kind'], RefKind.other),
        id: m['id']! as String,
        name: m['name'] as String? ?? '',
      ),
      _ => null,
    },
  );

  final int day;
  final EditAction action;

  /// The item replaced or removed; null for an add.
  final String? itemId;

  /// The item put in; null for a remove.
  final ({RefKind kind, String id, String name})? newItem;
}

/// What a day edit is about: the kinds the alternatives route takes.
enum AlternativeKind { sight, nature, restaurant, nightlife, event }

/// What the plan's values become on Rebuild plan; a null field keeps the plan's.
@immutable
class RebuildRequest {
  const RebuildRequest({this.from, this.to, this.adults, this.originId, this.preferences, this.pace, this.tripBudget});

  final DateTime? from;
  final DateTime? to;
  final int? adults;
  final String? originId;

  /// The six weights (0-100) by criterion name.
  final Map<String, int>? preferences;
  final Pace? pace;
  final num? tripBudget;

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, Object?> toJson() => {
    if (from case final from?) 'from': _day(from),
    if (to case final to?) 'to': _day(to),
    'adults': ?adults,
    'originId': ?originId,
    'preferences': ?preferences,
    if (pace case final pace?) 'pace': pace.name,
    'tripBudget': ?tripBudget,
  };
}
