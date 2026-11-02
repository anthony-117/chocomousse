import 'dart:async';

import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/links/link_opener.dart';
import 'package:chocomousse/core/widgets/page_frame.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/destination/presentation/widgets/trip_chips.dart';
import 'package:chocomousse/features/flights/application/flight_providers.dart';
import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:chocomousse/features/flights/data/flight_repository.dart';
import 'package:chocomousse/features/flights/presentation/widgets/departure_city_field.dart';
import 'package:chocomousse/features/flights/presentation/widgets/fare_tile.dart';
import 'package:chocomousse/features/flights/presentation/widgets/flight_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Recent flight prices for a destination and the trip's dates (designs F1–F4 / W1).
class FlightsScreen extends ConsumerStatefulWidget {
  const FlightsScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<FlightsScreen> createState() => _FlightsScreenState();
}

class _FlightsScreenState extends ConsumerState<FlightsScreen> {
  FlightTripType _tripType = FlightTripType.roundTrip;
  bool _directOnly = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final destination = ref.watch(destinationProvider(widget.id)).value;
    final origin = ref.watch(departureCityProvider);
    final trip = ref.watch(tripSettingsProvider);

    final search = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DepartureCityField(),
        const SizedBox(height: AppSpacing.lg),
        const TripChips(showPassport: false),
        const SizedBox(height: AppSpacing.md),
        FlightOptions(
          tripType: _tripType,
          directOnly: _directOnly,
          onTripTypeChanged: (value) => setState(() => _tripType = value),
          onDirectOnlyChanged: (value) => setState(() => _directOnly = value),
        ),
      ],
    );

    final fares = origin == null
        ? const EmptyState(
            icon: Icons.flight_takeoff,
            title: 'Where are you flying from?',
            message: 'Choose a city to see recent prices for your dates.',
          )
        : _Fares(
            query: (
              destinationId: widget.id,
              originId: origin.id,
              from: trip.from,
              to: trip.to,
              currency: trip.currency,
              tripType: _tripType,
              directOnly: _directOnly,
            ),
          );

    return PageFrame(
      children: [
        Row(
          children: [
            const BackCircleButton(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                destination == null ? 'Flights' : 'Flights to ${destination.name}',
                style: textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 400,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: search,
              ),
              const SizedBox(width: AppSpacing.xxl),
              Expanded(child: fares),
            ],
          )
        else ...[
          search,
          const SizedBox(height: AppSpacing.lg),
          fares,
        ],
      ],
    );
  }
}

class _Fares extends ConsumerWidget {
  const _Fares({required this.query});

  final FlightQuery query;

  Future<void> _open(BuildContext context, WidgetRef ref, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref.read(linkOpenerProvider)(url);
    if (!opened) messenger.showSnackBar(const SnackBar(content: Text('Could not open the booking site.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(flightResultsProvider(query))
        .when(
          loading: () => const FareTilePlaceholders(),
          error: (e, _) => isSameCityError(e)
              ? const WarningNote('This city uses the same airports as your destination. Choose a different one.')
              : Column(
                  children: [
                    ErrorRetry(error: e, onRetry: () => ref.invalidate(flightResultsProvider(query))),
                    const SizedBox(height: AppSpacing.sm),
                    const FareTilePlaceholders(animate: false),
                  ],
                ),
          data: (results) => _FareList(results: results, onOpen: (url) => unawaited(_open(context, ref, url))),
        );
  }
}

class _FareList extends StatelessWidget {
  const _FareList({required this.results, required this.onOpen});

  final FlightResults results;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final notes = [?results.origin.nearbyNote, ?results.destination.nearbyNote, ...results.warnings];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final note in notes) ...[WarningNote(note), const SizedBox(height: AppSpacing.sm)],
        if (results.items.isEmpty)
          _NoFares(results: results, onOpen: onOpen)
        else ...[
          if (results.message case final message?) ...[_DatesMessage(message), const SizedBox(height: AppSpacing.sm)],
          WarningNote(results.priceNote),
          const SizedBox(height: AppSpacing.md),
          for (final fare in results.items) ...[
            FareTile(fare: fare, onOpen: () => onOpen(fare.bookingUrl)),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ],
    );
  }
}

/// Explains why the fares are not on the requested dates.
class _DatesMessage extends StatelessWidget {
  const _DatesMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Text(message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary)),
    );
  }
}

class _NoFares extends StatelessWidget {
  const _NoFares({required this.results, required this.onOpen});

  final FlightResults results;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final message = results.message;
    final searchUrl = results.searchUrl;
    if (message == null && searchUrl == null) return const SizedBox.shrink();

    return SoftCard(
      child: Column(
        children: [
          Text('No recent prices for this trip', style: Theme.of(context).textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(message, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ],
          if (searchUrl != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: () => onOpen(searchUrl), child: const Text('Search live prices')),
          ],
        ],
      ),
    );
  }
}
