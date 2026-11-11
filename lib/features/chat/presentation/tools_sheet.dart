import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/chat/application/tool_starters.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The icon of each tool in the sheet and the menu.
AppIcons toolSheetIcon(Tool tool) => switch (tool) {
  Tool.planTrip => AppIcons.calendar,
  Tool.flights => AppIcons.plane,
  Tool.hotels => AppIcons.bed,
  Tool.carRental => AppIcons.car,
  Tool.places => AppIcons.landmark,
  Tool.events => AppIcons.ticket,
  Tool.travelInfo => AppIcons.globe,
  Tool.preferences => AppIcons.sliders,
};

/// How many plans "Open a saved plan" offers.
const kToolsPlanCount = 5;

/// What was picked in the tools sheet or menu. The composer acts on it once the sheet is closed.
@immutable
sealed class ToolChoice {
  const ToolChoice();
}

/// A tool: fill the composer with its starter (My preferences opens the preferences instead).
final class PickedTool extends ToolChoice {
  const PickedTool(this.tool);

  final Tool tool;
}

/// "Set trip dates and travellers".
final class PickedTripEditor extends ToolChoice {
  const PickedTripEditor();
}

/// One of the latest plans, from "Open a saved plan".
final class PickedPlan extends ToolChoice {
  const PickedPlan(this.planId);

  final String planId;
}

/// The "+" tools sheet on phones (M4). It only returns a choice; it never sends anything.
Future<ToolChoice?> showToolsSheet(BuildContext context) => showModalBottomSheet<ToolChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => const ToolsSheet(),
);

/// M4: "What can I help with?", the eight tools in two columns, then the trip and saved-plan rows. No attach and no
/// location rows (FR-029).
class ToolsSheet extends ConsumerWidget {
  const ToolsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    void pick(ToolChoice choice) => Navigator.of(context).pop(choice);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('What can I help with?', style: AppText.title.copyWith(color: palette.textPrimary)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Pick one, or just type — I'll use the right tool.",
            style: AppText.small.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 2.6,
            children: [for (final tool in Tool.values) _ToolTile(tool: tool, onTap: () => pick(PickedTool(tool)))],
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(color: palette.borderDefault, height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: AppIcon(AppIcons.users, color: palette.textSecondary),
            title: const Text('Set trip dates and travellers'),
            trailing: AppIcon(AppIcons.chevronRight, size: 16, color: palette.textTertiary),
            onTap: () => pick(const PickedTripEditor()),
          ),
          _SavedPlans(onOpen: (id) => pick(PickedPlan(id))),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool, required this.onTap});

  final Tool tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: '${tool.label}, ${tool.detail}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: palette.bgSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                AppIcon(toolSheetIcon(tool), color: palette.textPrimary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tool.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.smallStrong.copyWith(color: palette.textPrimary),
                      ),
                      Text(
                        tool.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.small.copyWith(color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Open a saved plan": the latest plans, shown when the row is opened. Hidden while there are none.
class _SavedPlans extends ConsumerWidget {
  const _SavedPlans({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final plans = ref.watch(plansProvider).value?.items.take(kToolsPlanCount).toList() ?? const <PlanSummary>[];
    if (plans.isEmpty) return const SizedBox.shrink();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: AppIcon(AppIcons.map, color: palette.textSecondary),
        title: const Text('Open a saved plan'),
        children: [
          for (final plan in plans)
            ListTile(
              contentPadding: const EdgeInsets.only(left: AppSpacing.xxl),
              title: Text(plan.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(plan.destinationName),
              onTap: () => onOpen(plan.id),
            ),
        ],
      ),
    );
  }
}

/// The same entries as the sheet, as the composer's "+" menu on wide screens.
List<Widget> toolMenuEntries({required List<PlanSummary> plans, required ValueChanged<ToolChoice> onPick}) => [
  for (final tool in Tool.values)
    MenuItemButton(
      leadingIcon: AppIcon(toolSheetIcon(tool), size: 18),
      onPressed: () => onPick(PickedTool(tool)),
      child: Text(tool.label),
    ),
  const Divider(height: 1),
  MenuItemButton(
    leadingIcon: const AppIcon(AppIcons.users, size: 18),
    onPressed: () => onPick(const PickedTripEditor()),
    child: const Text('Set trip dates and travellers'),
  ),
  if (plans.isNotEmpty)
    SubmenuButton(
      leadingIcon: const AppIcon(AppIcons.map, size: 18),
      menuChildren: [
        for (final plan in plans.take(kToolsPlanCount))
          MenuItemButton(onPressed: () => onPick(PickedPlan(plan.id)), child: Text(plan.name)),
      ],
      child: const Text('Open a saved plan'),
    ),
];
