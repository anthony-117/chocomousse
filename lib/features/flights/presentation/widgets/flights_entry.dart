import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/flights/application/flight_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The way into Flights from a destination's overview (F5). It makes no flight request.
class FlightsEntry extends ConsumerWidget {
  const FlightsEntry({required this.destinationId, required this.destinationName, super.key});

  final String destinationId;
  final String destinationName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final city = ref.watch(departureCityProvider);
    final trip = ref.watch(tripSettingsProvider);
    final day = DateFormat('d MMM');

    return Material(
      color: context.palette.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: context.palette.borderDefault),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.push('/discover/destination/$destinationId/flights'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(Icons.flight_takeoff, color: context.palette.brandPrimary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('See flights to $destinationName', style: textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      city == null
                          ? 'Choose your departure city'
                          : 'From ${city.name} · ${day.format(trip.from)} – ${day.format(trip.to)}',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
