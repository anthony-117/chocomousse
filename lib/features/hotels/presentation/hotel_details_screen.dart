import 'dart:async';

import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/links/link_opener.dart';
import 'package:chocomousse/core/widgets/page_frame.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/destination/presentation/widgets/trip_chips.dart';
import 'package:chocomousse/features/hotels/application/hotel_providers.dart';
import 'package:chocomousse/features/hotels/data/hotel_models.dart';
import 'package:chocomousse/features/hotels/presentation/widgets/hotel_card.dart';
import 'package:chocomousse/features/hotels/presentation/widgets/language_names.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// One hotel for the trip's dates and adults, with the way to book it on Booking.com (design H3).
class HotelDetailsScreen extends ConsumerWidget {
  const HotelDetailsScreen({required this.hotelId, super.key});

  final String hotelId;

  Future<void> _open(BuildContext context, WidgetRef ref, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref.read(linkOpenerProvider)(url);
    if (!opened) messenger.showSnackBar(const SnackBar(content: Text('Could not open Booking.com.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripSettingsProvider);
    final query = (hotelId: hotelId, from: trip.from, to: trip.to, adults: trip.adults, currency: trip.currency);

    final body = ref
        .watch(hotelDetailsProvider(query))
        .when(
          loading: () => const _Placeholders(),
          error: (e, _) => e is DioException && e.response?.statusCode == 404
              ? const _NotFound()
              : Column(
                  children: [
                    ErrorRetry(error: e, onRetry: () => ref.invalidate(hotelDetailsProvider(query))),
                    const SizedBox(height: AppSpacing.sm),
                    const _Placeholders(animate: false),
                  ],
                ),
          data: (hotel) =>
              _Details(hotel: hotel, trip: trip, onBook: () => unawaited(_open(context, ref, hotel.bookingUrl))),
        );

    return PageFrame(
      children: [
        Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: body),
        ),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.hotel, required this.trip, required this.onBook});

  final HotelDetails hotel;
  final TripSettings trip;
  final VoidCallback onBook;

  static String _km(double km) => km < 10 ? km.toStringAsFixed(1) : km.round().toString();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final stars = hotel.stars;
    final score = hotel.reviewScore;
    final count = hotel.reviewCount;
    final word = hotel.reviewWord;
    final distance = hotel.distanceToCentreKm;
    final place = [?hotel.address, if (distance != null) '${_km(distance)} km from centre'].join(' · ');
    final languages = languageNames(hotel.languages);
    final times = [
      if (hotel.checkInFrom case final from?) ('Check-in', 'From $from'),
      if (hotel.checkOutUntil case final until?) ('Check-out', 'Until $until'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Photos(urls: hotel.photoUrls),
        const SizedBox(height: AppSpacing.xl),
        for (final warning in hotel.warnings) ...[HotelWarning(warning), const SizedBox(height: AppSpacing.md)],
        Text(hotel.name, style: textTheme.headlineSmall),
        if (stars != null || score != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (stars != null && stars > 0) HotelStars(stars, size: 14),
              if (score != null) ReviewScore(score),
              if (score != null)
                Text([?word, if (count != null) formatReviews(count)].join(' · '), style: textTheme.bodySmall),
            ],
          ),
        ],
        if (place.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_outlined, size: 16, color: AppColors.muted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(place, style: textTheme.bodySmall)),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (hotel.stayType case final type?)
              Chip(
                avatar: const Icon(Icons.bed_outlined, size: 16, color: AppColors.primary),
                label: Text(type),
              ),
            if (hotel.freeCancellation ?? false) const HotelTag(icon: Icons.check, label: 'Free cancellation'),
            if (hotel.breakfastIncluded ?? false)
              const HotelTag(icon: Icons.free_breakfast_outlined, label: 'Breakfast included'),
          ],
        ),
        if (times.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              for (final (i, (label, value)) in times.indexed) ...[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _TimeTile(label: label, value: value),
                ),
              ],
            ],
          ),
        ],
        if (hotel.facilities.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('Facilities', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [for (final facility in hotel.facilities) Chip(label: Text(facility))],
          ),
        ],
        if (languages.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('Staff speak', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(languages.join(', '), style: textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
        ],
        const SizedBox(height: AppSpacing.xl),
        _PriceBox(hotel: hotel, trip: trip, onBook: onBook),
      ],
    );
  }
}

class _Photos extends StatefulWidget {
  const _Photos({required this.urls});

  final List<String> urls;

  @override
  State<_Photos> createState() => _PhotosState();
}

class _PhotosState extends State<_Photos> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: 280,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (urls.isEmpty)
              const HotelPhoto(url: null)
            else
              PageView.builder(
                itemCount: urls.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => HotelPhoto(url: urls[i]),
              ),
            const Positioned(left: AppSpacing.lg, top: AppSpacing.lg, child: BackCircleButton()),
            if (urls.length > 1)
              Positioned(
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.text.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '${_index + 1} / ${urls.length}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onPrimary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: AppColors.muted),
              const SizedBox(width: AppSpacing.xs),
              Text(label, style: textTheme.labelSmall?.copyWith(color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _PriceBox extends StatelessWidget {
  const _PriceBox({required this.hotel, required this.trip, required this.onBook});

  final HotelDetails hotel;
  final TripSettings trip;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final price = hotel.price;
    final checkedAt = hotel.priceFetchedAt;
    final day = DateFormat('d MMM');
    final stay = '${day.format(trip.from)} – ${day.format(trip.to)} · ${adultsLabel(trip.adults)} · 1 room';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final amount = price == null
                  ? Text('See the price on Booking.com', style: textTheme.labelLarge)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: formatHotelPrice(price.total, price.currency),
                            style: textTheme.titleLarge,
                            children: [TextSpan(text: '  total', style: textTheme.bodySmall)],
                          ),
                        ),
                        Text('${formatHotelPrice(price.perNight, price.currency)} a night', style: textTheme.bodySmall),
                      ],
                    );
              final book = FilledButton(onPressed: onBook, child: const Text('Book on Booking.com'));
              // Side by side when there is room (H3); on a narrow phone the button goes under the price.
              return constraints.maxWidth >= 380
                  ? Row(
                      children: [
                        Expanded(child: amount),
                        const SizedBox(width: AppSpacing.md),
                        book,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        amount,
                        const SizedBox(height: AppSpacing.md),
                        book,
                      ],
                    );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '$stay.'
            '${price != null && checkedAt != null ? ' Checked ${describeCheckedAt(checkedAt)}.' : ''}'
            ' You book and pay on Booking.com.',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BackCircleButton(),
        SizedBox(height: AppSpacing.lg),
        EmptyState(
          icon: Icons.bed_outlined,
          title: "This hotel can't be found",
          message: 'It may no longer be on Booking.com. Go back to see other hotels.',
        ),
      ],
    );
  }
}

/// The details layout as empty boxes while the hotel loads, or still ones after a failure.
class _Placeholders extends StatelessWidget {
  const _Placeholders({this.animate = true});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            SkeletonBox(height: 280, radius: AppRadius.lg, animate: animate),
            const Positioned(left: AppSpacing.lg, top: AppSpacing.lg, child: BackCircleButton()),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        SkeletonBox(height: 28, width: 240, animate: animate),
        const SizedBox(height: AppSpacing.md),
        SkeletonBox(width: 180, animate: animate),
        const SizedBox(height: AppSpacing.xl),
        SkeletonBox(height: 72, radius: AppRadius.md, animate: animate),
        const SizedBox(height: AppSpacing.xl),
        SkeletonBox(height: 96, radius: AppRadius.lg, animate: animate),
      ],
    );
  }
}
