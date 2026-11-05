import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/assistant/presentation/widgets/assistant_entry.dart';
import 'package:chocomousse/features/cars/presentation/widgets/cars_entry.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/models.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/destination/presentation/widgets/pin_map.dart';
import 'package:chocomousse/features/destination/presentation/widgets/place_tile.dart';
import 'package:chocomousse/features/destination/presentation/widgets/trip_chips.dart';
import 'package:chocomousse/features/flights/presentation/widgets/flights_entry.dart';
import 'package:chocomousse/features/hotels/presentation/widgets/hotels_entry.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/plan_entry.dart';
import 'package:chocomousse/features/shell/floating_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// City overview (designs 04 / W2): facts for the trip dates, top attractions and events.
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(overviewProvider(id));

    return overview.when(
      loading: () => const _OverviewPlaceholder(),
      error: (e, _) => _OverviewPlaceholder(
        banner: ErrorRetry(error: e, onRetry: () => ref.invalidate(overviewProvider(id))),
      ),
      data: (data) => _OverviewBody(id: id, data: data),
    );
  }
}

/// The overview layout with empty boxes, while it loads or after it failed ([banner] set).
class _OverviewPlaceholder extends StatelessWidget {
  const _OverviewPlaceholder({this.banner});

  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final sidePadding = wide ? 64.0 : AppSpacing.xl;
    final animate = banner == null;
    final onHero = AppColors.onPrimary.withValues(alpha: 0.35);

    return _OverviewFrame(
      wide: wide,
      sidePadding: sidePadding,
      hero: _HeroFrame(
        sidePadding: sidePadding,
        rounded: wide,
        lines: [
          SkeletonBox(width: 120, height: 12, color: onHero, animate: animate),
          const SizedBox(height: AppSpacing.sm),
          SkeletonBox(width: 180, height: 32, color: onHero, animate: animate),
          const SizedBox(height: AppSpacing.sm),
          SkeletonBox(width: 150, height: 14, color: onHero, animate: animate),
        ],
      ),
      main: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (banner != null) ...[banner!, const SizedBox(height: AppSpacing.lg)],
          const TripChips(),
          const SizedBox(height: AppSpacing.lg),
          _FactGrid(
            columns: wide ? 3 : 2,
            tiles: [
              for (final (icon, title) in const [
                (Icons.wb_sunny_outlined, 'Weather'),
                (Icons.payments_outlined, 'Currency'),
                (Icons.badge_outlined, 'Visa'),
                (Icons.shield_outlined, 'Safety'),
                (Icons.celebration_outlined, 'Holidays'),
                (Icons.translate_outlined, 'Country'),
              ])
                FactTile.placeholder(icon: icon, title: title, animate: animate),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('Flights'),
          const SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 72, radius: AppRadius.md, animate: animate),
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('Hotels'),
          const SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 72, radius: AppRadius.md, animate: animate),
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('Car rental'),
          const SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 72, radius: AppRadius.md, animate: animate),
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('Plan your trip'),
          const SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 72, radius: AppRadius.md, animate: animate),
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('Top attractions'),
          PlaceTilePlaceholders(animate: animate),
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('Events during your trip'),
          const SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 64, radius: AppRadius.md, animate: animate),
        ],
      ),
      side: SkeletonBox(height: 420, radius: AppRadius.lg + 4, animate: animate),
    );
  }
}

/// Hero on top, then the main column, with [side] beside it on wide screens.
class _OverviewFrame extends StatelessWidget {
  const _OverviewFrame({
    required this.wide,
    required this.sidePadding,
    required this.hero,
    required this.main,
    required this.side,
  });

  final bool wide;
  final double sidePadding;
  final Widget hero;
  final Widget main;
  final Widget side;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: wide ? 64 : FloatingNav.height + 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          hero,
          Padding(
            padding: EdgeInsets.fromLTRB(sidePadding, AppSpacing.xl, sidePadding, 0),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: main),
                      const SizedBox(width: AppSpacing.xxl),
                      SizedBox(width: 420, child: side),
                    ],
                  )
                : main,
          ),
        ],
      ),
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
        const SectionTitle('Flights'),
        const SizedBox(height: AppSpacing.sm),
        FlightsEntry(destinationId: id, destinationName: data.destination.name),
        const SizedBox(height: AppSpacing.xl),
        const SectionTitle('Hotels'),
        const SizedBox(height: AppSpacing.sm),
        HotelsEntry(destinationId: id, destinationName: data.destination.name),
        const SizedBox(height: AppSpacing.xl),
        const SectionTitle('Car rental'),
        const SizedBox(height: AppSpacing.sm),
        CarsEntry(destinationId: id, destinationName: data.destination.name),
        const SizedBox(height: AppSpacing.md),
        AssistantEntry(destinationId: id, destinationName: data.destination.name),
        const SizedBox(height: AppSpacing.xl),
        const SectionTitle('Plan your trip'),
        const SizedBox(height: AppSpacing.sm),
        PlanEntry(destinationId: id, destinationName: data.destination.name),
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

    return _OverviewFrame(
      wide: wide,
      sidePadding: sidePadding,
      hero: _Hero(data: data, sidePadding: sidePadding, rounded: wide),
      main: main,
      side: _MapColumn(id: id, data: data),
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

    return _HeroFrame(
      sidePadding: sidePadding,
      rounded: rounded,
      lines: [
        Text(
          '${d.flag ?? ''} ${d.countryName.toUpperCase()} · ${d.timeZone.toUpperCase()}'.trim(),
          style: textTheme.labelSmall?.copyWith(color: AppColors.primarySoft),
        ),
        Text(d.name, style: textTheme.displaySmall?.copyWith(color: AppColors.onPrimary)),
        Text(dates, style: textTheme.bodyLarge?.copyWith(color: AppColors.onPrimary)),
      ],
    );
  }
}

/// Gradient hero with the back button above [lines].
class _HeroFrame extends StatelessWidget {
  const _HeroFrame({required this.sidePadding, required this.rounded, required this.lines});

  final double sidePadding;
  final bool rounded;
  final List<Widget> lines;

  @override
  Widget build(BuildContext context) {
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
            ...lines,
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
    return _FactGrid(
      columns: columns,
      tiles: [_weather(), _currency(trip.currency), _visa(trip.passport), _safety(), _holidays(), _country()],
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

class _FactGrid extends StatelessWidget {
  const _FactGrid({required this.columns, required this.tiles});

  final int columns;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
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
      loading: () => const PlaceTilePlaceholders(),
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
      loading: () => const SkeletonBox(height: 64, radius: AppRadius.md),
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
