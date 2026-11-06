import 'dart:async';

import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/links/link_opener.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/core/widgets/page_frame.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/itinerary/presentation/plan_why_view.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/day_view.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/plan_texts.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/trip_card.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/ranked_card.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/ranked_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// What a failed plan request says: the plan failures' own words, or the usual network wording.
String describePlanError(Object error) => error is PlanFailure ? error.message : describeApiError(error);

/// The itinerary (I1, I2 on phones; W4 from [kWideLayoutBreakpoint]): the trip card, the days and their items.
class ItineraryScreen extends ConsumerWidget {
  const ItineraryScreen({required this.id, this.day, super.key});

  final String id;

  /// The chosen day's number (`?day=n`); the first day when missing or out of range.
  final int? day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(planProvider(id))
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const PlanLoading(),
          error: (e, _) => e is PlanNotFound
              ? const PlanProblem(message: "This plan doesn't exist or isn't yours.")
              : PlanLoading(
                  banner: ErrorRetryBanner(
                    message: describePlanError(e),
                    onRetry: () => ref.invalidate(planProvider(id)),
                  ),
                ),
          data: (plan) => PlanView(plan: plan, day: day),
        );
  }
}

/// A saved plan, laid out for the screen's width.
class PlanView extends ConsumerWidget {
  const PlanView({required this.plan, this.day, super.key});

  final Plan plan;
  final int? day;

  Future<void> _openLink(BuildContext context, WidgetRef ref, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref.read(linkOpenerProvider)(url);
    if (!opened) messenger.showSnackBar(const SnackBar(content: Text('Could not open the link.')));
  }

  /// What tapping an item opens (plan decision 6), or null when it opens nothing.
  VoidCallback? _onItem(BuildContext context, WidgetRef ref, PlanItem item) {
    final itemRef = item.ref;
    if (itemRef == null) return null;
    if (itemRef.hasPlaceDetails) {
      return () => context.push('/plans/${plan.id}/place/${Uri.encodeComponent(itemRef.id)}');
    }
    switch (itemRef.kind) {
      case RefKind.hotel:
        final hotel = plan.hotel?.offer;
        if (hotel == null) return null;
        return () =>
            context.push('/discover/destination/${plan.destinationId}/hotels/${Uri.encodeComponent(hotel.id)}');
      case RefKind.flight:
        final url = plan.flight?.offer.bookingUrl;
        return url == null ? null : () => unawaited(_openLink(context, ref, url));
      case RefKind.place || RefKind.event || RefKind.other:
        final url = itemRef.url;
        return url == null ? null : () => unawaited(_openLink(context, ref, url));
    }
  }

  void _change(BuildContext context, OfferKind kind) => context.push('/plans/${plan.id}/change/${kind.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final days = plan.days;
    final chosen = days.where((d) => d.number == day).firstOrNull ?? days.firstOrNull;
    void select(int n) => context.go('/plans/${plan.id}?day=$n');

    final header = PlanHeader(plan: plan);
    final trip = TripCard(
      plan: plan,
      onChange: (kind) => _change(context, kind),
      onWhy: () => unawaited(showPlanWhy(context, plan)),
    );
    final notes = [
      for (final warning in plan.warnings) ...[OfferWarning(warning), const SizedBox(height: AppSpacing.md)],
      if (chosen == days.firstOrNull)
        for (final note in plan.notes) ...[WarningNote(note), const SizedBox(height: AppSpacing.md)],
    ];
    final dayCard = chosen == null
        ? const WarningNote('This plan has no days.')
        : DayCard(day: chosen, onItem: (item) => _onItem(context, ref, item));

    if (wide) {
      return PageFrame(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 360,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    const SizedBox(height: AppSpacing.lg),
                    trip,
                    const SizedBox(height: AppSpacing.lg),
                    if (chosen != null) DayList(days: days, selected: chosen.number, onSelected: select),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...notes, dayCard]),
              ),
            ],
          ),
        ],
      );
    }

    return PageFrame(
      children: [
        header,
        const SizedBox(height: AppSpacing.lg),
        trip,
        const SizedBox(height: AppSpacing.lg),
        if (chosen != null) ...[
          DayChips(days: days, selected: chosen.number, onSelected: select),
          const SizedBox(height: AppSpacing.lg),
        ],
        ...notes,
        dayCard,
      ],
    );
  }
}

/// Back, the plan's name, "10 – 14 Apr · 1 adult · Draft, saved" and the match.
class PlanHeader extends StatelessWidget {
  const PlanHeader({required this.plan, super.key});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final match = plan.match;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PlansBackButton(),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan.name, style: textTheme.headlineSmall),
              Text(planSubtitle(plan), style: textTheme.bodySmall),
            ],
          ),
        ),
        if (match != null) ...[const SizedBox(width: AppSpacing.sm), MatchBadge(percent: match.percent)],
      ],
    );
  }
}

/// Back to where the plan was opened from, or to My plans.
class PlansBackButton extends StatelessWidget {
  const PlansBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.canvas,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.chevron_left, color: AppColors.text),
        onPressed: () => context.canPop() ? context.pop() : context.go('/plans'),
      ),
    );
  }
}

/// Placeholder header and days while a plan is opened or built, with [banner] above them after a failure.
class PlanLoading extends StatelessWidget {
  const PlanLoading({this.banner, this.title, super.key});

  final Widget? banner;

  /// "Building your plan for Rome…" while building.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final banner = this.banner;
    final title = this.title;

    return PageFrame(
      children: [
        Row(
          children: [
            const PlansBackButton(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: title == null
                  ? SkeletonBox(height: 28, width: 180, animate: banner == null)
                  : Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (banner != null) ...[banner, const SizedBox(height: AppSpacing.md)],
        DayPlaceholders(animate: banner == null),
      ],
    );
  }
}

/// A plan that can't be shown or built: the reason, and the way out.
class PlanProblem extends StatelessWidget {
  const PlanProblem({required this.message, this.action = 'My plans', this.to = '/plans', super.key});

  final String message;
  final String action;
  final String to;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      children: [
        const PlansBackButton(),
        const SizedBox(height: AppSpacing.xl),
        SoftCard(
          child: Column(
            children: [
              const Icon(Icons.map_outlined, size: 32, color: AppColors.muted),
              const SizedBox(height: AppSpacing.md),
              Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: () => context.go(to), child: Text(action)),
            ],
          ),
        ),
      ],
    );
  }
}
