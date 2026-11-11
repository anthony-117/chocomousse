import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/itinerary/presentation/itinerary_screen.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Plan pane (spec 008 US1): the plan open in this chat's panel, as the embedded itinerary.
class PlanPane extends ConsumerWidget {
  const PlanPane({required this.chatKey, super.key});

  final String chatKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planId = ref.watch(sidePanelProvider(chatKey).select((s) => s.planId));
    if (planId == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'Open a plan from the chat to see it here.',
          style: AppText.body.copyWith(color: context.palette.textSecondary),
        ),
      );
    }
    return ItineraryView(key: ValueKey(planId), planId: planId, embedded: true, chatKey: chatKey);
  }
}
