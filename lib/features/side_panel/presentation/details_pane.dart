import 'dart:async';

import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/links/link_opener.dart';
import 'package:chocomousse/core/widgets/cards/facts_rows.dart';
import 'package:chocomousse/core/widgets/cards/match_pill.dart';
import 'package:chocomousse/features/cars/presentation/car_details_screen.dart';
import 'package:chocomousse/features/chat/application/chat_controller.dart';
import 'package:chocomousse/features/chat/application/chat_trip.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/chat/presentation/widgets/card_views.dart';
import 'package:chocomousse/features/destination/presentation/place_details_screen.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:chocomousse/features/hotels/presentation/hotel_details_screen.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final _found = DateFormat('d MMM');

/// The chat a panel belongs to: null for the home's.
String? chatOfPanel(String chatKey) => chatKey == homePanelKey ? null : chatKey;

/// A card's title, for "Search again for …".
String cardTitle(AssistantCard card) => switch (card) {
  PlanCard(:final plan) => plan.name,
  final FlightCard flight => flight.rowTitle,
  HotelCard(:final hotel) => hotel.name,
  final CarCard car => car.rowTitle,
  PlaceCard(:final place) => place.name,
  EventCard(:final event) => event.name,
  FactsCard(:final facts) => 'travel facts for ${facts.destination.name}',
};

Match? _matchOf(AssistantCard card) => switch (card) {
  FlightCard(:final match) || HotelCard(:final match) || CarCard(:final match) => match,
  _ => null,
};

/// The Details pane (spec 008 US2): the card chosen in the chat, in full.
class DetailsPane extends ConsumerWidget {
  const DetailsPane({required this.chatKey, this.now, super.key});

  final String chatKey;

  /// For tests: the time "found over 24 h ago" is measured from.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final card = ref.watch(sidePanelProvider(chatKey).select((s) => s.selected));
    if (card == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'Tap a card in the chat to see it here.',
          style: AppText.body.copyWith(color: palette.textSecondary),
        ),
      );
    }
    final trip = ref.watch(chatTripProvider.select((s) => s.trip));
    final match = _matchOf(card);
    final foundAt = card.foundAt;
    final stale = foundAt != null && (now ?? DateTime.now()).difference(foundAt) > const Duration(hours: 24);
    final sending = ref.watch(chatProvider(chatOfPanel(chatKey)).select((s) => s.isSending));

    final top = [
      if (match != null) ...[
        Align(alignment: Alignment.centerLeft, child: MatchPill(match)),
        const SizedBox(height: AppSpacing.xs),
        Text(match.reason, style: AppText.small.copyWith(color: palette.textSecondary)),
        const SizedBox(height: AppSpacing.md),
      ],
      if (stale) ...[
        Row(
          children: [
            Expanded(
              child: Text(
                'Found on ${_found.format(foundAt.toLocal())}',
                style: AppText.small.copyWith(color: palette.statusWarning),
              ),
            ),
            TextButton(
              onPressed: sending
                  ? null
                  : () => unawaited(
                      ref.read(chatProvider(chatOfPanel(chatKey)).notifier).send('Search again for ${cardTitle(card)}'),
                    ),
              child: const Text('Search again'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    ];

    // The place screen scrolls on its own; every other view scrolls here.
    if (card case PlaceCard(:final place) when place.id.startsWith('otm:')) {
      return EmbeddedDetails(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (top.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: top),
              ),
            Expanded(child: PlaceDetailsView(placeId: place.id)),
          ],
        ),
      );
    }

    final body = switch (card) {
      HotelCard(:final hotel) => HotelDetailsView(hotelId: hotel.id, from: trip.from, to: trip.to, adults: trip.adults),
      CarCard(:final car) => CarDetailsView(car: car),
      final FlightCard flight => _FlightView(flight),
      final EventCard event => _EventView(event),
      final PlaceCard place => _PlaceView(place),
      FactsCard(:final facts) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Travel facts · ${facts.destination.name}',
            style: AppText.serifTitle.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          FactsRows(facts: facts, full: true),
        ],
      ),
      PlanCard() => const SizedBox.shrink(),
    };

    return EmbeddedDetails(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          ...top,
          body,
          // The bookmark (spec 008 US6) and Add to plan (US3) go here.
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

Future<void> _openLink(BuildContext context, WidgetRef ref, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final opened = await ref.read(linkOpenerProvider)(url);
  if (!opened) messenger.showSnackBar(const SnackBar(content: Text('Could not open the link.')));
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.serifTitle.copyWith(color: palette.textPrimary)),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: AppText.small.copyWith(color: palette.textSecondary)),
      ],
    );
  }
}

class _FlightView extends ConsumerWidget {
  const _FlightView(this.card);

  final FlightCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(card.rowTitle, card.rowSubtitle),
        const SizedBox(height: AppSpacing.lg),
        Text(card.rowPrice, style: AppText.title.copyWith(color: palette.textPrimary)),
        Text('Prices are recent, not live', style: AppText.small.copyWith(color: palette.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () => unawaited(_openLink(context, ref, card.fare.bookingUrl)),
          child: const Text('See this fare'),
        ),
      ],
    );
  }
}

class _EventView extends ConsumerWidget {
  const _EventView(this.card);

  final EventCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(card.event.name, card.subtitle),
        if (card.price.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(card.price, style: AppText.bodyStrong.copyWith(color: palette.textPrimary)),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () => unawaited(_openLink(context, ref, card.event.url)),
          child: const Text('Get tickets'),
        ),
      ],
    );
  }
}

class _PlaceView extends ConsumerWidget {
  const _PlaceView(this.card);

  final PlaceCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = card.place;
    final website = place.website;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(height: 200, child: OfferPhoto(url: place.imageUrl)),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Title(
          place.name,
          [card.subtitle, '${place.lat.toStringAsFixed(4)}, ${place.lng.toStringAsFixed(4)}'].join(' · '),
        ),
        if (place.description case final description?) ...[
          const SizedBox(height: AppSpacing.md),
          Text(description, style: AppText.body.copyWith(color: context.palette.textPrimary)),
        ],
        if (website != null) ...[
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(onPressed: () => unawaited(_openLink(context, ref, website)), child: const Text('Open link')),
        ],
      ],
    );
  }
}
