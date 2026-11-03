import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/presentation/widgets/trip_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The way into Hotels from a destination's overview (H7). It makes no hotel request.
class HotelsEntry extends ConsumerWidget {
  const HotelsEntry({required this.destinationId, required this.destinationName, super.key});

  final String destinationId;
  final String destinationName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final trip = ref.watch(tripSettingsProvider);
    final day = DateFormat('d MMM');

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.push('/discover/destination/$destinationId/hotels'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Icon(Icons.bed_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('See hotels in $destinationName', style: textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${day.format(trip.from)} – ${day.format(trip.to)} · ${adultsLabel(trip.adults)}',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
