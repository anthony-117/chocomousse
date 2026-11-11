import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/plan_texts.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/ranked_card.dart';
import 'package:flutter/material.dart';

/// Opens I3: a sheet on phones, a dialog from [kWideLayoutBreakpoint] (spec Edge Cases).
Future<void> showPlanWhy(BuildContext context, Plan plan) {
  if (MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: PlanWhyView(plan: plan),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: PlanWhyView(plan: plan),
      ),
    ),
  );
}

/// Why the match and the cost (I3): each part with its weight's interests, how the days fit, then the cost lines and
/// what isn't included. Everything is the API's; the app only lays it out (FR-002).
class PlanWhyView extends StatelessWidget {
  const PlanWhyView({required this.plan, super.key});

  final Plan plan;

  String _level(MatchPartKind part) => switch (part) {
    MatchPartKind.hotel => 'All six',
    MatchPartKind.flight || MatchPartKind.car => 'Budget + Comfort',
    MatchPartKind.days => plan.match!.days.length == 1 ? '1 interest' : '${plan.match!.days.length} interests',
    MatchPartKind.other => '',
  };

  String _detail(MatchPartKind part) => switch (part) {
    MatchPartKind.hotel => [?plan.hotel?.offer.name, ?plan.hotel?.ranked.match?.reason].join(': '),
    MatchPartKind.flight => plan.flight?.ranked.match?.reason ?? '',
    MatchPartKind.car => plan.car?.ranked.match?.reason ?? '',
    MatchPartKind.days => plan.match!.days.map((d) => '${d.label} ${d.percent}%').join(' · '),
    MatchPartKind.other => '',
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final match = plan.match;
    final total = plan.total;
    String money(num amount) => formatMoney(amount, total.currency);
    final events = plan.days.expand((d) => d.items).where((i) => i.kind == ItemKind.event && i.price != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (match != null) ...[
          Row(
            children: [
              Expanded(child: Text('Why ${match.percent}%', style: textTheme.titleLarge)),
              MatchBadge(percent: match.percent),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(match.reason, style: textTheme.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          for (final part in match.parts)
            _PartRow(
              label: part.part.label,
              level: _level(part.part),
              percent: part.percent,
              detail: _detail(part.part),
            ),
          Text('Each part is weighted by the preferences it covers, then averaged.', style: textTheme.bodySmall),
          const Divider(height: AppSpacing.xxl),
        ],
        Text('Cost', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (total.flight != null) _CostRow('Flight', money(total.flight!)),
        if (total.hotel != null) _CostRow('Hotel · ${nights(plan.nights)}', money(total.hotel!)),
        if (total.car != null) _CostRow('Car', money(total.car!)),
        if (total.events > 0) _CostRow(events == 0 ? 'Events' : 'Events · $events', money(total.events)),
        _CostRow('Total', money(total.amount), bold: true),
        const SizedBox(height: AppSpacing.sm),
        ?_notIncluded(context, textTheme, money),
      ],
    );
  }

  Widget? _notIncluded(BuildContext context, TextTheme textTheme, String Function(num) money) {
    final total = plan.total;
    final budget = plan.tripBudget;
    final over = total.overBudgetBy;
    final lines = [
      if (total.unpriced > 0)
        'Not included: ${total.unpriced == 1 ? '1 item' : '${total.unpriced} items'} with no known ticket price.',
      if (total.otherCurrency > 0)
        'Not included: ${total.otherCurrency == 1 ? '1 price' : '${total.otherCurrency} prices'} in another currency.',
      if (budget != null && over != null && over > 0)
        "Your budget was ${money(budget)}, so you're ${money(over)} over."
      else if (budget != null && budget >= total.amount)
        "Your budget was ${money(budget)}, so you're ${money(budget - total.amount)} under.",
    ];
    if (lines.isEmpty) return null;
    return Text(
      lines.join(' '),
      style: textTheme.bodySmall?.copyWith(color: over != null && over > 0 ? context.palette.statusDanger : null),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({required this.label, required this.level, required this.percent, required this.detail});

  final String label;
  final String level;
  final int percent;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: textTheme.titleSmall)),
              Text(level, style: textTheme.bodySmall),
              const SizedBox(width: AppSpacing.sm),
              Text('$percent%', style: textTheme.titleSmall?.copyWith(color: context.palette.brandPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 100) / 100,
              minHeight: 6,
              backgroundColor: context.palette.borderDefault,
              color: context.palette.brandPrimary,
              semanticsLabel: '$label $percent%',
            ),
          ),
          if (detail.isNotEmpty) ...[const SizedBox(height: AppSpacing.xs), Text(detail, style: textTheme.bodySmall)],
        ],
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow(this.label, this.amount, {this.bold = false});

  final String label;
  final String amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = bold ? textTheme.titleSmall : textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(amount, style: textTheme.titleSmall),
        ],
      ),
    );
  }
}
