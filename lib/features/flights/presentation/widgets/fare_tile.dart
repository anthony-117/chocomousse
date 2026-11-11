import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One fare (FareCard in Figma). The whole tile opens the booking site.
class FareTile extends StatelessWidget {
  const FareTile({required this.fare, required this.onOpen, super.key});

  final FlightFare fare;
  final VoidCallback onOpen;

  static final _date = DateFormat('EEE d MMM · HH:mm');

  static String _stops(int stops) => switch (stops) {
    0 => 'Direct',
    1 => '1 stop',
    _ => '$stops stops',
  };

  static String _duration(int minutes) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return [if (hours > 0) '${hours}h', if (rest > 0) '${rest}m'].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final price = NumberFormat.simpleCurrency(name: fare.currency, decimalDigits: 0).format(fare.amount);
    final returnAt = fare.returnAt;
    final label = fare.dateMatch.label;
    final duration = fare.durationMinutes;

    return Material(
      color: context.palette.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: context.palette.borderDefault),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: price,
                        style: textTheme.titleLarge,
                        children: [
                          TextSpan(text: returnAt == null ? '  one way' : '  round trip', style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                  if (label != null) _DateLabel(label),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('${fare.originAirport} → ${fare.destinationAirport}', style: textTheme.labelLarge),
              const SizedBox(height: AppSpacing.md),
              Text('${_date.format(fare.departureAt)} · ${_stops(fare.stops)}', style: textTheme.bodySmall),
              if (returnAt != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${_date.format(returnAt)}${fare.returnStops == null ? '' : ' · ${_stops(fare.returnStops!)}'}',
                  style: textTheme.bodySmall,
                ),
              ],
              // The source's duration covers both directions of a round trip.
              if (duration != null && duration > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${_duration(duration)} ${returnAt == null ? 'flying' : 'flying in total'}',
                  style: textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('See live price', style: textTheme.labelSmall?.copyWith(color: context.palette.brandPrimary)),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(Icons.north_east, size: 14, color: context.palette.brandPrimary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateLabel extends StatelessWidget {
  const _DateLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: context.palette.brandPrimarySoft,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.brandPrimary)),
    );
  }
}

/// Empty fare boxes while fares load, or still ones after a failure.
class FareTilePlaceholders extends StatelessWidget {
  const FareTilePlaceholders({this.animate = true, super.key});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          SkeletonBox(height: 140, radius: AppRadius.md, animate: animate),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
