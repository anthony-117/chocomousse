import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Itinerary · 91% match · $939 of $1,200 · Draft"; without "of …" when the plan has no budget.
String planCardLine(PlanSummary plan) {
  final budget = plan.tripBudget;
  final total = formatMoney(plan.total, plan.currency);
  return [
    'Itinerary',
    if (plan.matchPercent != null) '${plan.matchPercent}% match',
    if (budget == null) total else '$total of ${formatMoney(budget, plan.currency)}',
    plan.status.label,
  ].join(' · ');
}

/// Below this width a [PlanCardTile] puts Open plan under the plan, so the name keeps room.
const double kPlanTileStackWidth = 360;

/// A plan as a card (Figma 2304:143): the photo, the name, [planCardLine] and Open plan. Its border is the brand
/// colour while it is the plan open in the panel. A plan found deleted when opened says so and can't be opened again.
class PlanCardTile extends ConsumerWidget {
  const PlanCardTile({required this.plan, required this.onOpen, this.selected = false, super.key});

  final PlanSummary plan;
  final VoidCallback onOpen;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    // Only a plan already open is checked, so a list of cards never loads each plan.
    final deleted = ref.exists(planProvider(plan.id)) && ref.watch(planProvider(plan.id)).error is PlanNotFound;
    return Container(
      decoration: BoxDecoration(
        color: palette.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: selected ? palette.brandPrimary : palette.borderDefault, width: selected ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summary = Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(width: 56, height: 56, child: OfferPhoto(url: plan.imageUrl)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong.copyWith(color: palette.textPrimary),
                    ),
                    Text(
                      deleted ? 'This plan was deleted' : planCardLine(plan),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.small.copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          );
          final open = FilledButton(onPressed: deleted ? null : onOpen, child: const Text('Open plan'));
          // A narrow column (a phone, or a chat beside the panel) puts Open plan under the plan.
          if (constraints.maxWidth < kPlanTileStackWidth) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                summary,
                const SizedBox(height: AppSpacing.sm),
                open,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: summary),
              const SizedBox(width: AppSpacing.md),
              open,
            ],
          );
        },
      ),
    );
  }
}
