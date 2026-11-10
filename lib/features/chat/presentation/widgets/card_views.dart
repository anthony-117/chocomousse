import 'dart:async';

import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/cards/media_card.dart';
import 'package:chocomousse/core/widgets/cards/plan_card_tile.dart';
import 'package:chocomousse/core/widgets/cards/result_row.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:chocomousse/features/side_panel/presentation/side_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// One card of an answer, drawn for its kind. Car, place, event and facts cards get their own look in spec 008 US2.
class AssistantCardView extends ConsumerWidget {
  const AssistantCardView({required this.card, required this.chatKey, super.key});

  final AssistantCard card;
  final String chatKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open() => openAssistantCard(context, ref, chatKey, card);
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
      ),
      final HotelCard hotel => MediaCard(
        photoUrl: hotel.hotel.photoUrl,
        title: hotel.hotel.name,
        subtitle: hotel.subtitle,
        price: hotel.nightPrice,
        match: hotel.match,
        onTap: open,
      ),
      final CarCard car => ResultRow(
        icon: AppIcons.car,
        title: _itemName(car) ?? 'Car',
        subtitle: 'Rental car',
        price: '',
        match: car.match,
        onTap: open,
      ),
      _ => ResultRow(
        icon: switch (card) {
          PlaceCard() => AppIcons.landmark,
          EventCard() => AppIcons.ticket,
          _ => AppIcons.globe,
        },
        title: _itemName(card) ?? CardKind.of(card).label,
        subtitle: '',
        price: '',
        onTap: open,
      ),
    };
  }

  static String? _itemName(AssistantCard card) {
    final item = card.raw['item'];
    return item is Map<String, dynamic> ? item['name'] as String? ?? item['model'] as String? : null;
  }
}
