import 'package:chocomousse/features/destination/data/preferences.dart';

/// The three lists "Best for you" ranks. The names are the tab values in the link.
enum RankedKind {
  hotels('Hotels'),
  flights('Flights'),
  cars('Cars');

  RankedKind(this.label);

  final String label;

  /// An unknown or missing tab reads as hotels.
  static RankedKind parse(String? value) => values.asNameMap()[value] ?? hotels;
}

/// One ranked search. As a record it compares by value, so it can key a provider.
typedef RankedQuery = ({
  String destinationId,
  DateTime from,
  DateTime to,
  int adults,
  String currency,
  int driverAge,
  Preferences preferences,
});

/// One preference's share of a match (spec 005, FR-008).
class MatchPart {
  const MatchPart({
    required this.criterion,
    required this.weight,
    required this.percent,
    required this.known,
    required this.detail,
  });

  factory MatchPart.fromJson(Map<String, dynamic> json) => MatchPart(
    criterion: json['criterion'] as String,
    weight: json['weight'] as int,
    percent: json['percent'] as int,
    known: json['known'] as bool? ?? true,
    detail: json['detail'] as String? ?? '',
  );

  /// The API's name, e.g. "culture". Kept as text so a new criterion still shows.
  final String criterion;
  final int weight;
  final int percent;

  /// False when the data was missing and the part counted as average.
  final bool known;
  final String detail;

  /// "Culture & history", or the API's name with a capital for one this app doesn't know.
  String get label =>
      Criterion.parse(criterion)?.label ??
      (criterion.isEmpty ? criterion : '${criterion[0].toUpperCase()}${criterion.substring(1)}');

  /// "High" for the weights the app sends, otherwise the number.
  String get levelLabel => Level.ofWeight(weight)?.label ?? '$weight';
}

/// How well an offer fits the preferences.
class Match {
  const Match({required this.percent, required this.reason, required this.overBudget, required this.parts});

  factory Match.fromJson(Map<String, dynamic> json) => Match(
    percent: json['percent'] as int,
    reason: json['reason'] as String,
    overBudget: json['overBudget'] as bool? ?? false,
    parts: (json['parts'] as List<dynamic>).cast<Map<String, dynamic>>().map(MatchPart.fromJson).toList(),
  );

  final int percent;
  final String reason;
  final bool overBudget;
  final List<MatchPart> parts;
}

/// An offer with its match. The match is null when the API gave none.
class Ranked<T> {
  const Ranked(this.offer, this.match);

  final T offer;
  final Match? match;
}

/// A ranked list: the kind's usual results, each offer with its match, and what ranking added.
class RankedList<T, R> {
  const RankedList({required this.results, required this.items, required this.rankingNote, required this.tripBudget});

  /// Joins the API's matches to [offers] by id, keeping the API's order.
  factory RankedList.fromJson(
    Map<String, dynamic> json, {
    required R results,
    required List<T> offers,
    required String Function(T) id,
  }) {
    final matches = <String, Match?>{
      for (final item in (json['items'] as List<dynamic>).cast<Map<String, dynamic>>())
        item['id'] as String: switch (item['match']) {
          final Map<String, dynamic> match => Match.fromJson(match),
          _ => null,
        },
    };
    return RankedList(
      results: results,
      items: [for (final offer in offers) Ranked(offer, matches[id(offer)])],
      rankingNote: json['rankingNote'] as String?,
      tripBudget: json['tripBudget'] as num?,
    );
  }

  final R results;
  final List<Ranked<T>> items;

  /// Set when nothing could be ranked; the items then have no match.
  final String? rankingNote;
  final num? tripBudget;

  bool get anyOverBudget => items.any((i) => i.match?.overBudget ?? false);
}
