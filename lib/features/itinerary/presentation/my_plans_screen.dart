import 'dart:async';

import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/page_frame.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/presentation/itinerary_screen.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/plan_actions_sheet.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/plan_texts.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/ranked_card.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/ranked_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Which plans My plans shows.
enum PlansFilter {
  all('All'),
  drafts('Drafts'),
  planned('Planned');

  PlansFilter(this.label);

  final String label;

  bool keeps(PlanSummary plan) => switch (this) {
    all => true,
    drafts => plan.status == PlanStatus.draft,
    planned => plan.status == PlanStatus.planned,
  };
}

/// My plans (I5 on phones, W7 on wide screens): every saved plan, newest change first.
class MyPlansScreen extends ConsumerStatefulWidget {
  const MyPlansScreen({super.key});

  @override
  ConsumerState<MyPlansScreen> createState() => _MyPlansScreenState();
}

class _MyPlansScreenState extends ConsumerState<MyPlansScreen> {
  PlansFilter _filter = PlansFilter.all;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final list = ref.watch(plansProvider);

    final Widget body;
    if (list.hasValue && !list.hasError) {
      final plans = list.requireValue;
      final shown = plans.items.where(_filter.keeps).toList();
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plans.items.isEmpty)
            const _NoPlans()
          else if (shown.isEmpty)
            Text('No ${_filter.label.toLowerCase()} plans.', style: textTheme.bodySmall)
          else
            _Grid(children: [for (final plan in shown) PlanCard(plan: plan)]),
          const SizedBox(height: AppSpacing.lg),
          if (plans.items.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: () => context.go('/discover'), child: const Text('Plan a new trip')),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('${plans.count} of ${plans.max} plans', style: textTheme.bodySmall),
          ],
        ],
      );
    } else if (list.error case final e?) {
      body = Column(
        children: [
          ErrorRetryBanner(message: describePlanError(e), onRetry: () => ref.invalidate(plansProvider)),
          const SizedBox(height: AppSpacing.md),
          const PlanCardPlaceholders(animate: false),
        ],
      );
    } else {
      body = const PlanCardPlaceholders();
    }

    return PageFrame(
      children: [
        Text('My plans', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final filter in PlansFilter.values)
              ChoiceChip(
                label: Text(filter.label),
                selected: filter == _filter,
                showCheckmark: false,
                onSelected: (_) => setState(() => _filter = filter),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        body,
      ],
    );
  }
}

/// One column on phones, three on wide screens (W7).
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = wide ? (constraints.maxWidth - 2 * AppSpacing.lg) / 3 : constraints.maxWidth;
        return Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}

/// "DRAFT · EDITED TODAY", or the status alone.
String planStatusLine(PlanSummary plan, {DateTime? now}) {
  final at = plan.updatedAt?.toLocal();
  final today = now ?? DateTime.now();
  final editedToday = at != null && at.year == today.year && at.month == today.month && at.day == today.day;
  return '${plan.status.label.toUpperCase()}${editedToday ? ' · EDITED TODAY' : ''}';
}

/// One plan of My plans: picture, status, name, dates and total, match, and ⋯ for the actions (I6).
class PlanCard extends StatelessWidget {
  const PlanCard({required this.plan, super.key});

  final PlanSummary plan;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final image = plan.imageUrl;
    final match = plan.matchPercent;

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/plans/${plan.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: image == null
                      ? const _Pin()
                      : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _Pin()),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(planStatusLine(plan), style: textTheme.labelSmall?.copyWith(color: AppColors.muted)),
                    Text(plan.name, style: textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(
                      '${planDates(plan.from, plan.to)} · ${formatMoney(plan.total, plan.currency)}',
                      style: textTheme.bodySmall,
                    ),
                    if (match != null) ...[const SizedBox(height: AppSpacing.xs), MatchBadge(percent: match)],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Plan actions',
                icon: const Icon(Icons.more_horiz, color: AppColors.muted),
                onPressed: () => unawaited(showPlanActions(context, plan)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.primarySoft,
    child: Center(child: Icon(Icons.place_outlined, color: AppColors.text)),
  );
}

class _NoPlans extends StatelessWidget {
  const _NoPlans();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const EmptyState(
          icon: Icons.work_outline,
          title: 'No plans yet',
          message: 'Open a destination, rank what matters to you, then choose Build my plan.',
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(onPressed: () => context.go('/discover'), child: const Text('Discover')),
      ],
    );
  }
}

/// Placeholder cards while My plans loads, or still ones after a failure.
class PlanCardPlaceholders extends StatelessWidget {
  const PlanCardPlaceholders({this.animate = true, super.key});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          SkeletonBox(height: 98, radius: AppRadius.lg, animate: animate),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}
