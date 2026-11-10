import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/ranked_card.dart';
import 'package:flutter/material.dart';

/// Why an offer ranks where it does (S3 as a sheet, W1's right column as a panel): one row per part, in the API's
/// order, then the open button (spec story 2).
class WhyView extends StatelessWidget {
  const WhyView({required this.data, required this.match, required this.onOpen, this.panel = false, super.key});

  final RankedCardData data;
  final Match match;
  final VoidCallback onOpen;

  /// The W1 panel puts the match in the title instead of a badge.
  final bool panel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (panel)
          Text('Why ${data.title} · ${match.percent}%', style: textTheme.titleMedium)
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text('Why ${data.title}', style: textTheme.titleLarge)),
              const SizedBox(width: AppSpacing.sm),
              MatchBadge(percent: match.percent, overBudget: match.overBudget),
            ],
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(data.priceLine, style: textTheme.bodySmall),
        if (match.overBudget) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(match.reason, style: textTheme.bodySmall?.copyWith(color: context.palette.statusDanger)),
        ],
        const SizedBox(height: AppSpacing.md),
        for (final part in match.parts) MeasureRow(part: part),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: context.palette.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Each measure is multiplied by how much it matters to you, then averaged.',
                style: textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: onOpen, child: Text(data.openLabel)),
        ),
      ],
    );
  }
}

/// One part of a match, as the Figma MeasureRow component: name, level, percentage, bar and detail.
class MeasureRow extends StatelessWidget {
  const MeasureRow({required this.part, super.key});

  final MatchPart part;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final detail = part.known ? part.detail : 'Not known, counted as average';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(part.label, style: textTheme.bodyMedium)),
              Text(part.levelLabel, style: textTheme.bodySmall),
              const SizedBox(width: AppSpacing.sm),
              Text('${part.percent}%', style: textTheme.labelLarge?.copyWith(color: context.palette.brandPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: part.percent.clamp(0, 100) / 100,
              minHeight: 6,
              backgroundColor: context.palette.borderDefault,
              color: part.known ? context.palette.brandPrimary : context.palette.textSecondary,
              semanticsLabel: '${part.label} ${part.percent}%',
            ),
          ),
          if (detail.isNotEmpty) ...[const SizedBox(height: AppSpacing.xs), Text(detail, style: textTheme.bodySmall)],
        ],
      ),
    );
  }
}
