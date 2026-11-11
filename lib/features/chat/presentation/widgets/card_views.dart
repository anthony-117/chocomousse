import 'dart:async';

import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/cards/facts_rows.dart';
import 'package:chocomousse/core/widgets/cards/media_card.dart';
import 'package:chocomousse/core/widgets/cards/plan_card_tile.dart';
import 'package:chocomousse/core/widgets/cards/result_row.dart';
import 'package:chocomousse/features/chat/application/chat_trip.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/models.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/plan_texts.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:chocomousse/features/saved/presentation/bookmark_button.dart';
import 'package:chocomousse/features/side_panel/application/panel_chat.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:chocomousse/features/side_panel/presentation/side_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

final _day = DateFormat('EEE d MMM');
final _time = DateFormat('HH:mm');

String _stops(int stops) => switch (stops) {
  0 => 'Direct',
  1 => '1 stop',
  _ => '$stops stops',
};

String _hours(int minutes) =>
    minutes % 60 == 0 ? '${minutes ~/ 60} h' : '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}';

String _km(double km) => km < 10 ? km.toStringAsFixed(1) : km.round().toString();

/// A flight card as a row: "ORY → FCO" over "Sat 10 Apr · 09:25 · Direct · 4 h 20".
extension FlightCardRow on FlightCard {
  String get rowTitle => '${fare.originAirport} → ${fare.destinationAirport}';

  String get rowSubtitle => [
    _day.format(fare.departureAt),
    _time.format(fare.departureAt),
    _stops(fare.stops),
    if (fare.durationMinutes case final minutes?) _hours(minutes),
  ].join(' · ');

  String get rowPrice => formatMoney(fare.amount, fare.currency);
}

/// A hotel card's lines: "4★ · 8.9 · 1.1 km to centre" and "$203 / night".
extension HotelCardLines on HotelCard {
  String get subtitle => [
    if (hotel.stars case final stars?) '$stars★',
    if (hotel.reviewScore case final score?) score.toStringAsFixed(1),
    '${_km(hotel.distanceKm)} km to centre',
  ].join(' · ');

  String get nightPrice => '${formatMoney(hotel.price.perNight, hotel.price.currency)} / night';
}

/// The kinds of card, in the order an answer shows their groups, with each group's label.
enum CardKind {
  plan('PLAN'),
  flight('FLIGHTS'),
  hotel('HOTELS'),
  car('CARS'),
  place('PLACES'),
  event('EVENTS'),
  facts('TRAVEL FACTS');

  CardKind(this.label);

  final String label;

  static CardKind of(AssistantCard card) => switch (card) {
    PlanCard() => plan,
    FlightCard() => flight,
    HotelCard() => hotel,
    CarCard() => car,
    PlaceCard() => place,
    EventCard() => event,
    FactsCard() => facts,
  };
}

/// Opens [card] in the chat's side panel: a plan in the Plan pane, anything else in Details. On phones the panel is
/// a sheet.
void openAssistantCard(BuildContext context, WidgetRef ref, String chatKey, AssistantCard card) {
  ref.read(sidePanelProvider(chatKey).notifier).openCard(card);
  if (MediaQuery.sizeOf(context).width < kWideLayoutBreakpoint) unawaited(showSidePanelSheet(context, chatKey));
}

/// A place's kind for its card: "Restaurant", "Nature", "Nightlife" or "Sight".
String placeKindLabel(Place place) {
  switch (place.category) {
    case PlaceCategory.restaurant:
      return 'Restaurant';
    case PlaceCategory.nature:
      return 'Nature';
    case PlaceCategory.nightlife:
      return 'Nightlife';
    case PlaceCategory.attraction:
      break;
  }
  final kind = place.kind?.toLowerCase() ?? '';
  if (RegExp('park|garden|beach|lake|mountain|forest|nature|reserve').hasMatch(kind)) return 'Nature';
  if (RegExp('bar|club|pub|night').hasMatch(kind)) return 'Nightlife';
  return 'Sight';
}

/// A place card's lines: "Sight · ★ 4.7" (or the price level), and nothing for the price.
extension PlaceCardLines on PlaceCard {
  String get subtitle => [
    placeKindLabel(place),
    if (place.rating case final rating?) '★ ${rating.toStringAsFixed(1)}' else ?place.priceLevel,
  ].join(' · ');
}

/// An event card's lines: "Sun 11 Apr · 21:00" with the venue, and "from €35" when known.
extension EventCardLines on EventCard {
  String get when => [_day.format(event.date), ?event.time].join(' · ');

  String get subtitle => [when, ?event.venue].join(' · ');

  String get price => event.priceFrom ?? '';
}

/// A car card as a row: "Fiat 600 · Budget" over "Pick-up via Sardegna · 10 – 14 Apr".
extension CarCardRow on CarCard {
  String get rowTitle => '${car.model} · ${car.company.name}';

  String rowSubtitle({DateTime? from, DateTime? to}) =>
      ['Pick-up ${car.pickUp.name}', if (from != null && to != null) planDates(from, to)].join(' · ');

  String get rowPrice => formatMoney(car.price.total, car.price.currency);
}

String? _matchLabel(Match? match) => match == null ? null : '${match.percent}% match';

