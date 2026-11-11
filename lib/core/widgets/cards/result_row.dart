import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/cards/match_pill.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:flutter/material.dart';

/// A result as one row (Figma 2304:114): an icon tile, the title and subtitle, the price and the match. Flights use
/// it, and cars from spec 008 US2.
class ResultRow extends StatelessWidget {
  const ResultRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
    this.match,
    this.onTap,
    this.add,
    super.key,
  });

  final AppIcons icon;
  final String title;
  final String subtitle;
  final String price;
  final Match? match;
  final VoidCallback? onTap;

  /// The "+" slot at the end (spec 008 US3).
  final Widget? add;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: palette.borderDefault),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.brandPrimarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: AppIcon(icon, color: palette.brandPrimary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong.copyWith(color: palette.textPrimary),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.small.copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(price, style: AppText.bodyStrong.copyWith(color: palette.textPrimary)),
                  if (match != null) ...[const SizedBox(height: AppSpacing.xs), MatchPill(match)],
                ],
              ),
              if (add case final add?) ...[const SizedBox(width: AppSpacing.xs), add],
            ],
          ),
        ),
      ),
    );
  }
}
