import 'dart:async';

import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/links/link_opener.dart';
import 'package:chocomousse/core/widgets/page_frame.dart';
import 'package:chocomousse/features/cars/application/car_providers.dart';
import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:chocomousse/features/cars/presentation/car_details_screen.dart';
import 'package:chocomousse/features/cars/presentation/widgets/car_card.dart';
import 'package:chocomousse/features/cars/presentation/widgets/car_filters_sheet.dart';
import 'package:chocomousse/features/cars/presentation/widgets/pick_up_sheet.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:chocomousse/features/destination/presentation/widgets/trip_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Rental cars for a destination, the trip's dates and the driver's age (designs C1–C6).
class CarsScreen extends ConsumerStatefulWidget {
  const CarsScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<CarsScreen> createState() => _CarsScreenState();
}

class _CarsScreenState extends ConsumerState<CarsScreen> {
  final GlobalKey _top = GlobalKey();

  /// Each city starts at its centre with no filters (spec FR-003).
  PickUpPlace _place = PickUpPlace.centre;
  CarFilters _filters = const CarFilters();
  int _page = 1;

  /// The last search's filter values, kept while the next one loads so the filters stay usable.
  CarFilterChoices _choices = noCarFilterChoices;

  void _apply(CarFilters filters) => setState(() {
    _filters = filters;
    _page = 1;
  });

  void _goTo(int page) {
    setState(() => _page = page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final top = _top.currentContext;
      if (top != null && top.mounted) Scrollable.ensureVisible(top);
    });
  }

  Future<void> _openFilters(TripSettings trip) async {
    final applied = await showCarFiltersSheet(
      context,
      filters: _filters,
      choices: _choices,
      days: _days(trip),
      currency: trip.currency,
    );
    if (applied != null) _apply(applied);
  }

  Future<void> _openPickUp(TripSettings trip) async {
    final choice = await showPickUpSheet(
      context,
      destinationId: widget.id,
      place: _place,
      driverAge: trip.driverAge,
      from: trip.from,
      to: trip.to,
    );
    if (choice == null || !mounted) return;
    setState(() {
      _place = choice.place;
      _page = 1;
    });
    ref.read(tripSettingsProvider.notifier).setDriverAge(choice.driverAge);
  }

  /// Rental days, as the API counts them: at least one.
  static int _days(TripSettings trip) => trip.nights < 1 ? 1 : trip.nights;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final destination = ref.watch(destinationProvider(widget.id)).value;
    final trip = ref.watch(tripSettingsProvider);
    // New dates, age or currency start again from the first page.
    ref.listen(tripSettingsProvider, (_, _) => setState(() => _page = 1));

    final query = (
      destinationId: widget.id,
      from: trip.from,
      to: trip.to,
      place: _place.id,
      driverAge: trip.driverAge,
      currency: trip.currency,
      filters: _filters,
      page: _page,
    );
    ref.listen(carResultsProvider(query), (_, next) {
      final results = next.value;
      if (results != null) {
        setState(
          () => _choices = (
            sizes: results.sizes,
            companies: results.companies,
            pickUpTypes: results.pickUpTypes,
            searched: results.searchedCount,
          ),
        );
      }
    });

    final chips = TripChips(
      showPassport: false,
      extra: [
        ActionChip(
          avatar: Icon(Icons.place_outlined, size: 16, color: context.palette.brandPrimary),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text(_place.label), const Icon(Icons.expand_more, size: 16)],
          ),
          tooltip: 'Pick-up place',
          onPressed: () => unawaited(_openPickUp(trip)),
        ),
        ActionChip(
          avatar: Icon(Icons.person_outline, size: 16, color: context.palette.brandPrimary),
          label: Text('Driver ${trip.driverAge}'),
          tooltip: "Driver's age",
          onPressed: () => unawaited(_openPickUp(trip)),
        ),
      ],
    );
    final results = _Results(query: query, wide: wide, onClearFilters: () => _apply(_filters.cleared()), onPage: _goTo);

    return PageFrame(
      children: [
        Row(
          key: _top,
          children: [
            const BackCircleButton(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(destination == null ? 'Cars' : 'Cars in ${destination.name}', style: textTheme.headlineSmall),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A Material rather than a decorated box, so the free-cancellation switch's splash shows.
              Material(
                color: context.palette.bgSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: BorderSide(color: context.palette.borderDefault),
                ),
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      chips,
                      const SizedBox(height: AppSpacing.lg),
                      CarFiltersForm(
                        filters: _filters,
                        choices: _choices,
                        days: _days(trip),
                        currency: trip.currency,
                        onApply: _apply,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xxl),
              Expanded(child: results),
            ],
          )
        else ...[
          chips,
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _SortButton(
                sort: _filters.sort,
                onChanged: (sort) => _apply(_filters.copyWith(sort: sort)),
              ),
              ActionChip(
                avatar: Icon(
                  Icons.tune,
                  size: 16,
                  color: _filters.activeCount > 0 ? context.palette.brandPrimary : context.palette.textPrimary,
                ),
                label: Text(_filters.activeCount > 0 ? 'Filters · ${_filters.activeCount}' : 'Filters'),
                backgroundColor: _filters.activeCount > 0 ? context.palette.brandPrimarySoft : null,
                onPressed: () => unawaited(_openFilters(trip)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          results,
        ],
      ],
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onChanged});

  final CarSort sort;
  final ValueChanged<CarSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CarSort>(
      tooltip: 'Sort cars',
      initialValue: sort,
      onSelected: onChanged,
      itemBuilder: (context) => [for (final s in CarSort.values) PopupMenuItem(value: s, child: Text(s.label))],
      child: Chip(
        avatar: Icon(Icons.swap_vert, size: 16, color: context.palette.textPrimary),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(sort.label), const Icon(Icons.expand_more, size: 16)],
        ),
      ),
    );
  }
}