/// What a screen reader says for a card: its name, its match when ranked, then its key facts and price
/// ("Hotel Artemide, 92% match, $132 a night"). Null for plan and facts cards, which read their own texts.
String? cardSemanticLabel(AssistantCard card) => switch (card) {
  final FlightCard f => [f.rowTitle, ?_matchLabel(f.match), f.rowSubtitle, f.rowPrice].join(', '),
  final HotelCard h => [
    h.hotel.name,
    ?_matchLabel(h.match),
    '${formatMoney(h.hotel.price.perNight, h.hotel.price.currency)} a night',
  ].join(', '),
  final CarCard c => [c.rowTitle, ?_matchLabel(c.match), '${c.rowPrice} in all'].join(', '),
  final PlaceCard p => [p.place.name, p.subtitle].join(', '),
  final EventCard e => [e.event.name, e.subtitle, if (e.price.isNotEmpty) e.price].join(', '),
  PlanCard() || FactsCard() => null,
};

/// One card of an answer, drawn for its kind. A tap opens it in the side panel.
class AssistantCardView extends ConsumerWidget {
  const AssistantCardView({required this.card, required this.chatKey, super.key});

  final AssistantCard card;
  final String chatKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open() => openAssistantCard(context, ref, chatKey, card);
    final palette = context.palette;
    Widget plus() {
      // The label follows the plan open in the panel.
      ref.watch(sidePanelProvider(chatKey).select((s) => s.planId));
      return IconButton(
        tooltip: planActionLabel(ref, chatKey, card),
        // Drawn at 28 px to fit the card's price line; the tap area stays 48 × 48 (T093).
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.padded,
          minimumSize: const Size.square(28),
          fixedSize: const Size.square(28),
          padding: EdgeInsets.zero,
        ),
        onPressed: () => unawaited(addCardToPlan(context, ref, chatKey, card)),
        icon: AppIcon(AppIcons.plus, size: 18, color: palette.brandPrimary),
      );
    }

    return switch (card) {
      PlanCard(:final plan) => PlanCardTile(
        plan: plan,
        selected: ref.watch(
          sidePanelProvider(chatKey).select((s) => s.open && s.pane == PanelPane.plan && s.planId == plan.id),
        ),
        onOpen: open,
      ),
      final FlightCard flight => ResultRow(
        icon: AppIcons.plane,
        title: flight.rowTitle,
        subtitle: flight.rowSubtitle,
        price: flight.rowPrice,
        match: flight.match,
        onTap: open,
        semanticLabel: cardSemanticLabel(flight),
      ),
      final HotelCard hotel => MediaCard(
        photoUrl: hotel.hotel.photoUrl,
        title: hotel.hotel.name,
        subtitle: hotel.subtitle,
        price: hotel.nightPrice,
        match: hotel.match,
        onTap: open,
        semanticLabel: cardSemanticLabel(hotel),
        bookmark: BookmarkButton(card: hotel),
        add: plus(),
      ),
      final CarCard car => ResultRow(
        icon: AppIcons.car,
        title: car.rowTitle,
        subtitle: car.rowSubtitle(
          from: ref.watch(chatTripProvider.select((t) => t.trip.from)),
          to: ref.watch(chatTripProvider.select((t) => t.trip.to)),
        ),
        price: car.rowPrice,
        match: car.match,
        onTap: open,
        semanticLabel: cardSemanticLabel(car),
        add: plus(),
      ),
      final PlaceCard place => MediaCard(
        photoUrl: place.place.imageUrl,
        title: place.place.name,
        subtitle: place.subtitle,
        price: '',
        onTap: open,
        semanticLabel: cardSemanticLabel(place),
        bookmark: BookmarkButton(card: place),
      ),
      final EventCard event => MediaCard(
        photoUrl: null,
        title: event.event.name,
        subtitle: event.subtitle,
        price: event.price,
        onTap: open,
        semanticLabel: cardSemanticLabel(event),
        bookmark: BookmarkButton(card: event),
      ),
      FactsCard(:final facts) => Material(
        color: palette.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: palette.borderDefault),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(facts.destination.name, style: AppText.bodyStrong.copyWith(color: palette.textPrimary)),
                const SizedBox(height: AppSpacing.xs),
                FactsRows(facts: facts),
              ],
            ),
          ),
        ),
      ),
    };
  }
}

/// Where "See all" goes for [cards] of one kind, from the chat's city: the list screens of each kind, or the city
/// overview for events. Null without a city, or for plans and facts.
String? seeAllRoute(List<AssistantCard> cards, String? destinationId) {
  if (destinationId == null || cards.isEmpty) return null;
  final base = '/discover/destination/$destinationId';
  return switch (cards.first) {
    HotelCard() => '$base/hotels',
    FlightCard() => '$base/flights',
    CarCard() => '$base/cars',
    PlaceCard(:final place) => '$base/places?category=${place.category.name}',
    EventCard() => base,
    PlanCard() || FactsCard() => null,
  };
}

/// Opens [route] with the trip settings the list screens read set from the chat's trip: dates, adults and the
/// preferences when the traveller changed them.
void openSeeAll(BuildContext context, WidgetRef ref, String route) {
  final chips = ref.read(chatTripProvider);
  final settings = ref.read(tripSettingsProvider.notifier);
  final from = chips.trip.from;
  final to = chips.trip.to;
  if (from != null && to != null) settings.setDates(from, to);
  if (chips.trip.adults case final adults?) settings.setAdults(adults);
  if (chips.preferencesChanged) {
    settings.setPreferences(
      Preferences(
        levels: {
          for (final c in Criterion.values)
            if (chips.preferences[c.name] case final weight?) c: ?Level.ofWeight(weight),
        },
        tripBudget: ref.read(tripSettingsProvider).preferences.tripBudget,
      ),
    );
  }
  if (chips.paceChanged) settings.setPace(chips.pace);
  unawaited(GoRouter.of(context).push<void>(route));
}
