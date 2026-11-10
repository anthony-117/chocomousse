import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:flutter/material.dart';

/// What a ranked card shows, filled in by each kind (plan decision 8).
class RankedCardData {
  const RankedCardData({
    required this.id,
    required this.kind,
    required this.title,
    required this.details,
    required this.price,
    required this.priceLine,
    required this.openLabel,
  });

  final String id;

  /// "HOTEL · 4★", "FLIGHT · DIRECT", "CAR · INTERMEDIATE".
  final String kind;
  final String title;
  final String details;

  /// "$612".
  final String price;

  /// Under the title of the "Why" view: "$612 for 5 nights".
  final String priceLine;

  /// "Open hotel", "Open flight", "Open car".
  final String openLabel;
}

/// One ranked offer (S2, S4–S6): kind, match, title, details, reason and price.
class RankedCard extends StatelessWidget {
  const RankedCard({required this.data, required this.match, required this.onTap, this.selected = false, super.key});

  final RankedCardData data;
  final Match? match;
  final VoidCallback onTap;

  /// Outlined, as the selected card on wide screens (W1).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final match = this.match;
    final over = match?.overBudget ?? false;

    return Material(
      color: context.palette.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: selected ? context.palette.brandPrimary : context.palette.borderDefault,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(data.kind, style: textTheme.labelSmall?.copyWith(color: context.palette.textSecondary)),
                  ),
                  if (match != null) MatchBadge(percent: match.percent, overBudget: over),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(data.title, style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(data.details, style: textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: match == null
                        ? const SizedBox.shrink()
                        : Text(
                            match.reason,
                            style: textTheme.bodySmall?.copyWith(
                              color: over ? context.palette.statusDanger : context.palette.brandPrimary,
                            ),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(data.price, style: textTheme.titleLarge),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "94% match": green, or grey when the offer is over the total budget (S5).
class MatchBadge extends StatelessWidget {
  const MatchBadge({required this.percent, this.overBudget = false, super.key});

  final int percent;
  final bool overBudget;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: overBudget ? context.palette.textSecondary : context.palette.statusSuccess,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        '$percent% match',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.palette.brandOnPrimary),
      ),
    );
  }
}

/// Empty ranked cards while a list loads, or still ones after a failure.
class RankedCardPlaceholders extends StatelessWidget {
  const RankedCardPlaceholders({this.animate = true, super.key});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          SkeletonBox(height: 140, radius: AppRadius.md, animate: animate),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
