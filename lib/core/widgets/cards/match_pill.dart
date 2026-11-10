import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:flutter/material.dart';

/// "✦ 92% match" on a card (Figma 2302:24). Nothing when the API gave no match. A tap or hover shows the reason.
///
/// Named `MatchPill`, not `MatchBadge`, because the ranking screens already have a `MatchBadge(percent)`.
class MatchPill extends StatelessWidget {
  const MatchPill(this.match, {super.key});

  final Match? match;

  @override
  Widget build(BuildContext context) {
    final match = this.match;
    if (match == null) return const SizedBox.shrink();
    final palette = context.palette;
    return Tooltip(
      message: match.reason,
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
        decoration: BoxDecoration(
          color: palette.statusSuccessSoft,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcons.sparkles, size: 12, color: palette.statusSuccess),
            const SizedBox(width: AppSpacing.xs),
            Text('${match.percent}% match', style: AppText.smallStrong.copyWith(color: palette.statusSuccess)),
          ],
        ),
      ),
    );
  }
}
