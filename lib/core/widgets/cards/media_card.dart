import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/cards/match_pill.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:flutter/material.dart';

/// A result with a photo (Figma 2304:92), 232 × 248: the match top-left, a bookmark slot top-right, then the title,
/// the subtitle, the price and a "+" slot. Hotels use it, and places and events from spec 008 US2.
class MediaCard extends StatelessWidget {
  const MediaCard({
    required this.photoUrl,
    required this.title,
    required this.subtitle,
    required this.price,
    this.match,
    this.onTap,
    this.bookmark,
    this.add,
    this.semanticLabel,
    super.key,
  });

  static const width = 232.0;
  static const height = 248.0;

  final String? photoUrl;
  final String title;
  final String subtitle;
  final String price;
  final Match? match;
  final VoidCallback? onTap;

  /// The save button (spec 008 US6); empty until then.
  final Widget? bookmark;

  /// "Add to plan" (spec 008 US3); empty until then.
  final Widget? add;

  /// What a screen reader says for the card ("Hotel Artemide, 92% match, $132 a night"). The bookmark and "+" keep
  /// their own labels. Null: the texts are read as they are.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final labelled = semanticLabel != null;
    return SizedBox(
      width: width,
      height: height,
      child: Semantics(
        container: true,
        button: onTap != null,
        label: semanticLabel,
        child: Material(
          color: palette.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: palette.borderDefault),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 136,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      OfferPhoto(url: photoUrl),
                      Positioned(
                        left: AppSpacing.sm,
                        top: AppSpacing.sm,
                        child: ExcludeSemantics(excluding: labelled, child: MatchPill(match)),
                      ),
                      if (bookmark case final bookmark?)
                        Positioned(right: AppSpacing.xs, top: AppSpacing.xs, child: bookmark),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          excluding: labelled,
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
                                // The "+" keeps a 48 px tap area in the price line, so the subtitle gives up its
                                // second line.
                                maxLines: add == null ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.small.copyWith(color: palette.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: ExcludeSemantics(
                                excluding: labelled,
                                child: Text(
                                  price,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.smallStrong.copyWith(color: palette.textPrimary),
                                ),
                              ),
                            ),
                            ?add,
                          ],
                        ),
                      ],
                    ),
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