/// While a new search runs at Booking.com (C5): it takes up to 30 seconds, so the screen says so.
class CarSearching extends StatelessWidget {
  const CarSearching({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WarningNote(
          'Searching hundreds of cars on Booking.com. This takes up to 30 seconds; the results are then kept for a day.',
        ),
        SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.full)),
          child: LinearProgressIndicator(minHeight: 6, semanticsLabel: 'Searching for cars'),
        ),
        SizedBox(height: AppSpacing.lg),
        CarCardPlaceholders(count: 2),
      ],
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.query, required this.wide, required this.onClearFilters, required this.onPage});

  final CarQuery query;
  final bool wide;
  final VoidCallback onClearFilters;
  final ValueChanged<int> onPage;

  Future<void> _open(BuildContext context, WidgetRef ref, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref.read(linkOpenerProvider)(url);
    if (!opened) messenger.showSnackBar(const SnackBar(content: Text('Could not open Booking.com.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(carResultsProvider(query))
        .when(
          loading: () => const CarSearching(),
          error: (e, _) => Column(
            children: [
              _ErrorBanner(message: describeProblem(e), onRetry: () => ref.invalidate(carResultsProvider(query))),
              const SizedBox(height: AppSpacing.sm),
              const CarCardPlaceholders(animate: false),
            ],
          ),
          data: (results) => _CarList(
            results: results,
            filters: query.filters,
            wide: wide,
            onCar: (car) => context.push(
              '/discover/destination/${query.destinationId}/cars/${Uri.encodeComponent(car.id)}',
              extra: CarDetailsArgs(car: car, results: results),
            ),
            onSearchBookingCom: (url) => unawaited(_open(context, ref, url)),
            onClearFilters: onClearFilters,
            onRetry: () => ref.invalidate(carResultsProvider(query)),
            onPage: onPage,
          ),
        );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      decoration: BoxDecoration(color: context.palette.bgApp, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: context.palette.textSecondary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _CarList extends StatelessWidget {
  const _CarList({
    required this.results,
    required this.filters,
    required this.wide,
    required this.onCar,
    required this.onSearchBookingCom,
    required this.onClearFilters,
    required this.onRetry,
    required this.onPage,
  });

  final CarResults results;
  final CarFilters filters;
  final bool wide;
  final ValueChanged<CarOffer> onCar;
  final ValueChanged<String> onSearchBookingCom;
  final VoidCallback onClearFilters;
  final VoidCallback onRetry;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final fetchedAt = results.pricesFetchedAt;
    final driverNote = results.driverNote;
    final searchUrl = results.bookingSearchUrl;

    final notes = <Widget>[
      for (final warning in results.warnings) OfferWarning(warning),
      if (driverNote != null) WarningNote(driverNote),
      if (results.items.isNotEmpty)
        WarningNote(
          'Prices from Booking.com'
          '${fetchedAt == null ? '' : ', ${results.isSavedPrice ? 'saved' : 'checked'} ${describeCheckedAt(fetchedAt)}'}'
          ', for pick-up and return at 10:00. The final price is on Booking.com.',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final note in notes) ...[note, const SizedBox(height: AppSpacing.sm)],
        const SizedBox(height: AppSpacing.xs),
        if (results.items.isEmpty)
          _NoCars(
            results: results,
            filtered: filters.activeCount > 0,
            onSearchBookingCom: onSearchBookingCom,
            onClearFilters: onClearFilters,
            onRetry: onRetry,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = wide ? 2 : 1;
              final width = (constraints.maxWidth - AppSpacing.lg * (columns - 1)) / columns;
              return Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                children: [
                  for (final car in results.items)
                    SizedBox(
                      width: width,
                      child: CarCard(car: car, days: results.days, onOpen: () => onCar(car)),
                    ),
                ],
              );
            },
          ),
        if (results.totalPages > 1) ...[
          const SizedBox(height: AppSpacing.lg),
          Pager(page: results.page, totalPages: results.totalPages, onPage: onPage),
        ],
        if (results.mayHaveMore && results.items.isNotEmpty && searchUrl != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _MoreOnBookingCom(onOpen: () => onSearchBookingCom(searchUrl)),
        ],
      ],
    );
  }
}

/// The source returns at most 500 cars, so Booking.com may have more (`mayHaveMore`).
class _MoreOnBookingCom extends StatelessWidget {
  const _MoreOnBookingCom({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      decoration: BoxDecoration(color: context.palette.bgApp, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: context.palette.textSecondary, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Booking.com has more cars than shown here.', style: Theme.of(context).textTheme.bodySmall),
          ),
          TextButton(onPressed: onOpen, child: const Text('See all')),
        ],
      ),
    );
  }
}

