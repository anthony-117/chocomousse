import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/chat/application/chat_trip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The way into the assistant from a city's overview: the trip chip takes the city, keeping its dates and adults, and
/// the assistant's home opens, ready for a question about it.
class AssistantEntry extends ConsumerWidget {
  const AssistantEntry({required this.destinationId, required this.destinationName, super.key});

  final String destinationId;
  final String destinationName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: palette.brandPrimarySoft,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          final trip = ref.read(chatTripProvider).trip;
          ref
              .read(chatTripProvider.notifier)
              .setTrip(trip.copyWith(destinationId: destinationId, destinationName: destinationName));
          context.go(AppPaths.home);
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              AppIcon(AppIcons.sparkles, color: palette.brandPrimary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ask the assistant', style: textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Questions about $destinationName, answered with TravelGenie data',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              AppIcon(AppIcons.chevronRight, color: palette.brandPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
