import 'package:flutter/foundation.dart';

/// How much a preference matters. The values are what the API receives (spec 005, FR-003).
enum Level {
  low(10, 'Low'),
  medium(50, 'Medium'),
  high(90, 'High');

  Level(this.weight, this.label);

  final int weight;
  final String label;

  /// The level a weight from the API stands for, or null for a weight the app never sends.
  static Level? ofWeight(int weight) => values.where((l) => l.weight == weight).firstOrNull;
}

/// How full the itinerary's days are (API spec 008, FR-006). It shapes the plan only; rankings ignore it.
enum Pace {
  relaxed('Relaxed', 2),
  balanced('Balanced', 3),
  packed('Packed', 4);

  Pace(this.label, this.placesPerDay);

  final String label;
  final int placesPerDay;

  /// The API's value, "relaxed", "balanced" or "packed"; anything else is Balanced.
  static Pace parse(String? value) => values.asNameMap()[value] ?? balanced;
}

/// The six preferences weighted search ranks on. The names are the API's values.
enum Criterion {
  budget('Budget'),
  culture('Culture & history'),
  food('Food'),
  nature('Nature'),
  nightlife('Nightlife'),
  comfort('Comfort');

  Criterion(this.label);

  final String label;

  static Criterion? parse(String value) => values.asNameMap()[value];
}

/// What matters to the traveller, and an optional budget for the whole trip in the trip's currency.
@immutable
class Preferences {
  const Preferences({this.levels = const {}, this.tripBudget});

  /// Levels that were set. A criterion that isn't here is Medium.
  final Map<Criterion, Level> levels;

  /// Above 0 when set.
  final int? tripBudget;

  Level of(Criterion criterion) => levels[criterion] ?? Level.medium;

  Preferences withLevel(Criterion criterion, Level level) =>
      Preferences(levels: {...levels, criterion: level}, tripBudget: tripBudget);

  Preferences withTripBudget(int? budget) => Preferences(levels: levels, tripBudget: budget);

  /// The API's query parameters: every weight, and the budget when set.
  Map<String, Object> toQuery() => {for (final c in Criterion.values) c.name: of(c).weight, 'tripBudget': ?tripBudget};

  /// "Budget High · Culture & history High · Food Medium · …"
  String get summary =>
      Criterion.values.map((c) => '${c == Criterion.culture ? 'Culture' : c.label} ${of(c).label}').join(' · ');

  @override
  bool operator ==(Object other) =>
      other is Preferences && other.tripBudget == tripBudget && Criterion.values.every((c) => other.of(c) == of(c));

  @override
  int get hashCode => Object.hash(tripBudget, Object.hashAll(Criterion.values.map(of)));
}
