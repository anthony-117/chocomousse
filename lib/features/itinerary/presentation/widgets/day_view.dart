import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/plan_texts.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/trip_card.dart';
import 'package:flutter/material.dart';

/// "Day 1 · Day 2 · …" (I1): one chip per day.
class DayChips extends StatelessWidget {
  const DayChips({required this.days, required this.selected, required this.onSelected, super.key});

  final List<PlanDay> days;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final day in days)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text('Day ${day.number}'),
                selected: day.number == selected,
                showCheckmark: false,
                onSelected: (_) => onSelected(day.number),
              ),
            ),
        ],
      ),
    );
  }
}

/// The day list of W4: "Day 2 · Fri 11 Apr" over the day's topic, the chosen one tinted.
class DayList extends StatelessWidget {
  const DayList({required this.days, required this.selected, required this.onSelected, super.key});

  final List<PlanDay> days;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PlanPanel(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          for (final day in days)
            Material(
              color: day.number == selected ? context.palette.brandPrimarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => onSelected(day.number),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dayLabel(day),
                              style: textTheme.labelSmall?.copyWith(
                                color: day.number == selected
                                    ? context.palette.brandPrimary
                                    : context.palette.textSecondary,
                              ),
                            ),
                            Text(dayTopic(day), style: textTheme.titleSmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One day (I1, I2): title, date, weather and walk, then its items in time order on a timeline.
class DayCard extends StatelessWidget {
  const DayCard({required this.day, required this.onItem, super.key});

  final PlanDay day;

  /// Null for an item that opens nothing.
  final VoidCallback? Function(PlanItem item) onItem;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PlanPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(day.title, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(dayDetails(day), style: textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          if (day.items.isEmpty)
            Text('Nothing planned this day.', style: textTheme.bodySmall)
          else
            for (final (i, item) in day.items.indexed)
              TripItemRow(item: item, first: i == 0, last: i == day.items.length - 1, onTap: onItem(item)),
        ],
      ),
    );
  }
}

/// TripItemRow: the start time, a dot on the line, the name and its details.
class TripItemRow extends StatelessWidget {
  const TripItemRow({required this.item, required this.first, required this.last, this.onTap, super.key});

  final PlanItem item;
  final bool first;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 52, child: Text(item.start, style: textTheme.bodySmall)),
            SizedBox(
              width: 24,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: first ? 6 : 0,
                    bottom: 0,
                    child: Container(width: 2, color: context.palette.borderDefault),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: context.palette.brandPrimary, shape: BoxShape.circle),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? AppSpacing.sm : AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: textTheme.titleSmall?.copyWith(color: onTap == null ? null : context.palette.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(itemDetails(item, first: first), style: textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right, size: 18, color: context.palette.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Placeholder days while a plan is built or opened (constitution V).
class DayPlaceholders extends StatelessWidget {
  const DayPlaceholders({this.animate = true, super.key});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(height: 220, radius: AppRadius.lg, animate: animate),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              SkeletonBox(width: 64, height: 32, radius: AppRadius.full, animate: animate),
              const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SkeletonBox(height: 360, radius: AppRadius.lg, animate: animate),
      ],
    );
  }
}