class _NoCars extends StatelessWidget {
  const _NoCars({
    required this.results,
    required this.filtered,
    required this.onSearchBookingCom,
    required this.onClearFilters,
    required this.onRetry,
  });

  final CarResults results;
  final bool filtered;
  final ValueChanged<String> onSearchBookingCom;
  final VoidCallback onClearFilters;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Booking.com failed and nothing was saved: no car was searched, so "no cars here" would be wrong.
    final failed = results.searchedCount == 0 && results.warnings.isNotEmpty;
    final message = failed ? 'Booking.com did not answer this time. Try again in a moment.' : results.message;
    final searchUrl = results.searchUrl;

    return SoftCard(
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: context.palette.brandPrimarySoft,
            child: Icon(Icons.place_outlined, color: context.palette.brandPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            failed
                ? 'Cars could not be searched'
                : filtered
                ? 'No cars match these filters'
                : 'No rental cars here for these dates',
            style: textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(message, style: textTheme.bodySmall, textAlign: TextAlign.center),
          ],
          const SizedBox(height: AppSpacing.md),
          if (failed)
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: onRetry, child: const Text('Try again')),
            )
          else if (filtered)
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: onClearFilters, child: const Text('Clear filters')),
            ),
          if (searchUrl != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: failed || filtered
                  ? OutlinedButton(
                      onPressed: () => onSearchBookingCom(searchUrl),
                      child: const Text('Search on Booking.com'),
                    )
                  : FilledButton(
                      onPressed: () => onSearchBookingCom(searchUrl),
                      child: const Text('Search on Booking.com'),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
