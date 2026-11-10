import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/cards/pin_preview.dart';
import 'package:chocomousse/features/chat/application/chat_controller.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/chat/presentation/widgets/card_views.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/presentation/embedded_plan_view.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:chocomousse/features/side_panel/presentation/details_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A card's pin, or null for the kinds a map doesn't show (plans, flights, facts).
MapPin? pinOfCard(AssistantCard card) {
  final (kind, label) = switch (card) {
    HotelCard(:final hotel) => (PinKind.hotel, hotel.name),
    PlaceCard(:final place) => (PinKind.place, place.name),
    EventCard(:final event) => (PinKind.event, event.name),
    final CarCard car => (PinKind.car, car.rowTitle),
    _ => (null, ''),
  };
  if (kind == null) return null;
  return MapPin(id: card.id, lat: card.lat, lng: card.lng, kind: kind, label: label, approximate: card.approximate);
}

/// Every card of a chat's messages and their steps, once each, newest answer last.
List<AssistantCard> chatCards(ChatState chat) {
  final seen = <String>{};
  return [
    for (final message in chat.messages)
      for (final card in [...message.steps.expand((s) => s.cards), ...message.cards])
        if (seen.add('${CardKind.of(card).name}:${card.id}')) card,
    for (final step in chat.pending?.steps ?? const <ToolStep>[])
      for (final card in step.cards)
        if (seen.add('${CardKind.of(card).name}:${card.id}')) card,
  ];
}

/// The Map pane (spec 008 US2): the pins of this chat's cards, and of the open plan's days. A tap opens the card in
/// Details.
class MapPane extends ConsumerWidget {
  const MapPane({required this.chatKey, super.key});

  final String chatKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = chatCards(ref.watch(chatProvider(chatOfPanel(chatKey))));
    final planId = ref.watch(sidePanelProvider(chatKey).select((s) => s.planId));
    final plan = planId == null ? null : ref.watch(planProvider(planId)).value;
    final byId = {for (final card in cards) card.id: card};
    final pins = [...cards.map(pinOfCard).nonNulls, if (plan != null) ...planPins(plan)];

    if (pins.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'Pins show here when the assistant finds hotels, places or events.',
          style: AppText.body.copyWith(color: context.palette.textSecondary),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        PinPreview(
          pins: pins,
          onSelect: (id) {
            final card = byId[id];
            if (card != null) ref.read(sidePanelProvider(chatKey).notifier).openCard(card);
          },
        ),
      ],
    );
  }
}
