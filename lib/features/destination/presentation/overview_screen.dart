import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/tokens.dart';
import '../../shell/floating_nav.dart';
import '../application/destination_providers.dart';
import '../data/models.dart';
import 'widgets/common.dart';
import 'widgets/pin_map.dart';
import 'widgets/place_tile.dart';
import 'widgets/trip_chips.dart';

/// City overview (designs 04 / W2): facts for the trip dates, top attractions and events.
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(overviewProvider(id));

    return overview.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackCircleButton(),
              ErrorRetry(error: e, onRetry: () => ref.invalidate(overviewProvider(id))),
            ],
          ),
        ),
      ),
      data: (data) => _OverviewBody(id: id, data: data),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({required this.id, required this.data});

  final String id;
  final DestinationOverview data;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final sidePadding = wide ? 64.0 : AppSpacing.xl;

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TripChips(),
        const SizedBox(height: AppSpacing.lg),
        _Facts(data: data, columns: wide ? 3 : 2),
        if ((data.weather?.days.length ?? 0) > 1) ...[
          const SizedBox(height: AppSpacing.lg),
          _WeatherStrip(report: data.weather!),
        ],
        for (final warning in data.warnings) ...[const SizedBox(height: AppSpacing.sm), WarningNote(warning)],
        const SizedBox(height: AppSpacing.xl),
        SectionTitle(
          'Top attractions',
          action: 'See all',
          onAction: () => context.push('/discover/destination/$id/places?category=attraction'),
        ),
        _PlacesPreview(id: id),
        const SizedBox(height: AppSpacing.xl),
        const SectionTitle('Events during your trip'),
        const SizedBox(height: AppSpacing.sm),
        _EventsPreview(id: id),
        if (!wide) ...[
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.push('/discover/destination/$id/places?category=restaurant'),
              child: const Text('Places to eat'),
            ),
          ),
        ],
      ],
    );

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: wide ? 64 : FloatingNav.height + 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(data: data, sidePadding: sidePadding, rounded: wide),
          Padding(
            padding: EdgeInsets.fromLTRB(sidePadding, AppSpacing.xl, sidePadding, 0),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: main),
                      const SizedBox(width: AppSpacing.xxl),
                      SizedBox(
                        width: 420,
                        child: _MapColumn(id: id, data: data),
                      ),
                    ],
                  )
                : main,
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.data, required this.sidePadding, required this.rounded});

  final DestinationOverview data;
  final double sidePadding;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final d = data.destination;
    final days = data.to.difference(data.from).inDays + 1;
    final dates = '${DateFormat('d MMM').format(data.from)} – ${DateFormat('d MMM y').format(data.to)} · $days days';

    final hero = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: kPhotoGradient,
        borderRadius: rounded ? BorderRadius.circular(AppRadius.lg + 4) : null,
      ),
      padding: EdgeInsets.fromLTRB(sidePadding, AppSpacing.lg, sidePadding, AppSpacing.xl),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BackCircleButton(onDark: true),
            SizedBox(height: rounded ? 80 : 96),
            Text(
              '${d.flag ?? ''} ${d.countryName.toUpperCase()} · ${d.timeZone.toUpperCase()}'.trim(),
              style: textTheme.labelSmall?.copyWith(color: AppColors.primarySoft),
            ),
            Text(d.name, style: textTheme.displaySmall?.copyWith(color: AppColors.onPrimary)),
            Text(dates, style: textTheme.bodyLarge?.copyWith(color: AppColors.onPrimary)),
          ],
        ),
      ),
    );

    return rounded
        ? Padding(padding: EdgeInsets.fromLTRB(sidePadding, AppSpacing.xl, sidePadding, 0), child: hero)
        : hero;
  }
}

class _Facts extends ConsumerWidget {
  const _Facts({required this.data, required this.columns});

