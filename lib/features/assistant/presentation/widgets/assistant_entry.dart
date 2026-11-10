import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/assistant/application/chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The way into the assistant from a city's overview: the chat is then about that city (FR-005).
class AssistantEntry extends ConsumerWidget {
  const AssistantEntry({required this.destinationId, required this.destinationName, super.key});

  final String destinationId;
  final String destinationName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: context.palette.brandPrimarySoft,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          ref.read(chatControllerProvider.notifier).startFor((id: destinationId, name: destinationName));
          context.go(AppPaths.home);
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: context.palette.brandPrimary),
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
              Icon(Icons.chevron_right, color: context.palette.brandPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
