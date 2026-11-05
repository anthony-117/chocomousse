import 'dart:async';

import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/links/link_opener.dart';
import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:chocomousse/features/cars/presentation/car_details_screen.dart';
import 'package:chocomousse/features/cars/presentation/cars_screen.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:chocomousse/features/flights/application/flight_providers.dart';
import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:chocomousse/features/flights/presentation/widgets/departure_city_field.dart';
import 'package:chocomousse/features/hotels/data/hotel_models.dart';
import 'package:chocomousse/features/ranking/application/ranking_providers.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/ranked_card.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/ranked_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The open tab of "Best for you". Only this tab's provider is watched, so only it loads (FR-006).
class RankedTab extends ConsumerWidget {
  const RankedTab({required this.kind, required this.query, required this.wide, super.key});

  final RankedKind kind;
  final RankedQuery query;
  final bool wide;

  Future<void> _openLink(BuildContext context, WidgetRef ref, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref.read(linkOpenerProvider)(url);
    if (!opened) messenger.showSnackBar(const SnackBar(content: Text('Could not open the link.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void search(String url) => unawaited(_openLink(context, ref, url));
    final base = '/discover/destination/${query.destinationId}';

    switch (kind) {
      case RankedKind.hotels:
        return RankedListView<HotelOffer, HotelResults>(
          key: const ValueKey(RankedKind.hotels),
          value: ref.watch(rankedHotelsProvider(query)),
          kind: hotelView(query, onOpen: (hotel) => context.push('$base/hotels/${Uri.encodeComponent(hotel.id)}')),
          loading: const RankedCardPlaceholders(),
          onRetry: () => ref.invalidate(rankedHotelsProvider(query)),
          onSearch: search,
          wide: wide,
        );
      case RankedKind.flights:
        final origin = ref.watch(departureCityProvider);
        if (origin == null) return const _ChooseDeparture();
        final key = (query, origin.id);
        return RankedListView<FlightFare, FlightResults>(
          key: const ValueKey(RankedKind.flights),
          value: ref.watch(rankedFlightsProvider(key)),
          kind: flightView(query, onOpen: (fare) => search(fare.bookingUrl)),
          loading: const RankedCardPlaceholders(),
          onRetry: () => ref.invalidate(rankedFlightsProvider(key)),
          onSearch: search,
          wide: wide,
        );
      case RankedKind.cars:
        return RankedListView<CarOffer, CarResults>(
          key: const ValueKey(RankedKind.cars),
          value: ref.watch(rankedCarsProvider(query)),
          kind: carView(
            query,
            onOpen: (car, results) => context.push(
              '$base/cars/${Uri.encodeComponent(car.id)}',
              extra: CarDetailsArgs(car: car, results: results),
            ),
            footer: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push('$base/cars'),
                icon: const Icon(Icons.directions_car_outlined, size: 18),
                label: const Text('See all cars, with sort and filters'),
              ),
            ),
          ),
          loading: const CarSearching(),
          onRetry: () => ref.invalidate(rankedCarsProvider(query)),
          onSearch: search,
          wide: wide,
        );
    }
  }
}

final _day = DateFormat('d MMM');
final _when = DateFormat('EEE d MMM · HH:mm');

String _km(double km) => km < 10 ? km.toStringAsFixed(1) : km.round().toString();

String _duration(int minutes) =>
    minutes < 60 ? '${minutes}m' : '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';

String _stops(int stops) => switch (stops) {
  0 => 'DIRECT',
  1 => '1 STOP',
  _ => '$stops STOPS',
};

String _nights(int n) => n == 1 ? '1 night' : '$n nights';

String _checked(DateTime? at, {required bool saved}) =>
    at == null ? '' : ', ${saved ? 'saved' : 'checked'} ${describeCheckedAt(at)}';

/// Hotels (S2): all six preferences count.
RankedKindView<HotelOffer, HotelResults> hotelView(RankedQuery q, {required ValueChanged<HotelOffer> onOpen}) =>
    RankedKindView(
      noun: 'Hotels',
      notes: (r) => [
        for (final warning in r.warnings) OfferWarning(warning),
        if (r.items.isNotEmpty)
          WarningNote(
            '${r.items.length} hotels from Booking.com for ${_day.format(q.from)} – ${_day.format(q.to)}'
            '${_checked(r.pricesFetchedAt, saved: r.isSavedPrice)}. Tap a match to see why.',
          ),
      ],
      card: (h, r) => RankedCardData(
        id: h.id,
        kind: h.stars == null ? 'HOTEL' : 'HOTEL · ${h.stars}★',
        title: h.name,
        details: '${_nights(r.nights)} · ${_km(h.distanceKm)} km from ${h.nearCity ? r.destinationName : 'the centre'}',
        price: formatMoney(h.price.total, h.price.currency),
        priceLine: '${formatMoney(h.price.total, h.price.currency)} for ${_nights(r.nights)}',
        openLabel: 'Open hotel',
      ),
      open: (h, _) => onOpen(h),
      emptyTitle: 'No hotels for these dates',
      message: (r) => r.message,
      searchUrl: (r) => r.searchUrl,
    );

/// Flights (S4): budget and comfort only.
RankedKindView<FlightFare, FlightResults> flightView(RankedQuery q, {required ValueChanged<FlightFare> onOpen}) =>
    RankedKindView(
      noun: 'Flights',
      notes: (r) => [
        for (final warning in r.warnings) OfferWarning(warning),
        ?r.origin.nearbyNote == null ? null : WarningNote(r.origin.nearbyNote!),
        ?r.destination.nearbyNote == null ? null : WarningNote(r.destination.nearbyNote!),
        const WarningNote(
          'Flights are ranked on budget and comfort only (stops, journey time, dates). '
          'Recent prices from Aviasales, not live.',
        ),
      ],
      card: (f, r) {
        final duration = f.durationMinutes;
        final dates = f.dateMatch.label;
        return RankedCardData(
          id: f.id,
          kind: 'FLIGHT · ${_stops(f.stops)}',
          title: '${r.origin.name} → ${r.destination.name}',
          details: [_when.format(f.departureAt), if (duration != null) _duration(duration), ?dates].join(' · '),
          price: formatMoney(f.amount, f.currency),
          priceLine: '${formatMoney(f.amount, f.currency)} · ${f.originAirport} → ${f.destinationAirport}',
          openLabel: 'Open flight',
        );
      },
      open: (f, _) => onOpen(f),
      emptyTitle: 'No recent flights for these dates',
      message: (r) => r.message,
      searchUrl: (r) => r.searchUrl,
    );

/// Cars (S6): budget and comfort only, at the city centre.
RankedKindView<CarOffer, CarResults> carView(
  RankedQuery q, {
  required void Function(CarOffer car, CarResults results) onOpen,
  Widget? footer,
}) => RankedKindView(
  noun: 'Cars',
  notes: (r) => [
    for (final warning in r.warnings) OfferWarning(warning),
    ?r.driverNote == null ? null : WarningNote(r.driverNote!),
    WarningNote(
      'Cars are ranked on budget and comfort only (size, company rating, automatic, free cancellation). '
      'City centre, driver ${q.driverAge}, from Booking.com${_checked(r.pricesFetchedAt, saved: r.isSavedPrice)}.',
    ),
  ],
  card: (c, r) {
    final seats = c.seats;
    return RankedCardData(
      id: c.id,
      kind: 'CAR · ${c.size.toUpperCase()}',
      title: '${c.model}${c.orSimilar == null ? '' : ' ${c.orSimilar}'} · ${c.company.name}',
      details: [?c.gearbox?.label, if (seats != null) '$seats seats', c.pickUp.name].join(' · '),
      price: formatMoney(c.price.total, c.price.currency),
      priceLine: '${formatMoney(c.price.total, c.price.currency)} for ${r.days == 1 ? '1 day' : '${r.days} days'}',
      openLabel: 'Open car',
    );
  },
  open: onOpen,
  emptyTitle: 'No rental cars here for these dates',
  message: (r) => r.message,
  searchUrl: (r) => r.searchUrl,
  footer: footer,
);

class _ChooseDeparture extends StatelessWidget {
  const _ChooseDeparture();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WarningNote('Choose where you fly from to rank flights.'),
        SizedBox(height: AppSpacing.md),
        DepartureCityField(),
      ],
    );
  }
}