  final DestinationOverview data;
  final int columns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripSettingsProvider);
    final tiles = [_weather(), _currency(trip.currency), _visa(trip.passport), _safety(), _holidays(), _country()];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.md;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final tile in tiles) SizedBox(width: width, child: tile)],
        );
      },
    );
  }

  Widget _weather() {
    final w = data.weather;
    if (w == null || w.days.isEmpty) {
      return const FactTile(icon: Icons.wb_sunny_outlined, title: 'Weather', value: '—', note: 'Unavailable');
    }
    final high = w.days.map((d) => d.maxC).reduce((a, b) => a > b ? a : b).round();
    final low = w.days.map((d) => d.minC).reduce((a, b) => a < b ? a : b).round();
    return FactTile(
      icon: Icons.wb_sunny_outlined,
      title: 'Weather',
      value: '$high° / $low°',
      note: w.isForecast ? w.days.first.summary : 'Last year on these dates',
    );
  }

  Widget _currency(String home) {
    final rate = data.exchange;
    final local = data.country?.currencies.firstOrNull;
    if (rate != null) {
      final value = rate.rate >= 100 ? rate.rate.toStringAsFixed(0) : rate.rate.toStringAsFixed(2);
      return FactTile(
        icon: Icons.payments_outlined,
        title: 'Currency',
        value: '1 ${rate.base} = $value ${rate.quote}',
        note: 'ECB · ${DateFormat('d MMM').format(rate.date)}',
      );
    }
    return FactTile(
      icon: Icons.payments_outlined,
      title: 'Currency',
      value: local ?? '—',
      note: local == home ? 'Same as yours' : 'No rate available',
    );
  }

  Widget _visa(String passport) {
    final visa = data.visa;
    return FactTile(
      icon: Icons.badge_outlined,
      title: 'Visa',
      value: visa?.label ?? 'Unknown',
      note: '$passport passport',
      tone: visa == null
          ? null
          : visa.isFree
          ? AppColors.success
          : visa.requirement == 'visa required'
          ? AppColors.danger
          : AppColors.warning,
    );
  }

  Widget _safety() {
    final a = data.advisory;
    if (a == null) {
      return const FactTile(icon: Icons.shield_outlined, title: 'Safety', value: '—', note: 'No advisory');
    }
    return FactTile(
      icon: Icons.shield_outlined,
      title: 'Safety',
      value: 'Level ${a.level}',
      note: a.label,
      tone: switch (a.level) {
        1 => AppColors.success,
        2 => AppColors.warning,
        _ => AppColors.danger,
      },
    );
  }

  Widget _holidays() {
    final h = data.holidays;
    if (h == null) {
      return const FactTile(icon: Icons.celebration_outlined, title: 'Holidays', value: '—', note: 'Unavailable');
    }
    if (h.isEmpty) {
      return const FactTile(
        icon: Icons.celebration_outlined,
        title: 'Holidays',
        value: 'None',
        note: 'during your dates',
      );
    }
    final more = h.length > 1 ? ' (+${h.length - 1} more)' : '';
    return FactTile(
      icon: Icons.celebration_outlined,
      title: 'Holidays',
      value: DateFormat('d MMM').format(h.first.date),
      note: '${h.first.name}$more',
    );
  }

  Widget _country() {
    final c = data.country;
    return FactTile(
      icon: Icons.translate_outlined,
      title: 'Country',
      value: [c?.languages.firstOrNull, c?.callingCode].whereType<String>().join(' · '),
      note: c?.capital == null ? null : 'Capital: ${c!.capital}',
    );
  }
}

class _WeatherStrip extends StatelessWidget {
  const _WeatherStrip({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // A Row in a horizontal scroll view sizes itself to its content, so no fixed height to outgrow.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final day in report.days)
            Container(
              width: 96,
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('EEE d').format(day.date), style: textTheme.labelSmall),
                  Text('${day.maxC.round()}°', style: textTheme.titleMedium),
                  Text(
                    day.rainChance == null ? '${day.minC.round()}° low' : '${day.rainChance}% rain',
                    style: textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PlacesPreview extends ConsumerWidget {
  const _PlacesPreview({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(placesProvider((id, PlaceCategory.attraction)));
    return places.when(
      loading: () => const LoadingBlock(height: 80),
      error: (e, _) =>
          ErrorRetry(error: e, onRetry: () => ref.invalidate(placesProvider((id, PlaceCategory.attraction)))),
      data: (result) {
        if (result.items.isEmpty) {
          return WarningNote(result.warnings.firstOrNull ?? 'No attractions found.');
        }
        return Column(
          children: [
            for (final place in result.items.take(3))
              PlaceTile(place: place, onTap: () => context.push('/discover/place/${Uri.encodeComponent(place.id)}')),
          ],
        );
      },
    );
  }
}

class _EventsPreview extends ConsumerWidget {
  const _EventsPreview({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider(id));
    return events.when(
      loading: () => const LoadingBlock(height: 80),
      error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(eventsProvider(id))),
      data: (result) {
        if (result.items.isEmpty) {
          return WarningNote(result.warnings.firstOrNull ?? 'No events found for your dates.');
        }
        return Column(
          children: [
            for (final event in result.items.take(3)) ...[
              EventTile(event: event),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _MapColumn extends ConsumerWidget {
  const _MapColumn({required this.id, required this.data});

  final String id;
  final DestinationOverview data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attractions = ref.watch(placesProvider((id, PlaceCategory.attraction))).value?.items ?? const [];
    return Column(
      children: [
        PinMap(centerLat: data.destination.lat, centerLng: data.destination.lng, places: attractions, height: 420),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => context.push('/discover/destination/$id/places?category=restaurant'),
            child: const Text('Places to eat'),
          ),
        ),
      ],
    );
  }
}
