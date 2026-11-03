import 'dart:async';

import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/links/link_opener.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/core/widgets/page_frame.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/destination/presentation/widgets/trip_chips.dart';
import 'package:chocomousse/features/hotels/application/hotel_providers.dart';
import 'package:chocomousse/features/hotels/data/hotel_models.dart';
import 'package:chocomousse/features/hotels/presentation/widgets/hotel_card.dart';
import 'package:chocomousse/features/hotels/presentation/widgets/hotel_filters_sheet.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Hotels for a destination and the trip's dates and adults (designs H1–H6 / W1).
class HotelsScreen extends ConsumerStatefulWidget {
  const HotelsScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<HotelsScreen> createState() => _HotelsScreenState();
}

class _HotelsScreenState extends ConsumerState<HotelsScreen> {
  final GlobalKey _top = GlobalKey();
  HotelFilters _filters = const HotelFilters();
  int _page = 1;

  void _apply(HotelFilters filters) => setState(() {
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
    final applied = await showHotelFiltersSheet(
      context,
      filters: _filters,
      nights: trip.nights,
      currency: trip.currency,
    );
    if (applied != null) _apply(applied);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final destination = ref.watch(destinationProvider(widget.id)).value;
    final trip = ref.watch(tripSettingsProvider);
    // New dates, adults or currency start again from the first page.
    ref.listen(tripSettingsProvider, (_, _) => setState(() => _page = 1));

    final query = (
      destinationId: widget.id,
      from: trip.from,
      to: trip.to,
      adults: trip.adults,
      currency: trip.currency,
      filters: _filters,
      page: _page,
    );
    final results = _Results(
      query: query,
      destinationName: destination?.name ?? '',
      wide: wide,
      onClearFilters: () => _apply(_filters.cleared()),
      onPage: _goTo,
    );

    return PageFrame(
      children: [
        Row(
          key: _top,
          children: [
            const BackCircleButton(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                destination == null ? 'Hotels' : 'Hotels in ${destination.name}',
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
              // A Material rather than a decorated box, so the free-cancellation switch's splash shows.
              Material(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TripChips(showPassport: false, showAdults: true),
                      const SizedBox(height: AppSpacing.lg),
                      HotelFiltersForm(
                        filters: _filters,
                        nights: trip.nights,
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
          const TripChips(showPassport: false, showAdults: true),
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
                  color: _filters.activeCount > 0 ? AppColors.primary : AppColors.text,
                ),
                label: Text(_filters.activeCount > 0 ? 'Filters · ${_filters.activeCount}' : 'Filters'),
                backgroundColor: _filters.activeCount > 0 ? AppColors.primarySoft : null,
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

  final HotelSort sort;
  final ValueChanged<HotelSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<HotelSort>(
      tooltip: 'Sort hotels',
      initialValue: sort,
      onSelected: onChanged,
      itemBuilder: (context) => [for (final s in HotelSort.values) PopupMenuItem(value: s, child: Text(s.label))],
      child: Chip(
        avatar: const Icon(Icons.swap_vert, size: 16, color: AppColors.text),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(sort.label), const Icon(Icons.expand_more, size: 16)],
        ),
      ),
    );
  }
}

/// The API's reason for a 400 (Problem Details `errors`), or the usual wording for other failures.
String _describe(Object error) {
  if (error is DioException && error.response?.statusCode == 400) {
    final data = error.response?.data;
    final errors = data is Map<String, dynamic> ? data['errors'] : null;
    if (errors is Map<String, dynamic>) {
      for (final messages in errors.values) {
        if (messages is List && messages.isNotEmpty) return '${messages.first}';
      }
    }
  }
  return describeApiError(error);
}

class _Results extends ConsumerWidget {
  const _Results({
    required this.query,
    required this.destinationName,
    required this.wide,
    required this.onClearFilters,
    required this.onPage,
  });

  final HotelQuery query;
  final String destinationName;
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
        .watch(hotelResultsProvider(query))
        .when(
          loading: () => const HotelCardPlaceholders(),
          error: (e, _) => Column(
            children: [
              _ErrorBanner(message: _describe(e), onRetry: () => ref.invalidate(hotelResultsProvider(query))),
              const SizedBox(height: AppSpacing.sm),
              const HotelCardPlaceholders(animate: false),
            ],
          ),
          data: (results) => _HotelList(
            results: results,
            filters: query.filters,
            destinationName: results.destinationName.isEmpty ? destinationName : results.destinationName,
            wide: wide,
            onHotel: (hotel) =>
                context.push('/discover/destination/${query.destinationId}/hotels/${Uri.encodeComponent(hotel.id)}'),
            onSearchBookingCom: (url) => unawaited(_open(context, ref, url)),
            onClearFilters: onClearFilters,
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
      decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.muted, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _HotelList extends StatelessWidget {
  const _HotelList({
    required this.results,
    required this.filters,
    required this.destinationName,
    required this.wide,
    required this.onHotel,
    required this.onSearchBookingCom,
    required this.onClearFilters,
    required this.onPage,
  });

  final HotelResults results;
  final HotelFilters filters;
  final String destinationName;
  final bool wide;
  final ValueChanged<HotelOffer> onHotel;
  final ValueChanged<String> onSearchBookingCom;
  final VoidCallback onClearFilters;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final fetchedAt = results.pricesFetchedAt;
    final source = results.sourceName;
    final checked = results.filtersCheckedOn;

    final notes = <Widget>[
      for (final warning in results.warnings) HotelWarning(warning),
      if (source != null) WarningNote('Booking.com searched $source for $destinationName.'),
      if (results.items.isNotEmpty)
        WarningNote(
          'Prices from Booking.com'
          '${fetchedAt == null ? '' : ', ${results.isSavedPrice ? 'saved' : 'checked'} ${describeCheckedAt(fetchedAt)}'}'
          '. The final price is on Booking.com.',
        ),
    ];
    final filterNote = filters.needsDetails && checked != null
        ? WarningNote('Type of stay and free cancellation are known for $checked of the hotels found.')
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final note in notes) ...[note, const SizedBox(height: AppSpacing.sm)],
        const SizedBox(height: AppSpacing.xs),
        if (results.items.isEmpty) ...[
          _NoHotels(
            results: results,
            filtered: filters.activeCount > 0,
            onSearchBookingCom: onSearchBookingCom,
            onClearFilters: onClearFilters,
          ),
          const SizedBox(height: AppSpacing.md),
          ?filterNote,
        ] else ...[
          if (filterNote != null) ...[filterNote, const SizedBox(height: AppSpacing.md)],
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = wide ? 2 : 1;
              final width = (constraints.maxWidth - AppSpacing.lg * (columns - 1)) / columns;
              return Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                children: [
                  for (final hotel in results.items)
                    SizedBox(
                      width: width,
                      child: HotelCard(
                        hotel: hotel,
                        nights: results.nights,
                        destinationName: destinationName,
                        onOpen: () => onHotel(hotel),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
        if (results.totalPages > 1) ...[
          const SizedBox(height: AppSpacing.lg),
          _Pager(page: results.page, totalPages: results.totalPages, onPage: onPage),
        ],
      ],
    );
  }
}

class _NoHotels extends StatelessWidget {
  const _NoHotels({
    required this.results,
    required this.filtered,
    required this.onSearchBookingCom,
    required this.onClearFilters,
  });

  final HotelResults results;
  final bool filtered;
  final ValueChanged<String> onSearchBookingCom;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final message = results.message;
    final searchUrl = results.searchUrl;

    return SoftCard(
      child: Column(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primarySoft,
            child: Icon(Icons.bed_outlined, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            filtered ? 'No hotels match these filters' : 'No hotels for these dates',
            style: textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(message, style: textTheme.bodySmall, textAlign: TextAlign.center),
          ],
          const SizedBox(height: AppSpacing.md),
          if (filtered)
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: onClearFilters, child: const Text('Clear filters')),
            ),
          if (searchUrl != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: filtered
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

class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.totalPages, required this.onPage});

  final int page;
  final int totalPages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    // The theme's wide button padding doesn't fit three items on a phone.
    final compact = OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg));
    return Row(
      children: [
        OutlinedButton(
          style: compact,
          onPressed: page > 1 ? () => onPage(page - 1) : null,
          child: const Text('Previous'),
        ),
        Expanded(
          child: Text(
            'Page $page of $totalPages',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        OutlinedButton(
          style: compact,
          onPressed: page < totalPages ? () => onPage(page + 1) : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}
